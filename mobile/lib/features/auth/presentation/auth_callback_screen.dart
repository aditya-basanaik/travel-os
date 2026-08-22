import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:travel_os/core/theme/app_theme.dart';
import 'package:travel_os/features/auth/data/auth_repository.dart';

/// Handles the Google OAuth callback after the browser redirects to
/// travelos://auth/callback?session_id=XXX
class AuthCallbackScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const AuthCallbackScreen({super.key, required this.sessionId});

  @override
  ConsumerState<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends ConsumerState<AuthCallbackScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    if (widget.sessionId.isEmpty) {
      setState(() => _error = 'Google sign-in did not return a session. Please try again.');
      return;
    }

    final error = await ref.read(authRepositoryPrv).loginWithGoogleSession(widget.sessionId);

    if (!mounted) return;
    if (error == null) {
      context.go('/');
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: _error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.accent, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Back to Login'),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppTheme.primary),
                    const SizedBox(height: 20),
                    Text(
                      'Signing you in with Google…',
                      style: GoogleFonts.dmSans(color: AppTheme.mutedText, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
