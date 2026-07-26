import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/api_models.dart';
import '../../providers/wallet_provider.dart';
import '../nex_tokens.dart';
import '../widgets/nex_brand.dart';
import '../widgets/nex_components.dart';

class NexAccountRestrictionBanner extends StatelessWidget {
  const NexAccountRestrictionBanner({
    super.key,
    required this.status,
    required this.onSupport,
  });

  final AccountStatusInfo status;
  final VoidCallback onSupport;

  /// Short line shown inside the banner. Deliberately ignores the raw admin
  /// reason from the backend, which is internal wording.
  static const summaryText =
      'Your account has been restricted. Contact support for further help.';

  /// Longer explanation shown in the info sheet and the blocked-action notice.
  static String detailText(AccountStatusInfo? status) {
    if (status == null) return summaryText;
    if (status.isFrozen) {
      return 'Your account is frozen, so wallet actions are unavailable right now. Contact support for further help.';
    }
    if (status.blocks('withdrawal') && !status.blocks('swap')) {
      return 'Your account is restricted from withdrawing funds. You can still swap and use the other app services. Contact support for further help.';
    }
    return summaryText;
  }

  void showInfo(BuildContext context) {
    final t = NexThemeScope.of(context);
    final accent = status.isFrozen
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.muted.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    NexIcon('info', size: 18, color: accent),
                    const SizedBox(width: 8),
                    Text(
                      'Account notice',
                      style: TextStyle(
                        color: t.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  detailText(status),
                  style: TextStyle(color: t.text2, fontSize: 14, height: 1.45),
                ),
                if (status.supportRequired) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        onSupport();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Contact support'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final frozen = status.isFrozen;
    final accent = frozen ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: t.dark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  frozen ? 'Account frozen' : 'Account restricted',
                  style: TextStyle(
                    color: t.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summaryText,
                  style: TextStyle(color: t.text2, fontSize: 12, height: 1.4),
                ),
                if (status.supportRequired) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onSupport,
                    child: Text(
                      'Contact support',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: accent.withValues(alpha: 0.18),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => showInfo(context),
              child: SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: NexIcon('info', size: 16, color: accent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NexAnnouncementBanner extends StatelessWidget {
  const NexAnnouncementBanner({
    super.key,
    required this.announcement,
    this.onTap,
    this.dismissible = false,
  });

  final AppAnnouncement announcement;
  final VoidCallback? onTap;

  /// Announcements stay until the admin removes them on the backend.
  /// Local dismiss is never allowed.
  final bool dismissible;

  @override
  Widget build(BuildContext context) {
    assert(!dismissible, 'Announcements cannot be dismissed locally');
    final t = NexThemeScope.of(context);
    final accent = announcement.isHighPriority
        ? const Color(0xFFF59E0B)
        : t.navActive;

    final content = Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: t.dark ? 0.1 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NexIcon('bell', size: 19, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  announcement.title,
                  style: TextStyle(
                    color: t.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (announcement.body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    announcement.body,
                    style: TextStyle(
                      color: t.text2,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            NexIcon('chevR', size: 16, color: t.muted),
          ],
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: content,
      ),
    );
  }
}

/// Full-screen, non-dismissible announcement gate.
/// Stays up until [WalletProvider.announcements] becomes empty (admin deleted).
class NexPinnedAnnouncementOverlay extends StatefulWidget {
  const NexPinnedAnnouncementOverlay({
    super.key,
    required this.announcement,
  });

  final AppAnnouncement announcement;

  @override
  State<NexPinnedAnnouncementOverlay> createState() =>
      _NexPinnedAnnouncementOverlayState();
}

class _NexPinnedAnnouncementOverlayState
    extends State<NexPinnedAnnouncementOverlay> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      unawaited(
        context.read<WalletProvider>().refreshAccountFeatures(force: true),
      );
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final announcement = widget.announcement;
    final accent = announcement.isHighPriority
        ? const Color(0xFFF59E0B)
        : t.navActive;

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                decoration: BoxDecoration(
                  color: t.cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: NexIcon('bell', size: 18, color: accent),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Announcement',
                            style: TextStyle(
                              color: t.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      announcement.title,
                      style: TextStyle(
                        color: t.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    if (announcement.body.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        announcement.body,
                        style: TextStyle(
                          color: t.text2,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      'This notice stays on screen until an administrator removes it. It cannot be closed from the app.',
                      style: TextStyle(
                        color: t.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
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
}

class NexSupportTicketScreen extends StatefulWidget {
  const NexSupportTicketScreen({
    super.key,
    required this.onBack,
    this.blockedAction,
  });

  final VoidCallback onBack;
  final String? blockedAction;

  @override
  State<NexSupportTicketScreen> createState() => _NexSupportTicketScreenState();
}

class _NexSupportTicketScreenState extends State<NexSupportTicketScreen> {
  late final TextEditingController _subject;
  late final TextEditingController _message;
  bool _submitting = false;
  SupportTicket? _ticket;

  @override
  void initState() {
    super.initState();
    final restricted = widget.blockedAction != null;
    _subject = TextEditingController(
      text: restricted ? 'Account restricted' : '',
    );
    _message = TextEditingController(
      text: restricted
          ? 'Please review my wallet account and restore access to ${widget.blockedAction}.'
          : '',
    );
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subject.text.trim();
    final message = _message.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      showNexError(context, 'Enter a subject and message');
      return;
    }

    setState(() => _submitting = true);
    try {
      final ticket = await context.read<WalletProvider>().createSupportTicket(
        category: widget.blockedAction != null
            ? 'account_restricted'
            : 'general_support',
        subject: subject,
        message: message,
        blockedAction: widget.blockedAction,
      );
      if (!mounted) return;
      setState(() => _ticket = ticket);
    } catch (e) {
      if (!mounted) return;
      showNexError(context, e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);

    return ColoredBox(
      color: t.appBg,
      child: Column(
        children: [
          NexScreenHeader(title: 'Help & Support', onBack: widget.onBack),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                if (_ticket != null)
                  _TicketCreatedCard(ticket: _ticket!)
                else ...[
                  Text(
                    widget.blockedAction != null
                        ? 'Request an account review'
                        : 'How can we help?',
                    style: TextStyle(
                      color: t.text,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.blockedAction != null
                        ? 'Your ${widget.blockedAction} access is restricted. Send a ticket to the support team.'
                        : 'Describe the issue and our support team will review it.',
                    style: TextStyle(color: t.text2, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  _SupportField(
                    label: 'Subject',
                    controller: _subject,
                    hint: 'Briefly describe the issue',
                  ),
                  const SizedBox(height: 14),
                  _SupportField(
                    label: 'Message',
                    controller: _message,
                    hint: 'Add details that will help us investigate',
                    maxLines: 6,
                  ),
                  const SizedBox(height: 20),
                  NexPrimaryButton(
                    label: _submitting ? 'Submitting…' : 'Submit ticket',
                    loading: _submitting,
                    onPressed: _submitting ? null : () => unawaited(_submit()),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportField extends StatelessWidget {
  const _SupportField({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: t.text,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: t.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: t.muted),
            filled: true,
            fillColor: t.inputFill,
            contentPadding: const EdgeInsets.all(14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: t.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: t.navActive),
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketCreatedCard extends StatelessWidget {
  const _TicketCreatedCard({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    return NexCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: NexIcon('check', size: 24, color: Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Ticket submitted',
            style: TextStyle(
              color: t.text,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reference ${ticket.publicId}\nStatus: ${ticket.status}',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.text2, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class NexAnnouncementsScreen extends StatelessWidget {
  const NexAnnouncementsScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final provider = context.watch<WalletProvider>();

    return ColoredBox(
      color: t.appBg,
      child: Column(
        children: [
          NexScreenHeader(title: 'Announcements', onBack: onBack),
          Expanded(
            child: RefreshIndicator(
              onRefresh: provider.refreshAccountFeatures,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  if (provider.announcements.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Column(
                        children: [
                          NexIcon('bell', size: 34, color: t.muted),
                          const SizedBox(height: 12),
                          Text(
                            'No announcements',
                            style: TextStyle(
                              color: t.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Important wallet updates will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: t.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    ...provider.announcements.map(
                      (announcement) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AnnouncementCard(announcement: announcement),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement});

  final AppAnnouncement announcement;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final accent = announcement.isHighPriority
        ? const Color(0xFFF59E0B)
        : t.navActive;

    return NexCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(child: NexIcon('bell', size: 18, color: accent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  announcement.title,
                  style: TextStyle(
                    color: t.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (announcement.body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    announcement.body,
                    style: TextStyle(
                      color: t.text2,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  announcement.priority.toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
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
