import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:travel_os/core/theme/app_theme.dart';
import 'package:travel_os/features/auth/data/auth_repository.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String token;

  const ResetPasswordScreen({super.key, required this.token});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _success = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await ref.read(authRepositoryPrv).resetPassword(
      widget.token,
      _passwordController.text,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (error == null) {
          _success = true;
        } else {
          _errorMessage = error;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.foreground),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: _success ? _buildSuccess() : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: AppTheme.secondary, shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded, size: 40, color: AppTheme.primary),
        ),
        const SizedBox(height: 24),
        Text(
          'Password Updated!',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Your password has been changed. You can now sign in.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(color: AppTheme.mutedText),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => context.go('/login'),
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Back to Sign In'),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: AppTheme.secondary, shape: BoxShape.circle),
              child: const Icon(Icons.lock_reset_rounded, size: 40, color: AppTheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'NEW PASSWORD',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.primary, letterSpacing: 4),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Set New Password',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 28, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Choose a strong password of at least 8 characters.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedText),
            ),
          ),
          const SizedBox(height: 32),
          if (widget.token.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
              ),
              child: Text(
                'No reset token found. Please use the link from your email or the dev reset link.',
                style: GoogleFonts.dmSans(color: AppTheme.accent, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/forgot-password'),
              child: const Text('Request New Link'),
            ),
          ] else ...[
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.dmSans(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text('New Password', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Password is required';
                if (val.length < 8) return 'Must be at least 8 characters';
                return null;
              },
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                  child: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Confirm Password', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Please confirm your password';
                if (val != _passwordController.text) return 'Passwords do not match';
                return null;
              },
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  child: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Set New Password'),
            ),
          ],
        ],
      ),
    );
  }
}
