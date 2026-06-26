import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeline/components/custom_button.dart';
import 'package:lifeline/views/auth/forgotpass_screen.dart';
import 'package:lifeline/views/auth/signup_screen.dart';
import 'package:lifeline/services/auth_service.dart';
import 'package:lifeline/components/custom_text_field.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/views/auth/widgets/auth_header.dart';
import 'package:lifeline/views/auth/widgets/google_login_button.dart';
import 'package:lifeline/views/auth/auth_validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoggingIn = false;
  bool _isGoogleLoading = false;

  final emailIcon =
      Image.asset('assets/images/icons/email.png', width: 24, height: 24);
  final passwordIcon =
      Image.asset('assets/images/icons/password.png', width: 24, height: 24);
  final eyeSlashIcon =
      Image.asset('assets/images/icons/show.png', width: 24, height: 24);
  final eyeIcon =
      Image.asset('assets/images/icons/hide.png', width: 24, height: 24);

  void _validateAndLogin() async {
    if (_isLoggingIn || _isGoogleLoading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!AuthValidators.isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Wrong email format"),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!AuthValidators.isValidPassword(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must be at least 6 characters"),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      setState(() => _isLoggingIn = true);
      final result =
          await AuthService().loginWithEmail(email: email, password: password);

      if (!mounted) return;

      if (!result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Login failed'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // ✅ Login successful - AuthWrapper will handle navigation automatically
      debugPrint('✅ Email login successful: ${result.data?.email}');
      debugPrint('✅ User ID: ${result.data?.uid}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Login successful'),
          backgroundColor: AppColors.secondary,
        ),
      );

      // ✅ NEW: Pop the login screen so AuthWrapper can show the correct screen
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      String message = "Error: ${e.toString()}";
      if (e is FirebaseAuthException) {
        if (e.code == 'user-not-found') {
          message = 'No user exists with that email';
        } else if (e.code == 'wrong-password') {
          message = 'Wrong password provided';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  Future<void> onValidateGoogle(BuildContext context) async {
    if (_isGoogleLoading || _isLoggingIn) return;
    try {
      setState(() => _isGoogleLoading = true);
      final result = await AuthService().signInWithGoogle();

      if (!mounted) return;

      if (!result.isSuccess || result.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Google Sign-In failed'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // ✅ Google login successful - AuthWrapper will handle navigation automatically
      debugPrint('✅ Google login successful: ${result.data?.email}');
      debugPrint('✅ User ID: ${result.data?.uid}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Login successful'),
          backgroundColor: AppColors.secondary,
        ),
      );

      // ✅ NEW: Pop the login screen so AuthWrapper can show the correct screen
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Google Sign-In Failed: ${e.toString()}"),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const AuthHeader(heightFactor: 0.35),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Log In",
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _emailController,
                    hintText: "Email Address",
                    prefixIcon: emailIcon,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: _passwordController,
                    hintText: "Password",
                    prefixIcon: passwordIcon,
                    suffixIcon: _isPasswordVisible ? eyeSlashIcon : eyeIcon,
                    obscureText: !_isPasswordVisible,
                    onSuffixTap: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const ForgotpassScreen(),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            transitionDuration:
                                const Duration(milliseconds: 400),
                          ),
                        );
                      },
                      child: Text(
                        "Forgot Password?",
                        style: GoogleFonts.nunito(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: CustomButton(
                      text: "Login",
                      onPressed: _validateAndLogin,
                      isLoading: _isLoggingIn,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text("OR"),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GoogleLoginButton(
                    onPressed: () => onValidateGoogle(context),
                    isLoading: _isGoogleLoading,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: GoogleFonts.nunito(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const SignUpScreen(),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                              transitionDuration:
                                  const Duration(milliseconds: 400),
                            ),
                          );
                        },
                        child: Text(
                          "Sign Up",
                          style: GoogleFonts.nunito(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
