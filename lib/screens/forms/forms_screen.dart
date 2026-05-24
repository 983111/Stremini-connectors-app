import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';

class FormsScreen extends StatefulWidget {
  const FormsScreen({super.key});

  @override
  State<FormsScreen> createState() => _FormsScreenState();
}

class _FormsScreenState extends State<FormsScreen> {
  // 0 = builder, 1 = my forms
  int _tab = 0;

  // Builder state
  final TextEditingController _promptCtrl = TextEditingController();
  bool _generating = false;
  Map<String, dynamic>? _generatedForm;
  bool _publishing = false;
  String? _publishedUrl;

  // My Forms state
  List<Map<String, dynamic>> _userForms = [];
  bool _loadingForms = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  // Edit-with-AI
  final TextEditingController _editCtrl = TextEditingController();
  bool _editLoading = false;

  @override
  void dispose() {
    _promptCtrl.dispose();
    _editCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_promptCtrl.text.trim().isEmpty) return;
    setState(() {
      _generating = true;
      _publishedUrl = null;
    });
    try {
      final result = await ApiClient.post('/api/form/generate', {
        'description': _promptCtrl.text.trim(),
      });
      final items = (result['items'] as List? ?? []).map((item) {
        final m = Map<String, dynamic>.from(item as Map);
        m['id'] = DateTime.now().microsecondsSinceEpoch.toString() +
            item.hashCode.toString();
        return m;
      }).toList();
      setState(() {
        _generatedForm = {
          'title': result['title'] ?? 'Untitled Form',
          'description': result['description'] ?? '',
          'items': items,
        };
        _promptCtrl.clear();
      });
    } catch (e) {
      _showSnack('Failed to generate: $e');
    } finally {
      setState(() => _generating = false);
    }
  }

  Future<void> _editWithAI() async {
    if (_editCtrl.text.trim().isEmpty || _generatedForm == null) return;
    setState(() => _editLoading = true);
    try {
      final result = await ApiClient.post('/api/form/edit', {
        'currentStructure': _generatedForm,
        'prompt': _editCtrl.text.trim(),
      });
      final items = (result['items'] as List? ?? []).map((item) {
        final m = Map<String, dynamic>.from(item as Map);
        m['id'] ??= DateTime.now().microsecondsSinceEpoch.toString();
        return m;
      }).toList();
      setState(() {
        _generatedForm = {
          'title': result['title'] ?? _generatedForm!['title'],
          'description': result['description'] ?? _generatedForm!['description'],
          'items': items,
        };
        _editCtrl.clear();
      });
    } catch (e) {
      _showSnack('Failed to apply edits: $e');
    } finally {
      setState(() => _editLoading = false);
    }
  }

  Future<void> _publish() async {
    final auth = context.read<AuthProvider>();
    if (auth.googleApiClient == null) {
      _showSnack('Please sign in with Google first.');
      return;
    }
    if (_generatedForm == null) return;
    setState(() => _publishing = true);
    try {
      final formData = await auth.googleApiClient!.createForm(
        _generatedForm!['title'] as String? ?? 'Untitled Form',
      );
      final formId = formData['formId'] as String;
      final items = _generatedForm!['items'] as List;
      final requests = <Map<String, dynamic>>[];

      requests.add({
        'updateFormInfo': {
          'info': {
            'title': _generatedForm!['title'],
            'description': _generatedForm!['description'],
          },
          'updateMask': 'title,description',
        },
      });

      for (int i = 0; i < items.length; i++) {
        final item = items[i] as Map<String, dynamic>;
        final type = item['type'] as String? ?? 'TEXT';
        final q = <String, dynamic>{'required': item['required'] ?? false};
        if (type == 'TEXT') {
          q['textQuestion'] = {'paragraph': true};
        } else if (type == 'CHOICE') {
          q['choiceQuestion'] = {
            'type': 'RADIO',
            'options': ((item['options'] as List?) ?? [])
                .map((o) => {'value': o.toString()})
                .toList(),
          };
        } else if (type == 'CHECKBOX') {
          q['choiceQuestion'] = {
            'type': 'CHECKBOX',
            'options': ((item['options'] as List?) ?? [])
                .map((o) => {'value': o.toString()})
                .toList(),
          };
        } else if (type == 'SCALE') {
          q['scaleQuestion'] = {'low': 1, 'high': 5};
        }
        requests.add({
          'createItem': {
            'item': {'title': item['title'] ?? 'Question', 'questionItem': {'question': q}},
            'location': {'index': i},
          },
        });
      }

      await auth.googleApiClient!.updateFormBatch(formId, requests);
      setState(() {
        _publishedUrl = 'https://docs.google.com/forms/d/$formId/edit';
        _generatedForm = null;
      });
    } catch (e) {
      _showSnack('Failed to publish: $e');
    } finally {
      setState(() => _publishing = false);
    }
  }

  Future<void> _loadForms() async {
    final auth = context.read<AuthProvider>();
    if (auth.googleApiClient == null) return;
    setState(() => _loadingForms = true);
    try {
      final forms = await auth.googleApiClient!.fetchDriveFiles(
        query: "mimeType = 'application/vnd.google-apps.form' and trashed = false",
        orderBy: 'modifiedTime desc',
      );
      setState(() => _userForms = forms);
    } catch (e) {
      _showSnack('Failed to load forms: $e');
    } finally {
      setState(() => _loadingForms = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13, color: Colors.white)),
      backgroundColor: const Color(0xFF111111),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('Forms'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(41),
          child: Column(
            children: [
              Row(
                children: [
                  _TabBtn(
                    label: 'AI Builder',
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  _TabBtn(
                    label: 'My Forms',
                    selected: _tab == 1,
                    onTap: () {
                      setState(() => _tab = 1);
                      _loadForms();
                    },
                  ),
                ],
              ),
              const Divider(height: 1),
            ],
          ),
        ),
      ),
      body: _tab == 0 ? _buildBuilder() : _buildMyForms(),
    );
  }

  Widget _buildBuilder() {
    if (_publishedUrl != null) {
      return _SuccessView(
        url: _publishedUrl!,
        onNew: () => setState(() {
          _publishedUrl = null;
          _promptCtrl.clear();
        }),
      );
    }

    if (_generatedForm != null) {
      return _FormEditor(
        form: _generatedForm!,
        editCtrl: _editCtrl,
        editLoading: _editLoading,
        publishing: _publishing,
        onEditWithAI: _editWithAI,
        onPublish: _publish,
        onDiscard: () => setState(() => _generatedForm = null),
        onUpdateForm: (updated) => setState(() => _generatedForm = updated),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingMD),
      children: [
        const Text('Describe the form you need',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground)),
        const SizedBox(height: 6),
        const Text('AI will generate a complete form structure for you.',
            style: TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              TextField(
                controller: _promptCtrl,
                maxLines: 5,
                style: const TextStyle(fontSize: 14, color: AppColors.foreground),
                decoration: const InputDecoration(
                  hintText:
                      'e.g. Job application form for a senior designer role with portfolio and salary questions.',
                  hintStyle: TextStyle(fontSize: 13, color: AppColors.mutedLight),
                  contentPadding: EdgeInsets.all(14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  filled: true,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(AppConstants.radiusMD),
                    bottomRight: Radius.circular(AppConstants.radiusMD),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('AI will generate a complete form structure',
                        style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    GestureDetector(
                      onTap: _generating ? null : _generate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.foreground,
                          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                        ),
                        child: _generating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5, color: Colors.white))
                            : const Text('Generate',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('EXAMPLES',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedLight,
                letterSpacing: 1.2)),
        const SizedBox(height: 10),
        ...['Customer satisfaction survey',
            'Job application for product designer',
            'Event registration form',
            'Employee onboarding checklist']
            .map((ex) => GestureDetector(
                  onTap: () => setState(() => _promptCtrl.text = ex),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(ex,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.foregroundMuted)),
                        const Icon(Icons.arrow_forward, size: 14, color: AppColors.mutedLight),
                      ],
                    ),
                  ),
                )),
      ],
    );
  }

  Widget _buildMyForms() {
    final filtered = _userForms
        .where((f) => (f['name'] as String? ?? '')
            .toLowerCase()
            .contains(_search.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppConstants.spacingMD),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(fontSize: 13, color: AppColors.foreground),
                  decoration: InputDecoration(
                    hintText: 'Search forms...',
                    prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.muted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                        borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                        borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                        borderSide: const BorderSide(color: AppColors.foreground)),
                    filled: true,
                    fillColor: AppColors.bgSurfaceHover,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _loadForms,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _loadingForms
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: AppColors.muted))
                      : const Icon(Icons.refresh, size: 16, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loadingForms
              ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.muted))
              : filtered.isEmpty
                  ? const Center(
                      child: Text('No forms found.',
                          style: TextStyle(fontSize: 14, color: AppColors.muted)))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final form = filtered[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.list_alt_outlined,
                                  size: 16, color: AppColors.mutedLight),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(form['name'] as String? ?? 'Untitled',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.foreground),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text(
                                      _formatDate(form['modifiedTime'] as String?),
                                      style: const TextStyle(
                                          fontSize: 11, color: AppColors.mutedLight),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.north_east,
                                  size: 13, color: AppColors.mutedLight),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  String _formatDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

class _FormEditor extends StatefulWidget {
  final Map<String, dynamic> form;
  final TextEditingController editCtrl;
  final bool editLoading;
  final bool publishing;
  final VoidCallback onEditWithAI;
  final VoidCallback onPublish;
  final VoidCallback onDiscard;
  final ValueChanged<Map<String, dynamic>> onUpdateForm;

  const _FormEditor({
    required this.form,
    required this.editCtrl,
    required this.editLoading,
    required this.publishing,
    required this.onEditWithAI,
    required this.onPublish,
    required this.onDiscard,
    required this.onUpdateForm,
  });

  @override
  State<_FormEditor> createState() => _FormEditorState();
}

class _FormEditorState extends State<_FormEditor> {
  late Map<String, dynamic> _form;

  @override
  void initState() {
    super.initState();
    _form = Map<String, dynamic>.from(widget.form);
  }

  void _updateItem(int index, Map<String, dynamic> updated) {
    final items = List<Map<String, dynamic>>.from(
        (_form['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
    items[index] = updated;
    setState(() => _form = {..._form, 'items': items});
    widget.onUpdateForm(_form);
  }

  void _removeItem(int index) {
    final items = List<Map<String, dynamic>>.from(
        (_form['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
    items.removeAt(index);
    setState(() => _form = {..._form, 'items': items});
    widget.onUpdateForm(_form);
  }

  void _addItem() {
    final items = List<Map<String, dynamic>>.from(
        (_form['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
    items.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'title': 'New Question',
      'type': 'TEXT',
      'required': false,
      'options': <String>[],
    });
    setState(() => _form = {..._form, 'items': items});
    widget.onUpdateForm(_form);
  }

  @override
  Widget build(BuildContext context) {
    final items = (_form['items'] as List?) ?? [];

    return Column(
      children: [
        // AI edit bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.editCtrl,
                  onSubmitted: (_) => widget.onEditWithAI(),
                  style: const TextStyle(fontSize: 13, color: AppColors.foreground),
                  decoration: InputDecoration(
                    hintText: 'Refine with AI — e.g. Add a portfolio question...',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.mutedLight),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                        borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                        borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                        borderSide: const BorderSide(color: AppColors.foreground)),
                    filled: true,
                    fillColor: AppColors.bgSurfaceHover,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.editLoading ? null : widget.onEditWithAI,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.foreground,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                  ),
                  child: widget.editLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                      : const Text('Apply',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        // Form content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppConstants.spacingMD),
            children: [
              // Title
              TextField(
                controller: TextEditingController(text: _form['title'] as String? ?? ''),
                onChanged: (v) {
                  _form = {..._form, 'title': v};
                  widget.onUpdateForm(_form);
                },
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground),
                decoration: const InputDecoration(
                  hintText: 'Form Title',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  filled: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: TextEditingController(text: _form['description'] as String? ?? ''),
                onChanged: (v) {
                  _form = {..._form, 'description': v};
                  widget.onUpdateForm(_form);
                },
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
                decoration: const InputDecoration(
                  hintText: 'Description',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  filled: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              ...items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = Map<String, dynamic>.from(entry.value as Map);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _QuestionCard(
                    index: i,
                    item: item,
                    onUpdate: (updated) => _updateItem(i, updated),
                    onRemove: () => _removeItem(i),
                  ),
                );
              }),
              // Add question
              GestureDetector(
                onTap: _addItem,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppColors.border, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add, size: 14, color: AppColors.muted),
                      SizedBox(width: 6),
                      Text('Add Question',
                          style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.onDiscard,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Center(
                          child: Text('Discard',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.muted)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.publishing ? null : widget.onPublish,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.foreground,
                          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                        ),
                        child: Center(
                          child: widget.publishing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5, color: Colors.white))
                              : const Text('Publish to Google',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> item;
  final ValueChanged<Map<String, dynamic>> onUpdate;
  final VoidCallback onRemove;

  const _QuestionCard({
    required this.index,
    required this.item,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final type = item['type'] as String? ?? 'TEXT';
    final required = item['required'] as bool? ?? false;
    final options = (item['options'] as List?)?.cast<String>() ?? [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${index + 1}.',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.mutedLight)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: item['title'] as String? ?? ''),
                  onChanged: (v) => onUpdate({...item, 'title': v}),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Question text',
                    hintStyle: TextStyle(fontSize: 14, color: AppColors.mutedLight),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.mutedLight),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Type selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: type,
                    isDense: true,
                    items: ['TEXT', 'CHOICE', 'CHECKBOX', 'SCALE']
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                {'TEXT': 'Text', 'CHOICE': 'Choice', 'CHECKBOX': 'Checkbox', 'SCALE': 'Scale'}[t]!,
                                style: const TextStyle(fontSize: 11, color: AppColors.foreground),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => onUpdate({...item, 'type': v}),
                    style: const TextStyle(fontSize: 11, color: AppColors.foreground),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Required toggle
              GestureDetector(
                onTap: () => onUpdate({...item, 'required': !required}),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: required ? AppColors.foreground : AppColors.bgSurfaceHover,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                    border: Border.all(
                        color: required ? AppColors.foreground : AppColors.border),
                  ),
                  child: Text(
                    required ? 'Required' : 'Optional',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: required ? Colors.white : AppColors.muted),
                  ),
                ),
              ),
            ],
          ),
          if ((type == 'CHOICE' || type == 'CHECKBOX') && options.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...options.asMap().entries.map((e) => Row(
                  children: [
                    Icon(
                      type == 'CHOICE' ? Icons.radio_button_unchecked : Icons.check_box_outline_blank,
                      size: 14,
                      color: AppColors.mutedLight,
                    ),
                    const SizedBox(width: 8),
                    Text(e.value,
                        style: const TextStyle(fontSize: 12, color: AppColors.foregroundMuted)),
                  ],
                )),
          ],
          if (type == 'SCALE') ...[
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                5,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Text('${i + 1}',
                          style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String url;
  final VoidCallback onNew;

  const _SuccessView({required this.url, required this.onNew});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceHover,
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.check, size: 22, color: AppColors.foreground),
            ),
            const SizedBox(height: 16),
            const Text('Form Published',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground)),
            const SizedBox(height: 6),
            const Text('Your Google Form is live and ready to share.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: onNew,
                child: const Text('Create New Form'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.foreground : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.foreground : AppColors.muted,
          ),
        ),
      ),
    );
  }
}