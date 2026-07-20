import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/common.dart';
import '../main_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();

    if (!provider.initialized || provider.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.user == null) {
      return const LoginScreen();
    }

    return const MainShell();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool signupMode = false;
  bool obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<WalletProvider>();
    try {
      if (signupMode) {
        await provider.signup(
          email: _email.text.trim(),
          password: _password.text,
          name: _name.text.trim(),
        );
        if (mounted) showAppSnackBar(context, 'Account created');
      } else {
        await provider.login(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (mounted) showAppSnackBar(context, 'Logged in');
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                const Center(child: NexLogo(size: 56)),
                const SizedBox(height: 24),
                Text(
                  signupMode ? 'Create your wallet' : 'Welcome back',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect to your backend API for signup, balances, and transfers.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                ),
                const SizedBox(height: 28),
                if (signupMode)
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                if (signupMode) const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) =>
                      value == null || !value.contains('@') ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                  validator: (value) =>
                      value == null || value.length < 6 ? 'Minimum 6 characters' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: provider.loading ? null : _submit,
                    child: provider.loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(signupMode ? 'Create Account' : 'Open Wallet'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => signupMode = !signupMode),
                  child: Text(
                    signupMode
                        ? 'Already have an account? Log in'
                        : 'New here? Create account',
                  ),
                ),
                const SizedBox(height: 24),
                const SectionLabel('API settings'),
                const SizedBox(height: 8),
                const ApiSettingsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ApiSettingsCard extends StatefulWidget {
  const ApiSettingsCard({super.key});

  @override
  State<ApiSettingsCard> createState() => _ApiSettingsCardState();
}

class _ApiSettingsCardState extends State<ApiSettingsCard> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _urlController.text = ApiConfig.baseUrl;
    _keyController.text = ApiConfig.apiKey ?? '';
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<WalletProvider>();
    await provider.setApiBaseUrl(_urlController.text.trim());
    await provider.setApiKey(
      _keyController.text.trim().isEmpty ? null : _keyController.text.trim(),
    );
    if (mounted) showAppSnackBar(context, 'API settings saved');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
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
              child: OutlinedButton(onPressed: _save, child: const Text('Save API settings')),
            ),
          ],
        ),
      ),
    );
  }
}
