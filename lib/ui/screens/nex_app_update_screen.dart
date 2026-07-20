import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/app_update_service.dart';
import '../nex_tokens.dart';
import '../widgets/nex_brand.dart';
import '../widgets/nex_components.dart';

void openNexAppUpdateScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NexThemeScope(
        tokens: NexThemeScope.of(context),
        child: const NexAppUpdateScreen(),
      ),
    ),
  );
}

class NexAppUpdateScreen extends StatefulWidget {
  const NexAppUpdateScreen({super.key});

  @override
  State<NexAppUpdateScreen> createState() => _NexAppUpdateScreenState();
}

class _NexAppUpdateScreenState extends State<NexAppUpdateScreen> {
  AppUpdateStatus? _status;
  bool _checking = true;
  bool _downloading = false;
  double _progress = 0;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _actionError = null;
    });
    final status = await AppUpdateService.instance.checkForUpdate();
    if (!mounted) return;
    setState(() {
      _status = status;
      _checking = false;
    });
  }

  Future<void> _downloadAndInstall() async {
    final info = _status?.remote;
    if (info == null || info.apkUrl.isEmpty) return;

    setState(() {
      _downloading = true;
      _progress = 0;
      _actionError = null;
    });

    try {
      final path = await AppUpdateService.instance.downloadApk(
        info.apkUrl,
        onProgress: (value) {
          if (!mounted) return;
          setState(() => _progress = value);
        },
      );
      await AppUpdateService.instance.installApk(path);
      if (!mounted) return;
      showNexToast(context, 'Follow the prompts to install the update');
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = e.toString());
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _openBrowserDownload() async {
    final url = _status?.remote?.apkUrl;
    if (url == null || url.isEmpty) return;
    try {
      await AppUpdateService.instance.openDownloadInBrowser(url);
    } catch (e) {
      if (!mounted) return;
      showNexToast(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final status = _status;

    return Scaffold(
      backgroundColor: t.appBg,
      body: SafeArea(
        child: Column(
          children: [
            NexScreenHeader(title: 'Update App', onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F4FE0), Color(0xFF2DA8FF)],
                        ),
                      ),
                      child: const Center(child: NexIcon('download', size: 32, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'NEX Wallet',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: t.text),
                  ),
                  const SizedBox(height: 6),
                  if (status != null)
                    Text(
                      'Installed: ${status.localLabel}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: t.muted),
                    ),
                  const SizedBox(height: 24),
                  if (_checking)
                    Center(child: Padding(padding: const EdgeInsets.all(24), child: CircularProgressIndicator(color: t.navActive)))
                  else if (status?.error != null)
                    _messageCard(
                      t,
                      title: 'Could not check for updates',
                      body: status!.error!,
                      tone: _MessageTone.error,
                    )
                  else if (status != null && status.hasUpdate)
                    ...[
                      _messageCard(
                        t,
                        title: 'Update available',
                        body: 'Latest version ${status.remoteLabel} is ready to install.',
                        tone: _MessageTone.success,
                      ),
                      const SizedBox(height: 16),
                      if (status.remote!.releaseNotes.isNotEmpty) ...[
                        Text('What\'s new', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.text)),
                        const SizedBox(height: 8),
                        NexCard(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            status.remote!.releaseNotes,
                            style: TextStyle(fontSize: 14, color: t.text2, height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_downloading) ...[
                        LinearProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(999),
                          color: t.navActive,
                          backgroundColor: t.cardSoft,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _progress > 0 ? '${(_progress * 100).round()}% downloaded' : 'Downloading…',
                          style: TextStyle(fontSize: 13, color: t.muted),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_actionError != null) ...[
                        _messageCard(t, title: 'Install failed', body: _actionError!, tone: _MessageTone.error),
                        const SizedBox(height: 12),
                      ],
                      if (Platform.isAndroid) ...[
                        NexPrimaryButton(
                          label: _downloading ? 'Downloading…' : 'Download & install',
                          onPressed: _downloading ? null : () => unawaited(_downloadAndInstall()),
                        ),
                        const SizedBox(height: 10),
                      ],
                      NexSecondaryButton(
                        label: 'Open download in browser',
                        onPressed: _downloading ? () {} : () => unawaited(_openBrowserDownload()),
                      ),
                    ]
                  else if (status != null)
                    _messageCard(
                      t,
                      title: 'You\'re up to date',
                      body: 'You have the latest version (${status.localLabel}).',
                      tone: _MessageTone.neutral,
                    ),
                  const SizedBox(height: 20),
                  NexSecondaryButton(
                    label: 'Check again',
                    onPressed: _checking || _downloading ? () {} : () => unawaited(_check()),
                  ),
                  if (!Platform.isAndroid) ...[
                    const SizedBox(height: 16),
                    Text(
                      'On iOS, app updates are distributed through the App Store when available.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: t.muted, height: 1.45),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageCard(
    NexTokens t, {
    required String title,
    required String body,
    required _MessageTone tone,
  }) {
    final Color accent;
    switch (tone) {
      case _MessageTone.success:
        accent = const Color(0xFF22C55E);
      case _MessageTone.error:
        accent = const Color(0xFFF87171);
      case _MessageTone.neutral:
        accent = t.navActive;
    }

    return NexCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NexIcon(
            tone == _MessageTone.error ? 'alert' : 'check',
            size: 20,
            color: accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.text)),
                const SizedBox(height: 6),
                Text(body, style: TextStyle(fontSize: 14, color: t.text2, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _MessageTone { success, error, neutral }
