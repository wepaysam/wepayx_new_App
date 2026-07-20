import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_update_service.dart';
import '../widgets/nex_brand.dart';
import '../widgets/nex_components.dart';
import 'nex_settings_screens.dart';

/// Full-screen blocking update prompt — user cannot use the app until they update.
class NexForceUpdateScreen extends StatefulWidget {
  const NexForceUpdateScreen({
    super.key,
    required this.status,
    this.onRecheck,
  });

  final AppUpdateStatus status;
  final Future<AppUpdateStatus> Function()? onRecheck;

  @override
  State<NexForceUpdateScreen> createState() => _NexForceUpdateScreenState();
}

class _NexForceUpdateScreenState extends State<NexForceUpdateScreen> {
  bool _downloading = false;
  double _progress = 0;
  String? _actionError;
  bool _rechecking = false;

  Future<void> _downloadAndInstall() async {
    final info = widget.status.remote;
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = e.toString());
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _openBrowserDownload() async {
    final url = widget.status.remote?.apkUrl;
    if (url == null || url.isEmpty) return;
    try {
      await AppUpdateService.instance.openDownloadInBrowser(url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = e.toString());
    }
  }

  Future<void> _recheck() async {
    final recheck = widget.onRecheck;
    if (recheck == null) return;
    setState(() => _rechecking = true);
    try {
      await recheck();
    } finally {
      if (mounted) setState(() => _rechecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remote = widget.status.remote!;
    final notes = remote.releaseNotes.trim();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF060D1A),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    _header(remote.latestVersion),
                    const SizedBox(height: 20),
                    _bodyCard(notes),
                    const SizedBox(height: 28),
                    if (_downloading) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          minHeight: 6,
                          color: const Color(0xFF2DA8FF),
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _progress > 0 ? '${(_progress * 100).round()}% downloaded' : 'Downloading update…',
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.55)),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_actionError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF87171).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF87171).withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          _actionError!,
                          style: const TextStyle(fontSize: 13, color: Color(0xFFFCA5A5), height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _downloading ? null : () => unawaited(_downloadAndInstall()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2DA8FF),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF2DA8FF).withValues(alpha: 0.45),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        child: Text(_downloading ? 'Downloading…' : 'Update Now'),
                      ),
                    ),
                    if (!Platform.isAndroid) ...[
                      const SizedBox(height: 10),
                      NexSecondaryButton(
                        label: 'Open download link',
                        onPressed: _downloading ? () {} : () => unawaited(_openBrowserDownload()),
                      ),
                    ],
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: _rechecking ? null : () => unawaited(_recheck()),
                      child: Text(
                        _rechecking ? 'Checking…' : 'I already updated — check again',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => showNexComingSoon(context, 'Customer support'),
                      child: Text(
                        'Contact Customer Service',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Installed: ${widget.status.localLabel}',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.35)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(String version) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B2A6B), Color(0xFF123D8F), Color(0xFF1A4FA8)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -4,
            top: -8,
            child: Opacity(
              opacity: 0.22,
              child: Icon(
                Icons.rocket_launch_rounded,
                size: 110,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NexLogo(size: 28),
              const SizedBox(height: 18),
              Text(
                'New Version Available',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'v$version',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please update to continue using NEX Wallet.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.65),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bodyCard(String notes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s new',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            notes.isNotEmpty
                ? notes
                : 'This update includes important improvements and security fixes. '
                    'Updating is required to keep using the app.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.68),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}
