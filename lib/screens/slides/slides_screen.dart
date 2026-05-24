import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';

class SlidesScreen extends StatefulWidget {
  const SlidesScreen({super.key});

  @override
  State<SlidesScreen> createState() => _SlidesScreenState();
}

class _SlidesScreenState extends State<SlidesScreen> {
  int _tab = 0; // 0 = builder, 1 = my slides

  // Builder
  final TextEditingController _promptCtrl = TextEditingController();
  bool _generating = false;
  Map<String, dynamic>? _deck;
  bool _publishing = false;
  String? _publishedUrl;
  final TextEditingController _editCtrl = TextEditingController();
  bool _editLoading = false;

  // My Slides
  List<Map<String, dynamic>> _userSlides = [];
  bool _loadingSlides = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  // Preview
  int _previewIndex = 0;
  bool _previewing = false;

  // Insight panel
  bool _showInsight = false;
  final TextEditingController _insightCtrl = TextEditingController();
  bool _insightLoading = false;
  final List<Map<String, String>> _insightMessages = [];

  @override
  void dispose() {
    _promptCtrl.dispose();
    _editCtrl.dispose();
    _searchCtrl.dispose();
    _insightCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_promptCtrl.text.trim().isEmpty) return;
    setState(() {
      _generating = true;
      _publishedUrl = null;
    });
    try {
      final result = await ApiClient.post('/api/slides/generate', {
        'description': _promptCtrl.text.trim(),
      });
      final slides = (result['slides'] as List? ?? []).map((s) {
        final m = Map<String, dynamic>.from(s as Map);
        m['id'] ??= DateTime.now().microsecondsSinceEpoch.toString() + m.hashCode.toString();
        return m;
      }).toList();
      setState(() {
        _deck = {...result, 'slides': slides};
        _promptCtrl.clear();
      });
    } catch (e) {
      _showSnack('Failed to generate: $e');
    } finally {
      setState(() => _generating = false);
    }
  }

  Future<void> _editWithAI() async {
    if (_editCtrl.text.trim().isEmpty || _deck == null) return;
    setState(() => _editLoading = true);
    try {
      final result = await ApiClient.post('/api/slides/edit', {
        'currentStructure': _deck,
        'prompt': _editCtrl.text.trim(),
      });
      final slides = (result['slides'] as List? ?? []).map((s) {
        final m = Map<String, dynamic>.from(s as Map);
        m['id'] ??= DateTime.now().microsecondsSinceEpoch.toString();
        return m;
      }).toList();
      setState(() {
        _deck = {...result, 'slides': slides};
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
    if (_deck == null) return;
    setState(() => _publishing = true);
    try {
      final title = _deck!['title'] as String? ?? 'Presentation';
      final presData = await auth.googleApiClient!.createPresentation(title);
      final presentationId = presData['presentationId'] as String;

      final slides = (_deck!['slides'] as List?) ?? [];
      final theme = (_deck!['theme'] as Map<String, dynamic>?) ??
          {
            'primaryColor': '#1a365d',
            'accentColor': '#c9a84c',
            'textColor': '#1a1a2e',
            'bgColor': '#f8f9fa',
          };

      Map<String, double> hexToRgb(String hex) {
        final h = hex.replaceAll('#', '');
        final r = int.parse(h.substring(0, 2), radix: 16) / 255.0;
        final g = int.parse(h.substring(2, 4), radix: 16) / 255.0;
        final b = int.parse(h.substring(4, 6), radix: 16) / 255.0;
        return {'red': r, 'green': g, 'blue': b};
      }

      final primaryRgb = hexToRgb(theme['primaryColor'] as String? ?? '#1a365d');
      final textRgb = hexToRgb(theme['textColor'] as String? ?? '#1a1a2e');
      final requests = <Map<String, dynamic>>[];

      for (int i = 0; i < slides.length; i++) {
        final slide = slides[i] as Map<String, dynamic>;
        final slideId = 'slide_$i\_${DateTime.now().microsecondsSinceEpoch}';
        final titleBoxId = 'title_$i';
        final bodyBoxId = 'body_$i';

        requests.add({
          'createSlide': {
            'objectId': slideId,
            'insertionIndex': i,
            'slideLayoutReference': {'predefinedLayout': 'BLANK'},
          },
        });

        final isCover = slide['layout'] == 'COVER';
        final bgRgb = isCover ? primaryRgb : hexToRgb(theme['bgColor'] as String? ?? '#f8f9fa');

        requests.add({
          'updatePageProperties': {
            'objectId': slideId,
            'pageProperties': {
              'pageBackgroundFill': {
                'solidFill': {'color': {'rgbColor': bgRgb}},
              },
            },
            'fields': 'pageBackgroundFill',
          },
        });

        // Title box
        final titleColor = isCover ? {'red': 1.0, 'green': 1.0, 'blue': 1.0} : primaryRgb;
        requests.add({
          'createShape': {
            'objectId': titleBoxId,
            'shapeType': 'TEXT_BOX',
            'elementProperties': {
              'pageObjectId': slideId,
              'size': {
                'width': {'magnitude': 600, 'unit': 'PT'},
                'height': {'magnitude': isCover ? 80 : 50, 'unit': 'PT'},
              },
              'transform': {
                'scaleX': 1,
                'scaleY': 1,
                'translateX': 30,
                'translateY': isCover ? 140 : 30,
                'unit': 'PT',
              },
            },
          },
        });
        requests.add({
          'insertText': {'objectId': titleBoxId, 'text': slide['title'] ?? 'Slide'},
        });
        requests.add({
          'updateTextStyle': {
            'objectId': titleBoxId,
            'style': {
              'fontSize': {'magnitude': isCover ? 36 : 22, 'unit': 'PT'},
              'bold': true,
              'fontFamily': 'Georgia',
              'foregroundColor': {
                'opaqueColor': {'rgbColor': titleColor},
              },
            },
            'fields': 'fontSize,bold,fontFamily,foregroundColor',
          },
        });

        // Body box
        final content = slide['content'];
        final contentList = content is List
            ? content.cast<String>()
            : content is String
                ? [content]
                : <String>[];
        if (contentList.isNotEmpty && !isCover) {
          final bodyColor = textRgb;
          requests.add({
            'createShape': {
              'objectId': bodyBoxId,
              'shapeType': 'TEXT_BOX',
              'elementProperties': {
                'pageObjectId': slideId,
                'size': {
                  'width': {'magnitude': 600, 'unit': 'PT'},
                  'height': {'magnitude': 250, 'unit': 'PT'},
                },
                'transform': {
                  'scaleX': 1,
                  'scaleY': 1,
                  'translateX': 30,
                  'translateY': 100,
                  'unit': 'PT',
                },
              },
            },
          });
          requests.add({
            'insertText': {
              'objectId': bodyBoxId,
              'text': contentList.join('\n'),
            },
          });
          requests.add({
            'updateTextStyle': {
              'objectId': bodyBoxId,
              'style': {
                'fontSize': {'magnitude': 13, 'unit': 'PT'},
                'fontFamily': 'Georgia',
                'foregroundColor': {
                  'opaqueColor': {'rgbColor': bodyColor},
                },
              },
              'fields': 'fontSize,fontFamily,foregroundColor',
            },
          });
        }
      }

      await auth.googleApiClient!.updatePresentationBatch(presentationId, requests);
      setState(() {
        _publishedUrl = 'https://docs.google.com/presentation/d/$presentationId/edit';
        _deck = null;
      });
    } catch (e) {
      _showSnack('Failed to publish: $e');
    } finally {
      setState(() => _publishing = false);
    }
  }

  Future<void> _loadSlides() async {
    final auth = context.read<AuthProvider>();
    if (auth.googleApiClient == null) return;
    setState(() => _loadingSlides = true);
    try {
      final slides = await auth.googleApiClient!.fetchDriveFiles(
        query: "mimeType = 'application/vnd.google-apps.presentation' and trashed = false",
        orderBy: 'modifiedTime desc',
      );
      setState(() => _userSlides = slides);
    } catch (e) {
      _showSnack('Failed to load slides: $e');
    } finally {
      setState(() => _loadingSlides = false);
    }
  }

  Future<void> _askInsight(String question) async {
    if (_deck == null) return;
    setState(() {
      _insightLoading = true;
      _insightMessages.add({'role': 'user', 'text': question});
    });
    try {
      final result = await ApiClient.post('/api/slides/ask', {
        'slides': (_deck!['slides'] as List?) ?? [],
        'question': question,
        'history': _insightMessages
            .map((m) => {
                  'role': m['role'] == 'user' ? 'user' : 'model',
                  'parts': [{'text': m['text']}],
                })
            .toList(),
      });
      setState(() =>
          _insightMessages.add({'role': 'model', 'text': result['answer'] as String? ?? ''}));
    } catch (e) {
      setState(() => _insightMessages.add({'role': 'model', 'text': 'Error: $e'}));
    } finally {
      setState(() => _insightLoading = false);
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
    // Preview overlay
    if (_previewing && _deck != null) {
      return _PreviewOverlay(
        deck: _deck!,
        initialIndex: _previewIndex,
        onClose: () => setState(() => _previewing = false),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('Presentations'),
        actions: _deck != null
            ? [
                IconButton(
                  icon: const Icon(Icons.slideshow_outlined, size: 20),
                  onPressed: () => setState(() {
                    _previewIndex = 0;
                    _previewing = true;
                  }),
                  tooltip: 'Present',
                ),
                IconButton(
                  icon: Icon(
                    _showInsight ? Icons.chat_bubble : Icons.chat_bubble_outline,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _showInsight = !_showInsight),
                  tooltip: 'Insights',
                ),
              ]
            : null,
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
                    label: 'My Slides',
                    selected: _tab == 1,
                    onTap: () {
                      setState(() => _tab = 1);
                      _loadSlides();
                    },
                  ),
                ],
              ),
              const Divider(height: 1),
            ],
          ),
        ),
      ),
      body: _tab == 0 ? _buildBuilder() : _buildMySlides(),
    );
  }

  Widget _buildBuilder() {
    if (_publishedUrl != null) {
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
              const Text('Presentation Created',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground)),
              const SizedBox(height: 8),
              const Text(
                'Your Google Slides deck has been published.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => setState(() {
                    _publishedUrl = null;
                    _promptCtrl.clear();
                  }),
                  child: const Text('Create New Deck'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_deck != null) {
      return Row(
        children: [
          Expanded(
            child: Column(
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
                          controller: _editCtrl,
                          onSubmitted: (_) => _editWithAI(),
                          style: const TextStyle(fontSize: 13, color: AppColors.foreground),
                          decoration: InputDecoration(
                            hintText: 'Edit with AI — e.g. Add a market analysis slide...',
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
                        onTap: _editLoading ? null : _editWithAI,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.foreground,
                            borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                          ),
                          child: _editLoading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5, color: Colors.white))
                              : const Text('Apply',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
                // Deck editor
                Expanded(
                  child: _DeckEditor(
                    deck: _deck!,
                    publishing: _publishing,
                    onPublish: _publish,
                    onDiscard: () => setState(() => _deck = null),
                    onUpdateDeck: (updated) => setState(() => _deck = updated),
                    onPreview: (index) => setState(() {
                      _previewIndex = index;
                      _previewing = true;
                    }),
                  ),
                ),
              ],
            ),
          ),
          // Insight panel
          if (_showInsight)
            _InsightPanel(
              messages: _insightMessages,
              loading: _insightLoading,
              inputCtrl: _insightCtrl,
              onSend: (q) {
                _insightCtrl.clear();
                _askInsight(q);
              },
              onClose: () => setState(() => _showInsight = false),
            ),
        ],
      );
    }

    // Prompt view
    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingMD),
      children: [
        const Text('Describe your presentation',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground)),
        const SizedBox(height: 6),
        const Text('AI will generate a full slide deck with speaker notes.',
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
                      'e.g. A 12-slide pitch deck for a Series A SaaS startup targeting enterprise HR teams.',
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
                    const Text('AI will generate 10-14 slides with notes',
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
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                            : const Text('Generate Deck',
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
        ...['Series A pitch deck for a B2B SaaS startup',
            'Quarterly business review for Q3',
            'Go-to-market strategy for a new product',
            'Market entry analysis for Southeast Asia']
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
                        Expanded(
                          child: Text(ex,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.foregroundMuted)),
                        ),
                        const Icon(Icons.arrow_forward, size: 14, color: AppColors.mutedLight),
                      ],
                    ),
                  ),
                )),
      ],
    );
  }

  Widget _buildMySlides() {
    final filtered = _userSlides
        .where((s) => (s['name'] as String? ?? '')
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
                    hintText: 'Search presentations...',
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
                onTap: _loadSlides,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _loadingSlides
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
          child: _loadingSlides
              ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.muted))
              : filtered.isEmpty
                  ? const Center(
                      child: Text('No presentations found.',
                          style: TextStyle(fontSize: 14, color: AppColors.muted)))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final slide = filtered[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.slideshow_outlined,
                                  size: 18, color: AppColors.mutedLight),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(slide['name'] as String? ?? 'Untitled',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.foreground),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text(
                                      _formatDate(slide['modifiedTime'] as String?),
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

class _DeckEditor extends StatelessWidget {
  final Map<String, dynamic> deck;
  final bool publishing;
  final VoidCallback onPublish;
  final VoidCallback onDiscard;
  final ValueChanged<Map<String, dynamic>> onUpdateDeck;
  final ValueChanged<int> onPreview;

  const _DeckEditor({
    required this.deck,
    required this.publishing,
    required this.onPublish,
    required this.onDiscard,
    required this.onUpdateDeck,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final slides = (deck['slides'] as List?) ?? [];
    final theme = (deck['theme'] as Map<String, dynamic>?) ?? {};
    final primaryColor =
        _hexColor(theme['primaryColor'] as String? ?? '#1a365d');
    final accentColor =
        _hexColor(theme['accentColor'] as String? ?? '#c9a84c');

    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingMD),
      children: [
        // Deck header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deck['title'] as String? ?? 'Untitled',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground)),
                  Text('${slides.length} slides',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            // Theme dots
            Row(
              children: [primaryColor, accentColor]
                  .map((c) => Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(left: 4),
                        decoration:
                            BoxDecoration(color: c, shape: BoxShape.circle),
                      ))
                  .toList(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Action buttons
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onDiscard,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text('Discard',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: publishing ? null : onPublish,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.foreground,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                  ),
                  child: Center(
                    child: publishing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: Colors.white))
                        : const Text('Publish to Google',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        // Slide cards
        ...slides.asMap().entries.map((entry) {
          final i = entry.key;
          final slide = Map<String, dynamic>.from(entry.value as Map);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SlideCard(
              index: i,
              slide: slide,
              primaryColor: primaryColor,
              accentColor: accentColor,
              onTap: () => onPreview(i),
              onUpdateSlide: (updated) {
                final updatedSlides = List<dynamic>.from(slides);
                updatedSlides[i] = updated;
                onUpdateDeck({...deck, 'slides': updatedSlides});
              },
              onRemove: () {
                final updatedSlides = List<dynamic>.from(slides)..removeAt(i);
                onUpdateDeck({...deck, 'slides': updatedSlides});
              },
            ),
          );
        }),
        // Add slide
        GestureDetector(
          onTap: () {
            final updatedSlides = List<dynamic>.from(slides)
              ..add({
                'id': DateTime.now().microsecondsSinceEpoch.toString(),
                'title': 'New Slide',
                'content': [],
                'layout': 'CONTENT',
                'notes': '',
              });
            onUpdateDeck({...deck, 'slides': updatedSlides});
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.add, size: 14, color: AppColors.muted),
                SizedBox(width: 6),
                Text('Add Slide',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Color _hexColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF1a365d);
    }
  }
}

class _SlideCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> slide;
  final Color primaryColor;
  final Color accentColor;
  final VoidCallback onTap;
  final ValueChanged<Map<String, dynamic>> onUpdateSlide;
  final VoidCallback onRemove;

  const _SlideCard({
    required this.index,
    required this.slide,
    required this.primaryColor,
    required this.accentColor,
    required this.onTap,
    required this.onUpdateSlide,
    required this.onRemove,
  });

  @override
  State<_SlideCard> createState() => _SlideCardState();
}

class _SlideCardState extends State<_SlideCard> {
  bool _expanded = false;
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.slide['title'] as String? ?? '');
    final content = widget.slide['content'];
    final contentStr = content is List
        ? content.join('\n')
        : content?.toString() ?? '';
    _contentCtrl = TextEditingController(text: contentStr);
    _notesCtrl = TextEditingController(text: widget.slide['notes'] as String? ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Preview thumbnail
                  GestureDetector(
                    onTap: widget.onTap,
                    child: Container(
                      width: 60,
                      height: 38,
                      decoration: BoxDecoration(
                        color: widget.primaryColor,
                        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 3,
                              decoration: BoxDecoration(
                                color: widget.accentColor,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(AppConstants.radiusSM),
                                  bottomLeft: Radius.circular(AppConstants.radiusSM),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
                            child: Text(
                              widget.slide['title'] as String? ?? '',
                              style: const TextStyle(
                                  fontSize: 5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${(widget.index + 1).toString().padLeft(2, '0')}.',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.mutedLight),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.slide['title'] as String? ?? 'Untitled',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.foreground),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          widget.slide['layout'] as String? ?? 'CONTENT',
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.mutedLight),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: AppColors.mutedLight),
                    onPressed: widget.onRemove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppColors.mutedLight,
                  ),
                ],
              ),
            ),
          ),
          // Expanded edit fields
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Title'),
                  const SizedBox(height: 4),
                  _EditField(
                    controller: _titleCtrl,
                    onChanged: (v) => widget.onUpdateSlide({...widget.slide, 'title': v}),
                  ),
                  const SizedBox(height: 10),
                  _FieldLabel('Content (one bullet per line)'),
                  const SizedBox(height: 4),
                  _EditField(
                    controller: _contentCtrl,
                    maxLines: 4,
                    onChanged: (v) => widget.onUpdateSlide({
                      ...widget.slide,
                      'content': v.split('\n').where((l) => l.isNotEmpty).toList(),
                    }),
                  ),
                  const SizedBox(height: 10),
                  _FieldLabel('Speaker Notes'),
                  const SizedBox(height: 4),
                  _EditField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    onChanged: (v) => widget.onUpdateSlide({...widget.slide, 'notes': v}),
                    monospace: true,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
        style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.mutedLight,
            letterSpacing: 0.8));
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final bool monospace;

  const _EditField({
    required this.controller,
    required this.onChanged,
    this.maxLines = 1,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      style: TextStyle(
        fontSize: 13,
        color: AppColors.foreground,
        fontFamily: monospace ? 'monospace' : null,
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            borderSide: const BorderSide(color: AppColors.foreground)),
        filled: true,
        fillColor: AppColors.bgSurfaceHover,
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  final List<Map<String, String>> messages;
  final bool loading;
  final TextEditingController inputCtrl;
  final ValueChanged<String> onSend;
  final VoidCallback onClose;

  const _InsightPanel({
    required this.messages,
    required this.loading,
    required this.inputCtrl,
    required this.onSend,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Text('Insights',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground)),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close, size: 16, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Messages
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text('Ask anything about this deck.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.muted)))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: messages.length + (loading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (loading && i == messages.length) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: AppColors.muted),
                          ),
                        );
                      }
                      final msg = messages[i];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 200),
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: isUser
                                ? AppColors.foreground
                                : AppColors.bgSurfaceHover,
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusSM),
                            border: isUser
                                ? null
                                : Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            msg['text'] ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              color: isUser ? Colors.white : AppColors.foregroundMuted,
                              height: 1.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          // Input
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: inputCtrl,
                    onSubmitted: onSend,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.foreground),
                    decoration: InputDecoration(
                      hintText: 'Ask about this deck...',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: AppColors.mutedLight),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusSM),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusSM),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusSM),
                          borderSide:
                              const BorderSide(color: AppColors.foreground)),
                      filled: true,
                      fillColor: AppColors.bgSurfaceHover,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    if (inputCtrl.text.trim().isNotEmpty) {
                      onSend(inputCtrl.text.trim());
                    }
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.foreground,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusSM),
                    ),
                    child: const Icon(Icons.send, size: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewOverlay extends StatefulWidget {
  final Map<String, dynamic> deck;
  final int initialIndex;
  final VoidCallback onClose;

  const _PreviewOverlay({
    required this.deck,
    required this.initialIndex,
    required this.onClose,
  });

  @override
  State<_PreviewOverlay> createState() => _PreviewOverlayState();
}

class _PreviewOverlayState extends State<_PreviewOverlay> {
  late int _current;
  late List slides;
  late Map<String, dynamic> theme;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    slides = (widget.deck['slides'] as List?) ?? [];
    theme = (widget.deck['theme'] as Map<String, dynamic>?) ?? {};
  }

  Color _hexColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF1a365d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = slides.isNotEmpty ? slides[_current] as Map<String, dynamic> : {};
    final primaryColor = _hexColor(theme['primaryColor'] as String? ?? '#1a365d');
    final accentColor = _hexColor(theme['accentColor'] as String? ?? '#c9a84c');
    final textColor = _hexColor(theme['textColor'] as String? ?? '#1a1a2e');
    final bgColor = _hexColor(theme['bgColor'] as String? ?? '#f8f9fa');
    final isCover = slide['layout'] == 'COVER';
    final content = slide['content'];
    final contentList = content is List
        ? content.cast<String>()
        : content is String
            ? content.split('\n')
            : <String>[];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text(widget.deck['title'] as String? ?? '',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12)),
                  const Spacer(),
                  Text('${_current + 1} / ${slides.length}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: const Icon(Icons.close, color: Colors.white60, size: 18),
                  ),
                ],
              ),
            ),
            // Slide content
            Expanded(
              child: GestureDetector(
                onTapDown: (details) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  if (details.globalPosition.dx > screenWidth / 2) {
                    if (_current < slides.length - 1) {
                      setState(() => _current++);
                    }
                  } else {
                    if (_current > 0) {
                      setState(() => _current--);
                    }
                  }
                },
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCover ? primaryColor : bgColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Stack(
                          children: [
                            // Left accent bar
                            if (!isCover)
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 6,
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      bottomLeft: Radius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            // Top-right accent line
                            if (!isCover)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  width: 80,
                                  height: 3,
                                  color: accentColor,
                                ),
                              ),
                            // Content
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                  isCover ? 32 : 24, isCover ? 40 : 20, 24, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    slide['title'] as String? ?? '',
                                    style: TextStyle(
                                      fontSize: isCover ? 20 : 14,
                                      fontWeight: FontWeight.w700,
                                      color: isCover ? Colors.white : primaryColor,
                                      height: 1.2,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (slide['subtitle'] != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      slide['subtitle'] as String,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: isCover
                                            ? Colors.white60
                                            : textColor.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                  if (!isCover && contentList.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: contentList.take(6).map((point) {
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 5),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.only(
                                                      top: 3, right: 5),
                                                  child: Container(
                                                    width: 4,
                                                    height: 4,
                                                    decoration: BoxDecoration(
                                                      color: accentColor,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    point,
                                                    style: TextStyle(
                                                        fontSize: 7,
                                                        color: textColor,
                                                        height: 1.5),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Slide number
                            Positioned(
                              bottom: 8,
                              right: 12,
                              child: Text(
                                '${(_current + 1).toString().padLeft(2, '0')} / ${slides.length.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 6,
                                  color: isCover
                                      ? Colors.white38
                                      : textColor.withOpacity(0.3),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Dot indicators + speaker notes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white38),
                        onPressed: _current > 0
                            ? () => setState(() => _current--)
                            : null,
                      ),
                      ...slides.asMap().entries.map((e) {
                        final active = e.key == _current;
                        return GestureDetector(
                          onTap: () => setState(() => _current = e.key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: active ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: active ? Colors.white : Colors.white24,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      }),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Colors.white38),
                        onPressed: _current < slides.length - 1
                            ? () => setState(() => _current++)
                            : null,
                      ),
                    ],
                  ),
                  // Notes
                  if ((slide['notes'] as String?)?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        slide['notes'] as String,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10, height: 1.4),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
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