import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';

class DriveScreen extends StatefulWidget {
  const DriveScreen({super.key});

  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends State<DriveScreen> {
  List<Map<String, dynamic>> _files = [];
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _selected;
  String? _aiSummary;
  bool _aiLoading = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final List<_Crumb> _breadcrumbs = [const _Crumb('Drive', 'root')];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        _loadFiles(_breadcrumbs.last.id));
  }

  Future<void> _loadFiles(String folderId, [String query = '']) async {
    final auth = context.read<AuthProvider>();
    if (auth.googleApiClient == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      String q = "trashed=false and '$folderId' in parents";
      if (query.isNotEmpty) {
        q = "trashed=false and name contains '${query.replaceAll("'", "\\'")}'";
      }
      final files = await auth.googleApiClient!.fetchDriveFiles(query: q);
      setState(() => _files = files);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _summarize(Map<String, dynamic> file) async {
    final auth = context.read<AuthProvider>();
    if (auth.googleApiClient == null) return;
    setState(() {
      _aiLoading = true;
      _aiSummary = null;
    });
    try {
      final content = await auth.googleApiClient!.fetchDriveFileContent(
        file['id'] as String,
        file['mimeType'] as String,
      );
      final result = await ApiClient.post('/api/summarise/doc', {
        'content': content.substring(0, content.length.clamp(0, 10000)),
      });
      setState(() => _aiSummary = result['summary'] as String?);
    } catch (e) {
      setState(() => _aiSummary = 'Error: $e');
    } finally {
      setState(() => _aiLoading = false);
    }
  }

  void _openFolder(Map<String, dynamic> file) {
    setState(() {
      _selected = null;
      _aiSummary = null;
      _breadcrumbs.add(_Crumb(file['name'] as String, file['id'] as String));
    });
    _loadFiles(file['id'] as String);
  }

  void _navigateTo(int index) {
    final crumb = _breadcrumbs[index];
    setState(() {
      _breadcrumbs.removeRange(index + 1, _breadcrumbs.length);
      _selected = null;
      _aiSummary = null;
    });
    _loadFiles(crumb.id);
  }

  Future<void> _openInDrive(String? url) async {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.googleApiClient == null) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: AppBar(
          title: const Text('Drive'),
          bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.folder_outlined,
                    size: 40, color: AppColors.mutedLight),
                const SizedBox(height: 16),
                const Text('Connect Google Drive',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground)),
                const SizedBox(height: 8),
                const Text('Sign in with Google to browse your Drive.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: auth.signIn,
                    child: const Text('Connect Account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('Drive'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _loadFiles(_breadcrumbs.last.id),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (q) => _loadFiles(_breadcrumbs.last.id, q),
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.foreground),
                  decoration: InputDecoration(
                    hintText: 'Search Drive...',
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: AppColors.muted),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                      borderSide:
                          const BorderSide(color: AppColors.foreground),
                    ),
                    filled: true,
                    fillColor: AppColors.bgSurfaceHover,
                  ),
                ),
              ),
              const Divider(height: 1),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Breadcrumbs
          if (_breadcrumbs.length > 1)
            Container(
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.bgSurface,
                border: Border(
                    bottom: BorderSide(color: AppColors.border)),
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _breadcrumbs.length,
                separatorBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right,
                      size: 14, color: AppColors.mutedLight),
                ),
                itemBuilder: (_, i) {
                  final crumb = _breadcrumbs[i];
                  final isLast = i == _breadcrumbs.length - 1;
                  return GestureDetector(
                    onTap: isLast ? null : () => _navigateTo(i),
                    child: Center(
                      child: Text(
                        crumb.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isLast
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isLast
                              ? AppColors.foreground
                              : AppColors.muted,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          // File detail
          if (_selected != null)
            _FileDetail(
              file: _selected!,
              aiSummary: _aiSummary,
              aiLoading: _aiLoading,
              onClose: () => setState(() {
                _selected = null;
                _aiSummary = null;
              }),
              onOpen: () => _openInDrive(_selected!['webViewLink'] as String?),
              onAnalyze: () => _summarize(_selected!),
            ),
          // File list
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.error)),
                    ),
                  )
                : _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.muted))
                    : _files.isEmpty
                        ? const Center(
                            child: Text('No files found.',
                                style: TextStyle(
                                    fontSize: 14, color: AppColors.muted)))
                        : ListView.separated(
                            itemCount: _files.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final file = _files[i];
                              final isFolder = (file['mimeType'] as String?)
                                      ?.contains('folder') ==
                                  true;
                              return InkWell(
                                onTap: () {
                                  if (isFolder) {
                                    _openFolder(file);
                                  } else {
                                    setState(() {
                                      _selected = file;
                                      _aiSummary = null;
                                    });
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _mimeIcon(
                                            file['mimeType'] as String? ??
                                                ''),
                                        size: 18,
                                        color: isFolder
                                            ? AppColors.foreground
                                            : AppColors.mutedLight,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              file['name'] as String? ??
                                                  'Untitled',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400,
                                                color: AppColors.foreground,
                                              ),
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              _formatDate(file['modifiedTime']
                                                  as String?),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.mutedLight),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        isFolder
                                            ? Icons.chevron_right
                                            : Icons.north_east,
                                        size: 14,
                                        color: AppColors.mutedLight,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  IconData _mimeIcon(String mime) {
    if (mime.contains('folder')) return Icons.folder_outlined;
    if (mime.contains('document')) return Icons.description_outlined;
    if (mime.contains('spreadsheet')) return Icons.table_chart_outlined;
    if (mime.contains('presentation')) return Icons.slideshow_outlined;
    if (mime.contains('pdf')) return Icons.picture_as_pdf_outlined;
    return Icons.insert_drive_file_outlined;
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

class _Crumb {
  final String name;
  final String id;
  const _Crumb(this.name, this.id);
}

class _FileDetail extends StatelessWidget {
  final Map<String, dynamic> file;
  final String? aiSummary;
  final bool aiLoading;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  final VoidCallback onAnalyze;

  const _FileDetail({
    required this.file,
    required this.aiSummary,
    required this.aiLoading,
    required this.onClose,
    required this.onOpen,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.all(AppConstants.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_mimeIcon(file['mimeType'] as String? ?? ''),
                  size: 16, color: AppColors.foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  file['name'] as String? ?? 'Untitled',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClose,
                color: AppColors.muted,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ActionBtn(
                  label: 'Open in Drive',
                  icon: Icons.open_in_new,
                  onTap: onOpen),
              const SizedBox(width: 8),
              _ActionBtn(
                label: aiLoading ? 'Analyzing...' : 'Analyze',
                icon: Icons.auto_awesome_outlined,
                onTap: aiLoading ? null : onAnalyze,
                primary: true,
              ),
            ],
          ),
          if (aiSummary != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceHover,
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusMD),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                aiSummary!,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.foregroundMuted,
                    height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _mimeIcon(String mime) {
    if (mime.contains('folder')) return Icons.folder_outlined;
    if (mime.contains('document')) return Icons.description_outlined;
    if (mime.contains('spreadsheet')) return Icons.table_chart_outlined;
    if (mime.contains('presentation')) return Icons.slideshow_outlined;
    if (mime.contains('pdf')) return Icons.picture_as_pdf_outlined;
    return Icons.insert_drive_file_outlined;
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  const _ActionBtn({
    required this.label,
    required this.icon,
    this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: primary ? AppColors.foreground : AppColors.bgSurfaceHover,
          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          border: Border.all(
              color: primary ? AppColors.foreground : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: primary ? Colors.white : AppColors.foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primary ? Colors.white : AppColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}