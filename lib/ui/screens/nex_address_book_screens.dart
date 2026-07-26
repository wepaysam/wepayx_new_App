import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/formatters.dart';
import '../../models/saved_address.dart';
import '../../services/address_book_service.dart';
import '../nex_tokens.dart';
import '../widgets/nex_brand.dart';
import '../widgets/nex_components.dart';

Future<void> showSaveAddressSheet(
  BuildContext context, {
  required String address,
  required String network,
  String assetHint = '',
  SavedAddress? existing,
  bool allowNetworkPick = false,
}) async {
  final t = NexThemeScope.of(context);
  final book = AddressBookService.instance;
  if (!book.isLoaded) await book.load();
  if (!context.mounted) return;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.cardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) {
      return NexThemeScope(
        tokens: t,
        child: _SaveAddressSheetBody(
          address: address,
          network: network,
          assetHint: assetHint,
          existing: existing,
          allowNetworkPick: allowNetworkPick,
        ),
      );
    },
  );

  if (saved == true && context.mounted) {
    showNexToast(
      context,
      existing == null ? 'Address saved on this device' : 'Address updated',
    );
  }
}

class _SaveAddressSheetBody extends StatefulWidget {
  const _SaveAddressSheetBody({
    required this.address,
    required this.network,
    required this.assetHint,
    required this.existing,
    required this.allowNetworkPick,
  });

  final String address;
  final String network;
  final String assetHint;
  final SavedAddress? existing;
  final bool allowNetworkPick;

  @override
  State<_SaveAddressSheetBody> createState() => _SaveAddressSheetBodyState();
}

class _SaveAddressSheetBodyState extends State<_SaveAddressSheetBody> {
  static const _networks = ['TRC20', 'ERC20', 'BEP20', 'Bitcoin'];

  late final TextEditingController _titleCtrl;
  late final TextEditingController _addressCtrl;
  late String _selectedNetwork;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleCtrl = TextEditingController(text: existing?.title ?? '');
    _addressCtrl = TextEditingController(
      text: existing?.address ?? widget.address,
    );
    _selectedNetwork = existing?.network ?? widget.network;
    if (!_networks.contains(_selectedNetwork)) {
      _selectedNetwork = _networks.first;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AddressBookService.instance.save(
        id: widget.existing?.id,
        title: _titleCtrl.text,
        address: _addressCtrl.text,
        network: _selectedNetwork,
        assetHint: widget.assetHint,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final existing = widget.existing;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
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
          Text(
            existing == null ? 'Save address' : 'Edit address',
            style: TextStyle(
              color: t.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Saved on this device only. Not uploaded to the server.',
            style: TextStyle(color: t.text2, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          Text('Title', style: TextStyle(color: t.muted, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: t.text),
            decoration: InputDecoration(
              hintText: 'e.g. My Binance, Exchange wallet',
              filled: true,
              fillColor: t.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: t.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: t.inputBorder),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Network', style: TextStyle(color: t.muted, fontSize: 12)),
          const SizedBox(height: 6),
          if (widget.allowNetworkPick || existing != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _networks.map((n) {
                final selected = _selectedNetwork == n;
                return ChoiceChip(
                  label: Text(n),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedNetwork = n),
                  selectedColor: t.navActive.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: selected ? t.navActive : t.text2,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  backgroundColor: t.cardSoft,
                  side: BorderSide(
                    color: selected ? t.navActive : t.cardBorder,
                  ),
                );
              }).toList(),
            )
          else
            Text(
              _selectedNetwork,
              style: TextStyle(color: t.text, fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 12),
          Text('Address', style: TextStyle(color: t.muted, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _addressCtrl,
            maxLines: 2,
            style: TextStyle(
              color: t.text,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: t.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: t.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: t.inputBorder),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFF87171), fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          NexPrimaryButton(
            label: _saving
                ? 'Saving...'
                : (existing == null ? 'Save address' : 'Update'),
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

Future<SavedAddress?> showAddressBookPicker(
  BuildContext context, {
  String? networkFilter,
}) async {
  final t = NexThemeScope.of(context);
  final book = AddressBookService.instance;
  if (!book.isLoaded) await book.load();
  if (!context.mounted) return null;

  return showModalBottomSheet<SavedAddress>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.cardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) {
      final items = networkFilter == null || networkFilter.isEmpty
          ? book.entries
          : book.forNetwork(networkFilter);

      return NexThemeScope(
        tokens: t,
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.62,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.muted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          networkFilter == null || networkFilter.isEmpty
                              ? 'Address book'
                              : 'Saved · $networkFilter',
                          style: TextStyle(
                            color: t.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${items.length}',
                        style: TextStyle(color: t.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              networkFilter == null
                                  ? 'No saved addresses yet.'
                                  : 'No saved addresses for $networkFilter yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: t.text2, height: 1.4),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return Material(
                              color: t.cardSoft,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () =>
                                    Navigator.of(sheetContext).pop(item),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: t.cardBg,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: NexIcon(
                                            'user',
                                            size: 18,
                                            color: t.navActive,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              style: TextStyle(
                                                color: t.text,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${item.network} · ${Formatters.shortenAddress(item.address)}',
                                              style: TextStyle(
                                                color: t.text2,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      NexIcon('chevR', size: 16, color: t.muted),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class NexAddressBookScreen extends StatefulWidget {
  const NexAddressBookScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<NexAddressBookScreen> createState() => _NexAddressBookScreenState();
}

class _NexAddressBookScreenState extends State<NexAddressBookScreen> {
  final _book = AddressBookService.instance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _book.addListener(_onBookChanged);
    _boot();
  }

  @override
  void dispose() {
    _book.removeListener(_onBookChanged);
    super.dispose();
  }

  void _onBookChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _boot() async {
    await _book.load();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    await showSaveAddressSheet(
      context,
      address: '',
      network: 'TRC20',
      allowNetworkPick: true,
    );
  }

  Future<void> _edit(SavedAddress item) async {
    await showSaveAddressSheet(
      context,
      address: item.address,
      network: item.network,
      assetHint: item.assetHint,
      existing: item,
    );
  }

  Future<void> _delete(SavedAddress item) async {
    final t = NexThemeScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: t.cardBg,
          title: Text('Delete address?', style: TextStyle(color: t.text)),
          content: Text(
            '"${item.title}" will be removed from this device.',
            style: TextStyle(color: t.text2, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Color(0xFFF87171)),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _book.delete(item.id);
      if (mounted) showNexToast(context, 'Address deleted');
    }
  }

  Future<void> _copy(SavedAddress item) async {
    await Clipboard.setData(ClipboardData(text: item.address));
    if (mounted) showNexToast(context, 'Address copied');
  }

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final items = _book.entries;

    return ColoredBox(
      color: t.appBg,
      child: Column(
        children: [
          NexScreenHeader(
            title: 'Address Book',
            onBack: widget.onBack,
            right: IconButton(
              tooltip: 'Add address',
              onPressed: _add,
              icon: NexIcon('plus', size: 20, color: t.navActive),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              'Addresses are stored only on this phone. They are never sent to the server.',
              style: TextStyle(color: t.text2, fontSize: 12, height: 1.4),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                : items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          NexIcon('user', size: 36, color: t.muted),
                          const SizedBox(height: 14),
                          Text(
                            'No saved addresses',
                            style: TextStyle(
                              color: t.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Save a recipient title + address from Send, or add one here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: t.text2,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          NexPrimaryButton(
                            label: 'Add address',
                            onPressed: _add,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return NexCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      color: t.text,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: t.cardSoft,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    item.network,
                                    style: TextStyle(
                                      color: t.text2,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.address,
                              style: TextStyle(
                                color: t.text2,
                                fontSize: 12,
                                fontFamily: 'monospace',
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => _copy(item),
                                  child: Text(
                                    'Copy',
                                    style: TextStyle(color: t.navActive),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _edit(item),
                                  child: Text(
                                    'Edit',
                                    style: TextStyle(color: t.navActive),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _delete(item),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Color(0xFFF87171)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
