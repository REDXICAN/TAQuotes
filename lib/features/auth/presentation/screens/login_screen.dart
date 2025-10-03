// lib/features/auth/presentation/screens/login_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/utils/input_validators.dart';
import '../../../../core/services/validation_service.dart';
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
          // Navigate to pending approval screen
          context.go('/auth/pending-approval', extra: {
            'email': _emailController.text.trim(),
            'name': _nameController.text.trim(),
          });
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
        // Check if this is a pending approval error
        if (error.contains('pending approval')) {
          // Extract email from the error message if available
          context.go('/auth/pending-approval', extra: {
            'email': _emailController.text.trim(),
            'name': '', // We don't have the name during login
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
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
                // Validate email before sending reset
                final emailValidation = InputValidators.validateEmail(email);
                if (emailValidation != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(emailValidation),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Check for malicious content
                if (ValidationService.containsXss(email)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid email format'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

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
              theme.primaryColor.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: ResponsiveHelper.isMobile(context) 
                    ? MediaQuery.of(context).size.width * 0.9  // 90% width on mobile
                    : math.max(MediaQuery.of(context).size.width / 3, 400),   // 33% width on desktop, min 400
                  minWidth: ResponsiveHelper.isMobile(context) 
                    ? 250  // Min width on mobile
                    : 350, // Minimum width for desktop
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
                        // Logo - Direct display without container
                        Image.network(
                          '/turbo_air_logo.png',
                          height: 80,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to asset if network fails
                            return Image.asset(
                              'assets/logos/turbo_air_logo.png',
                              height: 80,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error2, stackTrace2) {
                                // Final fallback to text
                                return Text(
                                  'TURBO AIR',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          _isSignUp ? 'Create Account' : 'Welcome Back',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onSurface,
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
                            // Use comprehensive email validation
                            final emailValidation = InputValidators.validateEmail(value);
                            if (emailValidation != null) {
                              return emailValidation;
                            }

                            // Additional security check for malicious content
                            if (value != null && ValidationService.containsXss(value)) {
                              return 'Invalid characters in email address';
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

                            // Enhanced password validation for signup
                            if (_isSignUp) {
                              final passwordValidation = ValidationService.validatePassword(value);
                              if (!passwordValidation.isValid) {
                                return passwordValidation.message;
                              }
                            } else {
                              // Basic length check for login
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                            }

                            // Note: Passwords should NOT be checked for XSS/SQL injection
                            // as they need to allow special characters for security

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
                              if (_isSignUp) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your name';
                                }

                                // Validate name format and security
                                if (!ValidationService.isValidName(value)) {
                                  return 'Please enter a valid name (letters, spaces, hyphens, and apostrophes only)';
                                }

                                // Check for malicious content
                                if (ValidationService.containsXss(value) || ValidationService.containsSqlInjection(value)) {
                                  return 'Invalid characters in name';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Role selection dropdown
                          DropdownButtonFormField<String>(
                            initialValue: _selectedRole,
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
                              fontSize: 16,
                            ),
                            dropdownColor: Theme.of(context).cardColor,
                            decoration: InputDecoration(
                              labelText: 'Account Role',
                              prefixIcon: const Icon(Icons.work),
                              helperText: 'Select your account type',
                              helperMaxLines: 2,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Colors.grey[50],
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'Sales',
                                child: Text(
                                  'Sales Representative',
                                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Distribution',
                                child: Text(
                                  'Distributor',
                                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Admin',
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Administrator (Requires Approval)',
                                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87),
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'SuperAdmin',
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Super Administrator (Requires Approval)',
                                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87),
                                  ),
                                ),
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
                          
                          // All accounts now require approval
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'All new accounts require admin approval before access',
                                    style: TextStyle(fontSize: 12, color: Colors.blue[800]),
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

                        // Role approval info
                        if (_isSignUp) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: Colors.blue, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Admin and SuperAdmin roles require approval from existing administrators',
                                    style: TextStyle(
                                      color: Colors.blue[700],
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
    );
  }
}
