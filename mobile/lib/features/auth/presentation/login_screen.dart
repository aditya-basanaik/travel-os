import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:travel_os/core/theme/app_theme.dart';
import 'package:travel_os/features/auth/data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await ref.read(authRepositoryPrv).login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (!kIsWeb) {
        final googleSignIn = GoogleSignIn(
          scopes: const ['email', 'profile'],
          serverClientId: const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
        );
        final account = await googleSignIn.signIn();
        if (account == null) return;
        final authentication = await account.authentication;
        final idToken = authentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw Exception('Google did not return an ID token.');
        }
        final error = await ref.read(authRepositoryPrv).loginWithGoogleToken(idToken);
        if (mounted) setState(() => _errorMessage = error);
        return;
      }
      final redirect = Uri.parse('travelos://auth/callback');
      final authUrl = Uri.https(
        'auth.emergentagent.com',
        '/',
        {'redirect': redirect.toString()},
      );
      final callback = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: redirect.scheme,
      );
      final sessionId = Uri.parse(callback).fragment.isEmpty
          ? null
          : Uri.splitQueryString(Uri.parse(callback).fragment)['session_id'];
      if (sessionId == null || sessionId.isEmpty) {
        throw Exception('Google sign-in did not return a session.');
      }
      final error = await ref.read(authRepositoryPrv).loginWithGoogleSession(sessionId);
      if (mounted) setState(() => _errorMessage = error);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Google sign-in was cancelled or failed.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Emblem
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppTheme.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.travel_explore_rounded,
                        size: 40,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Brand Headers
                  Center(
                    child: Text(
                      'TRAVEL OS',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppTheme.primary,
                            letterSpacing: 4,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Welcome Back',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Plan, organize, and track your travels in one workspace.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.mutedText,
                          ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Error Toast Alert
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
                              style: GoogleFonts.dmSans(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Email Field
                  Text(
                    'Email Address',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Email is required';
                      if (!val.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Password Field
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Password',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foreground,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/forgot-password'),
                        child: Text(
                          'Forgot password?',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Password is required';
                      if (val.length < 8) return 'Password must be at least 8 characters';
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                      suffixIcon: GestureDetector(
                        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        child: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sign In'),
                  ),
                  const SizedBox(height: 20),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Color(0xFFE0DCD3))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR CONTINUE WITH',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: AppTheme.mutedText,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: Color(0xFFE0DCD3))),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Google login button
                  OutlinedButton(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                      side: const BorderSide(color: Color(0xFFE0DCD3)),
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.foreground,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'G',
                          style: TextStyle(
                            color: Color(0xFF4285F4),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Google',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Toggle screen view
                  Wrap(
                    alignment: WrapAlignment.center,
                    runSpacing: 4,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: GoogleFonts.dmSans(color: AppTheme.mutedText),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/register'),
                        child: Text(
                          'Sign up free',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
