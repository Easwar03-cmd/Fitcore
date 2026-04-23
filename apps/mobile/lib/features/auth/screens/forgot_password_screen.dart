import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_constants.dart';
import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';

enum _Step { email, code, success }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final Dio _dio;

  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  _Step _step = _Step.email;
  String? _devCode; // non-null only when SMTP is not configured (dev fallback)
  bool _loading = false;
  String? _error;
  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      baseUrl:
          '${dotenv.env['FLUTTER_API_URL'] ?? AppConstants.apiBaseUrl}/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _dio.close();
    super.dispose();
  }

  // ── Step 1: request code ───────────────────────────────────────────────────

  Future<void> _requestCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res =
          await _dio.post('/auth/forgot-password', data: {'email': email});
      final data = res.data['data'] as Map<String, dynamic>;
      final devCode = data['code'] as String?;
      setState(() {
        _loading = false;
        _step = _Step.code;
        _devCode = devCode;
        if (devCode != null) _codeCtrl.text = devCode;
      });
    } on DioException catch (e) {
      final msg = (e.response?.data?['error']?['message'] as String?) ??
          'Request failed. Please try again.';
      setState(() {
        _loading = false;
        _error = msg;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Something went wrong.';
      });
    }
  }

  // ── Step 2: submit code + new password ─────────────────────────────────────

  Future<void> _confirmReset() async {
    final code = _codeCtrl.text.trim();
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;

    if (code.isEmpty || newPass.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    if (newPass.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _dio.post('/auth/reset-password',
          data: {'code': code, 'newPassword': newPass});
      if (mounted) setState(() { _loading = false; _step = _Step.success; });
    } on DioException catch (e) {
      final msg = (e.response?.data?['error']?['message'] as String?) ??
          'Reset failed. Please try again.';
      setState(() {
        _loading = false;
        _error = msg;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Something went wrong.';
      });
    }
  }

  // ── Back-press handling ────────────────────────────────────────────────────

  bool _handleBackPress() {
    switch (_step) {
      case _Step.email:
        return false; // let the navigator pop (go back to login)
      case _Step.code:
        setState(() {
          _step = _Step.email;
          _error = null;
        });
        return true; // consumed — stay on screen
      case _Step.success:
        context.go(AppRoutes.login);
        return true;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _Step.email,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackPress();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_appBarTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              final consumed = _handleBackPress();
              if (!consumed) context.pop();
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: switch (_step) {
              _Step.email => _buildEmailStep(),
              _Step.code => _buildCodeStep(),
              _Step.success => _buildSuccessStep(),
            },
          ),
        ),
      ),
    );
  }

  String get _appBarTitle => switch (_step) {
        _Step.email => 'Forgot Password',
        _Step.code => 'Reset Password',
        _Step.success => 'Password Updated',
      };

  // ── Step 1 widget ──────────────────────────────────────────────────────────

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.lock_reset, size: 56, color: AppColors.primary),
        const SizedBox(height: 24),
        Text('Forgot your password?',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text("Enter your email and we'll send you a reset code.",
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center),
        const SizedBox(height: 32),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _requestCode(),
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _loading ? null : _requestCode,
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Send Reset Code'),
        ),
      ],
    );
  }

  // ── Step 2 widget ──────────────────────────────────────────────────────────

  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.key, size: 56, color: AppColors.primary),
        const SizedBox(height: 24),
        Text('Check your email',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          _devCode != null
              ? 'A reset code was generated (SMTP not configured — shown below for testing).'
              : 'We sent a 6-character code to ${_emailCtrl.text.trim()}. Enter it below.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        // Dev-only code display
        if (_devCode != null) ...[
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reset code (dev)',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Text(_devCode!,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                                letterSpacing: 4,
                                fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy code',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _devCode!));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Code copied'),
                        duration: Duration(seconds: 1)));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('Expires in 15 minutes.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center),
        ],
        const SizedBox(height: 20),
        TextFormField(
          controller: _codeCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Reset Code',
            prefixIcon: Icon(Icons.vpn_key_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _newPassCtrl,
          obscureText: _obscurePass,
          decoration: InputDecoration(
            labelText: 'New Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon:
                  Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
              onPressed: () =>
                  setState(() => _obscurePass = !_obscurePass),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirmPassCtrl,
          obscureText: _obscurePass,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _confirmReset(),
          decoration: const InputDecoration(
            labelText: 'Confirm New Password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _loading ? null : _confirmReset,
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Reset Password'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () =>
              setState(() {
                _step = _Step.email;
                _error = null;
              }),
          child: const Text('Use a different email'),
        ),
      ],
    );
  }

  // ── Step 3 widget ──────────────────────────────────────────────────────────

  Widget _buildSuccessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.check_circle_outline,
            size: 80, color: AppColors.primary),
        const SizedBox(height: 24),
        Text('Password Updated!',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text('Your password has been reset successfully.\nYou can now log in with your new password.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center),
        const SizedBox(height: 40),
        FilledButton(
          onPressed: () => context.go(AppRoutes.login),
          child: const Text('Go to Login'),
        ),
      ],
    );
  }
}
