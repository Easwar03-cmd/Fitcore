import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _dio = Dio(BaseOptions(
    baseUrl: '${AppConstants.apiBaseUrl}/api/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  // Step 1: request code
  final _emailCtrl = TextEditingController();
  // Step 2: confirm reset
  final _codeCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _step2 = false;
  String? _generatedCode; // shown to user when no email service
  bool _loading = false;
  String? _error;
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _dio.close();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _dio.post('/auth/forgot-password', data: {'email': email});
      final data = res.data['data'] as Map<String, dynamic>;
      setState(() {
        _loading = false;
        _step2 = true;
        _generatedCode = data['code'] as String?;
        if (_generatedCode != null) _codeCtrl.text = _generatedCode!;
      });
    } on DioException catch (e) {
      final msg = (e.response?.data?['error']?['message'] as String?) ?? 'Request failed.';
      setState(() { _loading = false; _error = msg; });
    } catch (_) {
      setState(() { _loading = false; _error = 'Something went wrong.'; });
    }
  }

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

    setState(() { _loading = true; _error = null; });
    try {
      await _dio.post('/auth/reset-password', data: {'code': code, 'newPassword': newPass});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated. Please log in.')),
        );
        context.pop();
      }
    } on DioException catch (e) {
      final msg = (e.response?.data?['error']?['message'] as String?) ?? 'Reset failed.';
      setState(() { _loading = false; _error = msg; });
    } catch (_) {
      setState(() { _loading = false; _error = 'Something went wrong.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _step2 ? _buildStep2() : _buildStep1(),
        ),
      ),
    );
  }

  Widget _buildStep1() {
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
        Text('Enter your email and we\'ll generate a reset code.',
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
              ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Get Reset Code'),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.key, size: 56, color: AppColors.primary),
        const SizedBox(height: 24),
        Text('Enter your reset code',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        if (_generatedCode != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    Text('Your reset code', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Text(_generatedCode!,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            letterSpacing: 4, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy code',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _generatedCode!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied'), duration: Duration(seconds: 1)));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('This code expires in 15 minutes.',
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
              icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
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
              ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Reset Password'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() { _step2 = false; _error = null; }),
          child: const Text('Use a different email'),
        ),
      ],
    );
  }
}
