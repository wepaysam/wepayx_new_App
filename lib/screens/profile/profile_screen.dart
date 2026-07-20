import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _keyController;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiConfig.baseUrl);
    _keyController = TextEditingController(text: ApiConfig.apiKey ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _saveApiSettings() async {
    final provider = context.read<WalletProvider>();
    await provider.setApiBaseUrl(_urlController.text.trim());
    await provider.setApiKey(
      _keyController.text.trim().isEmpty ? null : _keyController.text.trim(),
    );
    if (mounted) showAppSnackBar(context, 'API settings saved');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Profile',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(provider.user?.name ?? 'Wallet user'),
              subtitle: Text(provider.user?.email ?? ''),
            ),
          ),
          const SizedBox(height: 16),
          const SectionLabel('API connection'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'API base URL',
                      hintText: 'https://your-api.example.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyController,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      labelText: 'Futre API key (required)',
                      hintText: 'futre_live_...',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                        icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _saveApiSettings,
                      child: const Text('Save API settings'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Dark theme'),
            value: provider.isDark,
            onChanged: (_) => provider.toggleTheme(),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () async {
              await provider.logout();
              if (context.mounted) showAppSnackBar(context, 'Logged out');
            },
          ),
        ],
      ),
    );
  }
}
