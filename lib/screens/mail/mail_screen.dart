import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';

class MailScreen extends StatefulWidget {
  const MailScreen({super.key});

  @override
  State<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends State<MailScreen> {
  List<Map<String, dynamic>> _emails = [];
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _selected;
  String? _emailBody;
  bool _loadingBody = false;
  String? _aiSummary;
  bool _aiLoading = false;
  bool _composing = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEmails());
  }

  Future<void> _loadEmails([String query = '']) async {
    final auth = context.read<AuthProvider>();
    if (auth.googleApiClient == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final emails = await auth.googleApiClient!.fetchRecentEmails(
        query: query,
        maxResults: 50,
      );
      setState(() => _emails = emails);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadBody(String id) async {
    final auth = context.read<AuthProvider>();
    if (auth.googleApiClient == null) return;
    setState(() {
      _loadingBody = true;
      _emailBody = null;
    });
    try {
      final body = await auth.googleApiClient!.fetchEmailBody(id);
      setState(() => _emailBody = body);
    } catch (_) {
    } finally {
      setState(() => _loadingBody = false);
    }
  }

  Future<void> _summarize() async {
    if (_selected == null) return;
    setState(() {
      _aiLoading = true;
      _aiSummary = null;
    });
    try {
      final result = await ApiClient.post('/api/summarise/thread', {
        'threadMessages': [_selected],
      });
      setState(() => _aiSummary = result['summary'] as String?);
    } catch (e) {
      setState(() => _aiSummary = 'Error: $e');
    } finally {
      setState(() => _aiLoading = false);
    }
  }

  void _selectEmail(Map<String, dynamic> email) {
    setState(() {
      _selected = email;
      _aiSummary = null;
      _composing = false;
    });
    _loadBody(email['id'] as String);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.googleApiClient == null) {
      return _ConnectPrompt(onConnect: auth.signIn);
    }

    if (_selected != null || _composing) {
      return _DetailView(
        email: _selected,
        body: _emailBody,
        loadingBody: _loadingBody,
        aiSummary: _aiSummary,
        aiLoading: _aiLoading,
        composing: _composing,
        onBack: () => setState(() {
          _selected = null;
          _composing = false;
        }),
        onSummarize: _summarize,
        onReply: () {
          setState(() {
            _composing = true;
            _selected = null;
          });
        },
        googleApiClient: auth.googleApiClient!,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('Mail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => setState(() => _composing = true),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _loadEmails(_searchCtrl.text),
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
                  onSubmitted: _loadEmails,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.foreground),
                  decoration: InputDecoration(
                    hintText: 'Search mail...',
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: AppColors.muted),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                      borderSide:
                          const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                      borderSide:
                          const BorderSide(color: AppColors.border),
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
      body: _error != null
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
                      strokeWidth: 1.5, color: AppColors.muted))
              : _emails.isEmpty
                  ? const Center(
                      child: Text('No emails found.',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.muted)))
                  : ListView.separated(
                      itemCount: _emails.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final email = _emails[i];
                        return _EmailTile(
                          email: email,
                          onTap: () => _selectEmail(email),
                        );
                      },
                    ),
    );
  }
}

class _EmailTile extends StatelessWidget {
  final Map<String, dynamic> email;
  final VoidCallback onTap;

  const _EmailTile({required this.email, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              email['from'] as String? ?? 'Unknown',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              email['subject'] as String? ?? '(no subject)',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.foregroundMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              email['snippet'] as String? ?? '',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailView extends StatefulWidget {
  final Map<String, dynamic>? email;
  final String? body;
  final bool loadingBody;
  final String? aiSummary;
  final bool aiLoading;
  final bool composing;
  final VoidCallback onBack;
  final VoidCallback onSummarize;
  final VoidCallback onReply;
  final dynamic googleApiClient;

  const _DetailView({
    required this.email,
    required this.body,
    required this.loadingBody,
    required this.aiSummary,
    required this.aiLoading,
    required this.composing,
    required this.onBack,
    required this.onSummarize,
    required this.onReply,
    required this.googleApiClient,
  });

  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> {
  final TextEditingController _toCtrl = TextEditingController();
  final TextEditingController _subjectCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();
  final TextEditingController _draftPromptCtrl = TextEditingController();
  bool _sending = false;
  bool _draftLoading = false;

  Future<void> _draftWithAI() async {
    if (_draftPromptCtrl.text.trim().isEmpty) return;
    setState(() => _draftLoading = true);
    try {
      final result = await ApiClient.post('/api/draft/email', {
        'prompt': _draftPromptCtrl.text,
        'context': _bodyCtrl.text,
      });
      _bodyCtrl.text = result['draft'] as String? ?? '';
      _draftPromptCtrl.clear();
    } catch (_) {
    } finally {
      setState(() => _draftLoading = false);
    }
  }

  Future<void> _send() async {
    if (_toCtrl.text.isEmpty || _subjectCtrl.text.isEmpty || _bodyCtrl.text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.googleApiClient.sendEmail(
        to: _toCtrl.text,
        subject: _subjectCtrl.text,
        body: _bodyCtrl.text,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Email sent.'),
        backgroundColor: Color(0xFF111111),
      ));
      widget.onBack();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed: $e'),
        backgroundColor: AppColors.error,
      ));
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.composing) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onBack,
          ),
          title: const Text('Compose'),
          actions: [
            TextButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: AppColors.foreground))
                  : const Text('Send',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground)),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppConstants.spacingMD),
          children: [
            _ComposeField(label: 'To', controller: _toCtrl),
            const Divider(height: 16),
            _ComposeField(label: 'Subject', controller: _subjectCtrl),
            const Divider(height: 16),
            // AI draft bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _draftPromptCtrl,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.foreground),
                    decoration: InputDecoration(
                      hintText: 'Draft with AI (e.g. "Schedule a meeting")...',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: AppColors.mutedLight),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppConstants.radiusMD),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppConstants.radiusMD),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppConstants.radiusMD),
                          borderSide: const BorderSide(
                              color: AppColors.foreground)),
                      filled: true,
                      fillColor: AppColors.bgSurfaceHover,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _draftLoading ? null : _draftWithAI,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.foreground,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                    ),
                    child: _draftLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: Colors.white))
                        : const Text('Draft',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.foregroundMuted,
                  height: 1.6),
              decoration: const InputDecoration(
                hintText: 'Write your message...',
                hintStyle:
                    TextStyle(fontSize: 14, color: AppColors.mutedLight),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      );
    }

    final email = widget.email!;
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          onPressed: widget.onBack,
        ),
        title: Text(
          email['subject'] as String? ?? '(no subject)',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: widget.aiLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: AppColors.muted))
                : const Icon(Icons.auto_awesome_outlined, size: 20),
            onPressed: widget.aiLoading ? null : widget.onSummarize,
            tooltip: 'Summarize',
          ),
          IconButton(
            icon: const Icon(Icons.reply_outlined, size: 20),
            onPressed: widget.onReply,
            tooltip: 'Reply',
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.spacingMD),
        children: [
          Text(
            email['from'] as String? ?? 'Unknown',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground),
          ),
          const SizedBox(height: 2),
          Text(
            email['date'] as String? ?? '',
            style: const TextStyle(fontSize: 11, color: AppColors.mutedLight),
          ),
          const SizedBox(height: 16),
          if (widget.aiSummary != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceHover,
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusMD),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI SUMMARY',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mutedLight,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Text(widget.aiSummary!,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.foregroundMuted,
                          height: 1.5)),
                ],
              ),
            ),
          if (widget.loadingBody)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppColors.muted),
              ),
            )
          else
            Text(
              widget.body?.isNotEmpty == true
                  ? widget.body!
                  : email['snippet'] as String? ?? '',
              style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.foregroundMuted,
                  height: 1.6),
            ),
        ],
      ),
    );
  }
}

class _ComposeField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _ComposeField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted)),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(
                fontSize: 14, color: AppColors.foreground),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              fillColor: Colors.transparent,
              filled: true,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConnectPrompt extends StatelessWidget {
  final VoidCallback onConnect;
  const _ConnectPrompt({required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('Mail'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mail_outline_rounded,
                  size: 40, color: AppColors.mutedLight),
              const SizedBox(height: 16),
              const Text('Connect Gmail',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground)),
              const SizedBox(height: 8),
              const Text(
                'Sign in with Google to access your mail.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: onConnect,
                  child: const Text('Connect Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}