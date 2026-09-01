import 'package:tally/core/supabase_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Must match Supabase Auth → "Email OTP Length" (dashboard setting).
  static const _codeLength = 8;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _codeSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // Step 1 — email the user a 6-digit one-time code.
  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _loading = true);
    try {
      await supabase.auth.signInWithOtp(email: email);
      if (mounted) setState(() => _codeSent = true);
    } on Exception catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Step 2 — exchange the code for a session. On success the auth state
  // change fires and the router redirects to /groups automatically.
  Future<void> _verifyCode() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _loading = true);
    try {
      await supabase.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );
      // No manual navigation — GoRouter's auth redirect handles it.
    } on Exception catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Tally',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Split expenses simply.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 56),
                if (_codeSent) ..._codeStep(theme) else ..._emailStep(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _emailStep() {
    return [
      TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _sendCode(),
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Email address',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.email_outlined),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _loading ? null : _sendCode,
        child: _loading
            ? const _ButtonSpinner()
            : const Text('Send login code'),
      ),
    ];
  }

  List<Widget> _codeStep(ThemeData theme) {
    return [
      Text(
        'Enter the $_codeLength-digit code we emailed to '
        '${_emailController.text.trim()}.',
        style: theme.textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _verifyCode(),
        autofocus: true,
        maxLength: _codeLength,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 6),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          counterText: '',
          hintText: '•' * _codeLength,
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _loading ? null : _verifyCode,
        child: _loading
            ? const _ButtonSpinner()
            : const Text('Verify & log in'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _loading
            ? null
            : () => setState(() {
                  _codeSent = false;
                  _codeController.clear();
                }),
        child: const Text('Use a different email'),
      ),
    ];
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
