import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/documents_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _briefing;
  bool _loadingBriefing = false;
  List<Map<String, dynamic>> _recentFiles = [];
  bool _loadingFiles = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecentFiles());
  }

  Future<void> _loadRecentFiles() async {
    final auth = context.read<AuthProvider>();
    if (auth.googleApiClient == null) return;
    setState(() => _loadingFiles = true);
    try {
      final files = await auth.googleApiClient!.fetchDriveFiles(pageSize: 5);
      setState(() => _recentFiles = files);
    } catch (_) {
    } finally {
      setState(() => _loadingFiles = false);
    }
  }

  Future<void> _runSynthesis() async {
    final auth = context.read<AuthProvider>();
    if (auth.googleApiClient == null) {
      _showSnack('Please sign in with Google first.');
      return;
    }
    setState(() {
      _loadingBriefing = true;
      _briefing = null;
    });
    try {
      final emails = await auth.googleApiClient!
          .fetchRecentEmails(query: 'is:unread', maxResults: 20);
      final files = await auth.googleApiClient!.fetchDriveFiles(pageSize: 10);
      final result = await ApiClient.post('/api/briefing', {
        'emails': emails,
        'driveFiles': files,
      });
      setState(() => _briefing = result['briefing'] as String? ?? '');
    } catch (e) {
      setState(() => _briefing = 'Error: ${e.toString()}');
    } finally {
      setState(() => _loadingBriefing = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontSize: 13, color: Colors.white)),
        backgroundColor: const Color(0xFF111111),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final docs = context.watch<DocumentsProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('Nexus Hub'),
        actions: [
          if (auth.user?.photoURL != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 14,
                backgroundImage: NetworkImage(auth.user!.photoURL!),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.bgSurfaceHover,
                child: const Icon(Icons.person_outline,
                    size: 16, color: AppColors.muted),
              ),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecentFiles,
        color: AppColors.foreground,
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.spacingMD),
          children: [
            // Welcome
            _WelcomeCard(
              userName: auth.user?.displayName?.split(' ').first ?? 'there',
              onRunSynthesis: _runSynthesis,
              isLoading: _loadingBriefing,
              briefing: _briefing,
            ),
            const SizedBox(height: AppConstants.spacingMD),
            // System status
            _StatusCard(isConnected: auth.googleApiClient != null),
            const SizedBox(height: AppConstants.spacingMD),
            // Recent docs
            _RecentDocsCard(documents: docs.documents.take(4).toList()),
            const SizedBox(height: AppConstants.spacingMD),
            // Recent Drive
            _RecentDriveCard(
              files: _recentFiles,
              isLoading: _loadingFiles,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String userName;
  final VoidCallback onRunSynthesis;
  final bool isLoading;
  final String? briefing;

  const _WelcomeCard({
    required this.userName,
    required this.onRunSynthesis,
    required this.isLoading,
    required this.briefing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMD),
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
              const Icon(Icons.memory_outlined,
                  size: 16, color: AppColors.foreground),
              const SizedBox(width: 8),
              const Text(
                'DAILY SYNTHESIS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedLight,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Good to see you, $userName.',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 6),
          if (isLoading)
            Row(
              children: const [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.muted,
                  ),
                ),
                SizedBox(width: 10),
                Text('Analyzing recent context...',
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
              ],
            )
          else if (briefing != null)
            Text(
              briefing!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.foregroundMuted,
                height: 1.5,
              ),
            )
          else
            const Text(
              'Run a synthesis to analyze your recent emails and files.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: isLoading ? null : onRunSynthesis,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceHover,
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                briefing != null ? 'Refresh Synthesis' : 'Run Synthesis',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool isConnected;
  const _StatusCard({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final status = isConnected ? 'Connected' : 'Offline';
    final statusColor =
        isConnected ? AppColors.success : AppColors.mutedLight;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMD),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.cable_outlined, size: 15, color: AppColors.foreground),
              SizedBox(width: 8),
              Text(
                'SYSTEM CORE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedLight,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _statusRow('Google Mail', status, statusColor),
          const Divider(height: 16),
          _statusRow('Google Drive', status, statusColor),
          const Divider(height: 16),
          _statusRow('Workspace Auth', 'Verified', AppColors.success),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        Text(value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor,
            )),
      ],
    );
  }
}

class _RecentDocsCard extends StatelessWidget {
  final List documents;
  const _RecentDocsCard({required this.documents});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMD),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.description_outlined,
                  size: 15, color: AppColors.foreground),
              SizedBox(width: 8),
              Text(
                'RECENT DOCUMENTS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedLight,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (documents.isEmpty)
            const Text('No documents yet.',
                style: TextStyle(fontSize: 13, color: AppColors.muted))
          else
            ...documents.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.article_outlined,
                          size: 14, color: AppColors.mutedLight),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          d.title ?? 'Untitled',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.foregroundMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _RecentDriveCard extends StatelessWidget {
  final List<Map<String, dynamic>> files;
  final bool isLoading;

  const _RecentDriveCard({required this.files, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMD),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.drive_eta_outlined,
                  size: 15, color: AppColors.foreground),
              SizedBox(width: 8),
              Text(
                'RECENT DRIVE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedLight,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppColors.muted),
                ),
              ),
            )
          else if (files.isEmpty)
            const Text('No recent files.',
                style: TextStyle(fontSize: 13, color: AppColors.muted))
          else
            ...files.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(
                        _mimeIcon(f['mimeType'] as String? ?? ''),
                        size: 14,
                        color: AppColors.mutedLight,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          f['name'] as String? ?? 'Untitled',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.foregroundMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.north_east,
                          size: 12, color: AppColors.mutedLight),
                    ],
                  ),
                )),
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