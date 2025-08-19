// lib/features/auth/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/sample_data_service.dart';
import '../../../../core/config/env_config.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = 'Sales';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleDemoLogin() async {
    setState(() => _isLoading = true);

    try {
      // Create a demo account with timestamp to ensure uniqueness
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final demoEmail = 'demo_$timestamp@turboair.com';
      final demoPassword = EnvConfig.demoPassword;
      const demoName = 'Demo User';

      // First create the demo account
      final signUp = ref.read(signUpProvider);
      final signUpError = await signUp(demoEmail, demoPassword, demoName, 'Sales');

      if (signUpError != null && mounted) {
        // If signup failed, try to sign in (account might exist)
        final signIn = ref.read(signInProvider);
        final signInError = await signIn(demoEmail, demoPassword);
        
        if (signInError != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Demo login failed: $signInError'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // Wait a moment for authentication to complete
      await Future.delayed(const Duration(seconds: 1));

      // Initialize sample data for the demo account
      await SampleDataService.initializeSampleData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to the demo! Sample data has been loaded.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Demo setup failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? error;

      if (_isSignUp) {
        final signUp = ref.read(signUpProvider);
        error = await signUp(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
          _selectedRole,
        );

        if (error == null && mounted) {
          if (_selectedRole == 'Admin') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Admin account created! Pending approval from superadmin. Check your email for details.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
            // Don't redirect to home for admin accounts
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account created successfully! Welcome!'),
                backgroundColor: Colors.green,
              ),
            );
            context.go('/');
          }
        }
      } else {
        final signIn = ref.read(signInProvider);
        error = await signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );

        if (error == null && mounted) {
          context.go('/');
        }
      }

      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a password reset link.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isNotEmpty) {
                Navigator.pop(dialogContext);

                final resetPassword = ref.read(resetPasswordProvider);
                final error = await resetPassword(email);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error ?? 'Password reset email sent!'),
                      backgroundColor:
                          error != null ? Colors.red : Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Send Reset Email'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.primaryColor,
              theme.primaryColor.withOpacity(0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width / 3,
                  minWidth: 350, // Minimum width for mobile devices
                ),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Image.asset(
                          'assets/logos/turbo_air_logo.png',
                          height: 80,
                          errorBuilder: (_, __, ___) => const Text(
                            'TURBO AIR',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF20429C),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          _isSignUp ? 'Create Account' : 'Welcome Back',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Email field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleAuth(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (_isSignUp && value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Additional signup fields
                        if (_isSignUp) ...[
                          // Confirm Password field
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (_isSignUp) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Name field
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Your Name',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (_isSignUp &&
                                  (value == null || value.isEmpty)) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Role selection dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: InputDecoration(
                              labelText: 'Account Role',
                              prefixIcon: const Icon(Icons.work),
                              helperText: 'Select your account type',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Sales',
                                child: Text('Sales Representative'),
                              ),
                              DropdownMenuItem(
                                value: 'Distribution',
                                child: Text('Distributor'),
                              ),
                              DropdownMenuItem(
                                value: 'Admin',
                                child: Text('Administrator (Requires Approval)'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedRole = value!;
                              });
                            },
                            validator: (value) {
                              if (_isSignUp && (value == null || value.isEmpty)) {
                                return 'Please select your role';
                              }
                              return null;
                            },
                          ),
                          
                          // Admin role warning
                          if (_selectedRole == 'Admin')
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 20, color: Colors.orange[700]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Admin accounts require approval from the super admin',
                                      style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleAuth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF20429C),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text(
                                    _isSignUp ? 'Sign Up' : 'Sign In',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Forgot password (only for sign in)
                        if (!_isSignUp) ...[
                          TextButton(
                            onPressed: () {
                              _showForgotPasswordDialog();
                            },
                            child: const Text('Forgot Password?'),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Toggle sign up/sign in
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isSignUp
                                  ? 'Already have an account?'
                                  : "Don't have an account?",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isSignUp = !_isSignUp;
                                  _formKey.currentState?.reset();
                                  // Clear password fields when switching
                                  _passwordController.clear();
                                  _confirmPasswordController.clear();
                                  // Reset role to default
                                  _selectedRole = 'Sales';
                                });
                              },
                              child: Text(
                                _isSignUp ? 'Sign In' : 'Sign Up',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),

                        // First user info
                        if (_isSignUp) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.purple.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: Colors.purple, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'First user to sign up becomes Super Admin',
                                    style: TextStyle(
                                      color: Colors.purple[700],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ),
          ),
        ),
      ),
      // Demo button at the bottom
      bottomNavigationBar: Container(
        color: Colors.transparent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Want to explore the app?',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 200,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleDemoLogin,
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Try Demo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      backgroundColor: Colors.white.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Creates a demo account with sample data',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
