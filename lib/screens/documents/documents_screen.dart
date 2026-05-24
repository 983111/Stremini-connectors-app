import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/api_client.dart';
import '../../providers/documents_provider.dart';
import '../../providers/auth_provider.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  DocumentModel? _selected;

  @override
  Widget build(BuildContext context) {
    final docs = context.watch<DocumentsProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: _selected == null
            ? const Text('Documents')
            : Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _selected = null),
                    child: const Icon(Icons.arrow_back_ios_new,
                        size: 16, color: AppColors.foreground),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selected?.title ?? '',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
        actions: [
          if (_selected == null)
            IconButton(
              icon: const Icon(Icons.add, size: 22),
              onPressed: () async {
                final doc = await docs.createDocument();
                setState(() => _selected = doc);
              },
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: _selected == null
          ? _DocList(
              documents: docs.documents,
              onSelect: (d) => setState(() => _selected = d),
              onDelete: (d) => docs.deleteDocument(d.id),
            )
          : _DocEditor(
              doc: _selected!,
              onUpdate: (title, content) {
                docs.updateDocument(_selected!.id,
                    title: title, content: content);
                setState(() {
                  _selected = _selected!.copyWith(
                      title: title, content: content);
                });
              },
            ),
    );
  }
}

class _DocList extends StatelessWidget {
  final List<DocumentModel> documents;
  final ValueChanged<DocumentModel> onSelect;
  final ValueChanged<DocumentModel> onDelete;

  const _DocList({
    required this.documents,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.description_outlined,
                size: 40, color: AppColors.mutedLight),
            SizedBox(height: 16),
            Text('No documents yet.',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground)),
            SizedBox(height: 6),
            Text('Tap + to create your first document.',
                style: TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppConstants.spacingMD),
      itemCount: documents.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppConstants.spacingSM),
      itemBuilder: (_, i) {
        final doc = documents[i];
        return _DocTile(
          doc: doc,
          onTap: () => onSelect(doc),
          onDelete: () => onDelete(doc),
        );
      },
    );
  }
}

class _DocTile extends StatelessWidget {
  final DocumentModel doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DocTile({
    required this.doc,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingMD),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.article_outlined,
                size: 18, color: AppColors.mutedLight),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDate(doc.updatedAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.mutedLight),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.mutedLight),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete document?'),
                    content: Text('Delete "${doc.title}"?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onDelete();
                        },
                        child: const Text('Delete',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _DocEditor extends StatefulWidget {
  final DocumentModel doc;
  final void Function(String title, String content) onUpdate;

  const _DocEditor({required this.doc, required this.onUpdate});

  @override
  State<_DocEditor> createState() => _DocEditorState();
}

class _DocEditorState extends State<_DocEditor> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  bool _aiLoading = false;
  final List<_ChatMessage> _messages = [];
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _showChat = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.doc.title);
    _contentCtrl = TextEditingController(text: widget.doc.content);
    _titleCtrl.addListener(_save);
    _contentCtrl.addListener(_save);
  }

  void _save() {
    widget.onUpdate(_titleCtrl.text, _contentCtrl.text);
  }

  Future<void> _aiAction(String prompt) async {
    setState(() {
      _aiLoading = true;
      _showChat = true;
      _messages.add(_ChatMessage(role: 'user', text: prompt));
    });
    _scrollToBottom();
    try {
      final result = await ApiClient.post('/api/ask/doc', {
        'content': _contentCtrl.text,
        'question': prompt,
        'history': _messages
            .map((m) => {'role': m.role == 'user' ? 'user' : 'model', 'parts': [{'text': m.text}]})
            .toList(),
      });
      final answer = result['answer'] as String? ?? '';
      setState(() => _messages.add(_ChatMessage(role: 'assistant', text: answer)));
      _scrollToBottom();
    } catch (e) {
      setState(() =>
          _messages.add(_ChatMessage(role: 'assistant', text: 'Error: $e')));
    } finally {
      setState(() => _aiLoading = false);
    }
  }

  Future<void> _rewrite(String tone) async {
    setState(() {
      _aiLoading = true;
      _showChat = true;
      _messages.add(_ChatMessage(role: 'user', text: 'Rewrite this document to be more $tone.'));
    });
    try {
      final result = await ApiClient.post('/api/rewrite/doc', {
        'content': _contentCtrl.text,
        'tone': tone,
      });
      final rewritten = result['rewritten'] as String? ?? '';
      setState(() => _messages.add(_ChatMessage(role: 'assistant', text: rewritten, isContent: true)));
      _scrollToBottom();
    } catch (e) {
      setState(() => _messages.add(_ChatMessage(role: 'assistant', text: 'Error: $e')));
    } finally {
      setState(() => _aiLoading = false);
    }
  }

  Future<void> _summarize() async {
    setState(() {
      _aiLoading = true;
      _showChat = true;
      _messages.add(const _ChatMessage(role: 'user', text: 'Summarize this document.'));
    });
    try {
      final result = await ApiClient.post('/api/summarise/doc', {
        'content': _contentCtrl.text,
      });
      final summary = result['summary'] as String? ?? '';
      setState(() => _messages.add(_ChatMessage(role: 'assistant', text: summary)));
      _scrollToBottom();
    } catch (e) {
      setState(() => _messages.add(_ChatMessage(role: 'assistant', text: 'Error: $e')));
    } finally {
      setState(() => _aiLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendChat() {
    if (_chatCtrl.text.trim().isEmpty) return;
    _aiAction(_chatCtrl.text.trim());
    _chatCtrl.clear();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // AI toolbar
        Container(
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _ToolbarChip(
                label: 'Formal',
                onTap: () => _rewrite('formal'),
              ),
              _ToolbarChip(
                label: 'Casual',
                onTap: () => _rewrite('casual'),
              ),
              _ToolbarChip(
                label: 'Persuasive',
                onTap: () => _rewrite('persuasive'),
              ),
              _ToolbarChip(
                label: 'Summarize',
                onTap: _summarize,
              ),
              _ToolbarChip(
                label: _showChat ? 'Hide Chat' : 'AI Chat',
                onTap: () => setState(() => _showChat = !_showChat),
                highlight: _showChat,
              ),
            ],
          ),
        ),
        // Editor
        Expanded(
          flex: _showChat ? 1 : 2,
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMD),
            child: Column(
              children: [
                TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Document title',
                    hintStyle: TextStyle(color: AppColors.mutedLight),
                    contentPadding: EdgeInsets.zero,
                    fillColor: Colors.transparent,
                    filled: true,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                const Divider(height: 16),
                Expanded(
                  child: TextField(
                    controller: _contentCtrl,
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.foregroundMuted,
                      height: 1.6,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Start writing...',
                      hintStyle: TextStyle(color: AppColors.mutedLight),
                      contentPadding: EdgeInsets.zero,
                      fillColor: Colors.transparent,
                      filled: true,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // AI Chat panel
        if (_showChat)
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.bgSurface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.smart_toy_outlined,
                            size: 15, color: AppColors.foreground),
                        const SizedBox(width: 8),
                        const Text('Assistant',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.foreground)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _messages.clear()),
                          child: const Icon(Icons.refresh,
                              size: 16, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length +
                          (_aiLoading ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (_aiLoading && i == _messages.length) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: AppColors.muted),
                              ),
                            ),
                          );
                        }
                        final msg = _messages[i];
                        return _ChatBubble(
                          message: msg,
                          onApply: msg.isContent
                              ? () {
                                  _contentCtrl.text = msg.text;
                                  _save();
                                }
                              : null,
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatCtrl,
                            onSubmitted: (_) => _sendChat(),
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.foreground),
                            decoration: InputDecoration(
                              hintText: 'Ask about this document...',
                              hintStyle: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.mutedLight),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppConstants.radiusMD),
                                borderSide: const BorderSide(
                                    color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppConstants.radiusMD),
                                borderSide: const BorderSide(
                                    color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppConstants.radiusMD),
                                borderSide: const BorderSide(
                                    color: AppColors.foreground),
                              ),
                              filled: true,
                              fillColor: AppColors.bgBase,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _sendChat,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.foreground,
                              borderRadius: BorderRadius.circular(
                                  AppConstants.radiusMD),
                            ),
                            child: const Icon(Icons.send,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ChatMessage {
  final String role;
  final String text;
  final bool isContent;

  const _ChatMessage({
    required this.role,
    required this.text,
    this.isContent = false,
  });
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  final VoidCallback? onApply;

  const _ChatBubble({required this.message, this.onApply});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isUser
                  ? AppColors.foreground
                  : AppColors.bgSurfaceHover,
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              border: isUser ? null : Border.all(color: AppColors.border),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                fontSize: 13,
                color: isUser ? Colors.white : AppColors.foregroundMuted,
                height: 1.5,
              ),
            ),
          ),
          if (onApply != null)
            GestureDetector(
              onTap: onApply,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'Apply to document',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  const _ToolbarChip({
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: highlight ? AppColors.foreground : AppColors.bgSurfaceHover,
          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          border: Border.all(
              color: highlight ? AppColors.foreground : AppColors.border),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: highlight ? Colors.white : AppColors.foregroundMuted,
            ),
          ),
        ),
      ),
    );
  }
}