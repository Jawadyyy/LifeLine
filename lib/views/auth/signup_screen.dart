import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeline/components/custom_button.dart';
import 'package:lifeline/components/phone_field.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/views/auth/login_screen.dart';
import 'package:lifeline/services/auth_service.dart';
import 'package:lifeline/views/auth/widgets/signup_form_fields.dart';
import 'package:lifeline/views/auth/auth_validators.dart';
import 'package:lifeline/views/auth/widgets/auth_header.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _phone = '';
  bool _isPasswordVisible = false;
  bool _isSubmitting = false;

  // Kept for backwards compatibility; not used after AuthValidators adoption.
  // ignore: unused_field
  final RegExp _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  final emailIcon =
      Image.asset('assets/images/icons/email.png', width: 24, height: 24);
  final passwordIcon =
      Image.asset('assets/images/icons/password.png', width: 24, height: 24);
  final userIcon =
      Image.asset('assets/images/icons/user.png', width: 24, height: 24);
  final eyeSlashIcon =
      Image.asset('assets/images/icons/show.png', width: 24, height: 24);
  final eyeIcon =
      Image.asset('assets/images/icons/hide.png', width: 24, height: 24);

  void _registerAccount() async {
    if (_isSubmitting) return;
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final l = AppLocalizations.of(context);
    if (!AuthValidators.isNonEmpty(fullName)) {
      _showSnackbar(l.fullNameRequired);
      return;
    }

    if (!AuthValidators.isValidEmail(email)) {
      _showSnackbar(l.invalidEmailFormat);
      return;
    }

    if (!AuthValidators.isValidPassword(password)) {
      _showSnackbar(l.passwordMinLength);
      return;
    }

    try {
      setState(() => _isSubmitting = true);
      final result = await AuthService().signup(
        email: email,
        password: password,
        username: fullName,
        phone: _phone,
      );

      if (!result.isSuccess) {
        _showSnackbar(result.message ?? l.signupFailed);
        return;
      }

      _showSnackbar(l.accountRegistered, isSuccess: true);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      _showSnackbar(l.errorGeneric(e.toString()));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackbar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const AuthHeader(
              heightFactor: 0.30,
              gradientColors: [AppColors.primary, AppColors.accent]),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.signUp,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SignupFormFields(
                    nameController: _fullNameController,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    nameIcon: userIcon,
                    emailIcon: emailIcon,
                    passwordIcon: passwordIcon,
                    eyeIcon: eyeIcon,
                    eyeSlashIcon: eyeSlashIcon,
                    isPasswordVisible: _isPasswordVisible,
                    onTogglePassword: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  PhoneForm(
                    onPhoneChanged: (phone) {
                      setState(() {
                        _phone = phone;
                      });
                    },
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: CustomButton(
                      text: l.signUp,
                      onPressed: _registerAccount,
                      isLoading: _isSubmitting,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l.haveAccount,
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
                                      const LoginScreen(),
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
                          l.logIn,
                          style: GoogleFonts.nunito(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
