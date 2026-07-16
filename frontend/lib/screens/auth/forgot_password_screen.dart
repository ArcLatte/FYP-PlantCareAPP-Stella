import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';

enum _ResetStep { email, code, password }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _codeFocusNode = FocusNode();

  _ResetStep _step = _ResetStep.email;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _codeFocusNode.addListener(_refreshCodeFocus);
  }

  void _refreshCodeFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _focusCode() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _codeFocusNode.requestFocus();
    });
  }

  Future<void> _requestCode({bool resend = false}) async {
    if (!resend && !_emailFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _codeError = null;
    });
    try {
      await ApiService.requestPasswordReset(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _step = _ResetStep.code;
        if (!resend) _codeController.clear();
      });
      _focusCode();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resend
                ? 'A new code can be sent once per minute.'
                : 'If that email is registered, a code is on its way.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = AppErrorMessages.message(
          error,
          fallback: 'Could not send the reset code. Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.length != 6) {
      setState(() => _codeError = 'Enter the complete six-digit code');
      _focusCode();
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _codeError = null;
    });
    try {
      await ApiService.verifyPasswordResetCode(
        email: _emailController.text.trim(),
        code: _codeController.text,
      );
      if (!mounted) return;
      setState(() => _step = _ResetStep.password);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _codeError = AppErrorMessages.message(
          error,
          fallback: 'That code is invalid or has expired.',
        ),
      );
      _focusCode();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ApiService.confirmPasswordReset(
        email: _emailController.text.trim(),
        code: _codeController.text,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.go('/login');
      messenger.showSnackBar(
        const SnackBar(content: Text('Password reset. You can now sign in.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = AppErrorMessages.message(
          error,
          fallback: 'Could not reset your password. Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goBack() {
    if (_step == _ResetStep.email) {
      context.go('/login');
      return;
    }
    setState(() {
      _errorMessage = null;
      _codeError = null;
      _step = _step == _ResetStep.password ? _ResetStep.code : _ResetStep.email;
    });
    if (_step == _ResetStep.code) _focusCode();
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _ResetStep.email => 'Forgot your password?',
      _ResetStep.code => 'Check your email',
      _ResetStep.password => 'Create a new password',
    };
    final subtitle = switch (_step) {
      _ResetStep.email =>
        'Enter the email linked to your Stella account and we will send you a six-digit code.',
      _ResetStep.code =>
        'Enter the six-digit code sent to ${_emailController.text.trim()}. It expires in 10 minutes.',
      _ResetStep.password =>
        'Your code is verified. Choose a secure password for your account.',
    };

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton.filledTonal(
                onPressed: _isLoading ? null : _goBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(height: 30),
              _StepIndicator(step: _step.index),
              const SizedBox(height: 30),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  _step == _ResetStep.code
                      ? Icons.mark_email_read_outlined
                      : _step == _ResetStep.password
                      ? Icons.password_rounded
                      : Icons.lock_reset_rounded,
                  color: AppColors.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 24),
              Text(title, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 32),
              if (_errorMessage != null) ...[
                _ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 20),
              ],
              if (_step == _ResetStep.email) _buildEmailStep(),
              if (_step == _ResetStep.code) _buildCodeStep(),
              if (_step == _ResetStep.password) _buildPasswordStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return 'Enter your email';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                return 'Enter a valid email';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              if (!_isLoading) _requestCode();
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _requestCode,
            child: _loadingOrText('Send reset code'),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStep() {
    return Column(
      children: [
        _CodeInput(
          controller: _codeController,
          focusNode: _codeFocusNode,
          enabled: !_isLoading,
          errorText: _codeError,
          onChanged: (_) {
            if (_codeError != null) setState(() => _codeError = null);
          },
          onSubmitted: (_) {
            if (!_isLoading) _verifyCode();
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyCode,
          child: _loadingOrText('Verify code'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading ? null : () => _requestCode(resend: true),
          child: const Text("Didn't receive it? Resend code"),
        ),
        TextButton(
          onPressed: _isLoading
              ? null
              : () => setState(() {
                  _step = _ResetStep.email;
                  _codeController.clear();
                  _codeError = null;
                  _errorMessage = null;
                }),
          child: const Text('Use a different email'),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter a new password';
              }
              if (value.length < 8) return 'Use at least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Confirm new password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) => value == _passwordController.text
                ? null
                : 'Passwords do not match',
            onFieldSubmitted: (_) {
              if (!_isLoading) _resetPassword();
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _resetPassword,
            child: _loadingOrText('Set new password'),
          ),
        ],
      ),
    );
  }

  Widget _loadingOrText(String text) {
    return _isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(text);
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Email', 'Code', 'Password'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= step;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 4,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      labels[index],
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: active ? AppColors.primary : Colors.grey,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < labels.length - 1) const SizedBox(width: 8),
            ],
          ),
        );
      }),
    );
  }
}

class _CodeInput extends StatelessWidget {
  const _CodeInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
    this.errorText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final digits = controller.text;
    return Semantics(
      label: 'Six-digit reset code',
      textField: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: enabled ? () => focusNode.requestFocus() : null,
            child: Stack(
              children: [
                Row(
                  children: List.generate(6, (index) {
                    final isActive =
                        focusNode.hasFocus && index == digits.length;
                    final hasError = errorText != null;
                    return Expanded(
                      child: Container(
                        height: 62,
                        margin: EdgeInsets.only(right: index == 5 ? 0 : 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: hasError
                              ? AppColors.error.withValues(alpha: 0.05)
                              : AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasError
                                ? AppColors.error
                                : isActive
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.22),
                            width: isActive || hasError ? 1.8 : 1,
                          ),
                        ),
                        child: Text(
                          index < digits.length ? digits[index] : '',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    );
                  }),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.01,
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: enabled,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                      ),
                      maxLength: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                errorText!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
