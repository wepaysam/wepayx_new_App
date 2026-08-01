import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/wallet_provider.dart';
import '../nex_tokens.dart';
import '../widgets/nex_brand.dart';
import '../widgets/nex_components.dart';

class NexLandingScreen extends StatelessWidget {
  const NexLandingScreen({
    super.key,
    required this.onSignup,
    required this.onLogin,
  });

  final VoidCallback onSignup;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/hero.jpg', fit: BoxFit.cover),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              stops: const [0.14, 0.48, 1],
              colors: [
                Colors.black,
                Colors.black.withValues(alpha: 0.82),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 40,
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F4FE0), Color(0xFF2DA8FF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2D8CFF).withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: onSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Create a New Wallet', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              NexSecondaryButton(
                label: 'Log in to Existing Wallet',
                onPressed: onLogin,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class NexSignupScreen extends StatefulWidget {
  const NexSignupScreen({super.key, required this.onBack, required this.onSuccess});

  final VoidCallback onBack;
  final VoidCallback onSuccess;

  @override
  State<NexSignupScreen> createState() => _NexSignupScreenState();
}

class _NexSignupScreenState extends State<NexSignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _show = false;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await context.read<WalletProvider>().signup(
            email: _email.text.trim(),
            password: _password.text,
            name: _name.text.trim(),
          );
      if (mounted) {
        showNexToast(context, 'Account created — verify your email');
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) showNexToast(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    return ColoredBox(
      color: t.appBg,
      child: Column(
        children: [
          NexScreenHeader(title: 'Get started.', onBack: widget.onBack),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              children: [
                Row(
                  children: [
                    const NexLogo(size: 40),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NEX Wallet', style: TextStyle(fontWeight: FontWeight.w600, color: t.text)),
                        const NexLabel('Secure. Simple. Yours.', color: nexBlue),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Create your self-custody wallet in a minute.',
                  style: TextStyle(fontSize: 15, color: t.text2),
                ),
                const SizedBox(height: 16),
                NexField(label: 'Full Name', controller: _name, placeholder: 'Shubham'),
                const SizedBox(height: 16),
                NexField(
                  label: 'Email',
                  controller: _email,
                  placeholder: 'you@email.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                NexField(
                  label: 'Password',
                  controller: _password,
                  placeholder: 'At least 8 characters',
                  obscure: !_show,
                  onToggleObscure: () => setState(() => _show = !_show),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: NexPrimaryButton(
              label: 'Continue',
              loading: _loading,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class NexLoginScreen extends StatefulWidget {
  const NexLoginScreen({
    super.key,
    required this.onBack,
    required this.onSuccess,
    this.onForgotPassword,
  });

  final VoidCallback onBack;
  final VoidCallback onSuccess;
  final VoidCallback? onForgotPassword;

  @override
  State<NexLoginScreen> createState() => _NexLoginScreenState();
}

class _NexLoginScreenState extends State<NexLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _show = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await context.read<WalletProvider>().requestLoginOtp(
            email: _email.text.trim(),
            password: _password.text,
          );
      if (!mounted) return;
      final provider = context.read<WalletProvider>();
      if (provider.pendingLoginEmail != null) {
        widget.onSuccess();
      } else {
        showNexToast(context, 'Logged in');
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) showNexToast(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    return ColoredBox(
      color: t.appBg,
      child: Column(
        children: [
          NexScreenHeader(title: 'Welcome back.', onBack: widget.onBack),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              children: [
                Column(
                  children: [
                    const NexLogo(size: 56),
                    const SizedBox(height: 8),
                    Text('NEX Wallet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: t.text)),
                    const NexLabel('Secure. Simple. Yours.', color: nexBlue),
                  ],
                ),
                const SizedBox(height: 20),
                NexField(
                  label: 'Email',
                  controller: _email,
                  placeholder: 'you@email.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                NexField(
                  label: 'Password',
                  controller: _password,
                  placeholder: 'Your password',
                  obscure: !_show,
                  onToggleObscure: () => setState(() => _show = !_show),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: widget.onForgotPassword,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: t.text2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: NexPrimaryButton(label: 'Log In', loading: _loading, onPressed: _submit),
          ),
        ],
      ),
    );
  }
}

class NexApiSettingsSheet extends StatefulWidget {
  const NexApiSettingsSheet({super.key});

  @override
  State<NexApiSettingsSheet> createState() => _NexApiSettingsSheetState();
}

class _NexApiSettingsSheetState extends State<NexApiSettingsSheet> {
  late final _url = TextEditingController(text: ApiConfig.baseUrl);
  late final _key = TextEditingController(text: ApiConfig.apiKey ?? '');
  bool _obscure = true;

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('API Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.text)),
            const SizedBox(height: 12),
            NexField(label: 'API URL', controller: _url, placeholder: ApiConfig.defaultBaseUrl),
            const SizedBox(height: 12),
            NexField(
              label: 'Futre API Key',
              controller: _key,
              placeholder: 'futre_live_...',
              obscure: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
            ),
            const SizedBox(height: 16),
            NexPrimaryButton(
              label: 'Save',
              onPressed: () async {
                final provider = context.read<WalletProvider>();
                await provider.setApiBaseUrl(_url.text.trim());
                await provider.setApiKey(_key.text.trim().isEmpty ? null : _key.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  showNexToast(context, 'API settings saved');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
