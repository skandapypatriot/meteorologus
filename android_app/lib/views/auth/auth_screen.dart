import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/glass_container.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _infoMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password.')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    if (auth.isSignUpMode) {
      if (password.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password must be at least 6 characters.')),
        );
        return;
      }
      await auth.signUp(email, password);
    } else {
      await auth.signIn(email, password);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email above first.')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.sendPasswordReset(email);
    if (ok && mounted) {
      setState(() {
        _infoMessage = 'Reset email sent to $email. Check your inbox.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final theme = themeProvider.theme;
    final isSignUp = auth.isSignUpMode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: theme.gradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hero Icon & Title
                    const Text('🌤️', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 8),
                    Text(
                      'Meteorologus',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your weather, on your device',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.textColor.withAlpha(200),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in to see your weather nodes, live telemetry and ML forecasts.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.textColor.withAlpha(150),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Glass Auth Card
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            isSignUp ? 'Create account' : 'Sign in',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: theme.textColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Email Field
                          Text(
                            'EMAIL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: theme.textColor.withAlpha(140),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                              color: theme.textColor,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'user@example.com',
                              hintStyle: TextStyle(
                                color: theme.textColor.withAlpha(90),
                              ),
                              filled: true,
                              fillColor: Colors.black.withAlpha(40),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withAlpha(30),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withAlpha(30),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: theme.textColor.withAlpha(160),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Password Field
                          Text(
                            'PASSWORD',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: theme.textColor.withAlpha(140),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(
                              color: theme.textColor,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              hintStyle: TextStyle(
                                color: theme.textColor.withAlpha(90),
                              ),
                              filled: true,
                              fillColor: Colors.black.withAlpha(40),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withAlpha(30),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withAlpha(30),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: theme.textColor.withAlpha(160),
                                  width: 1.5,
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: theme.textColor.withAlpha(150),
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),

                          if (auth.errorMessage != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              auth.errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFFB7185),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],

                          if (_infoMessage != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _infoMessage!,
                              style: const TextStyle(
                                color: Color(0xFF4ADE80),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Primary Action Button
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x4D3B82F6),
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: auth.isLoading ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      isSignUp ? 'Create account' : 'Sign in',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Mode Switch Ghost Button
                          OutlinedButton(
                            onPressed: auth.isLoading ? null : auth.toggleMode,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(
                                color: Colors.white.withAlpha(40),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isSignUp
                                  ? 'I already have an account'
                                  : 'Create a new account',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.textColor,
                              ),
                            ),
                          ),

                          if (!isSignUp) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed:
                                  auth.isLoading ? null : _handleForgotPassword,
                              child: Text(
                                'Forgot password?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textColor.withAlpha(160),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
