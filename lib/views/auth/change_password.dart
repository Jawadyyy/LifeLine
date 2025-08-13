import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeline/components/custom_button.dart';
import 'package:lifeline/components/custom_text_field.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/views/auth/login_screen.dart';
import 'package:lifeline/views/auth/widgets/auth_header.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isChanging = false;

  final passwordIcon =
      Image.asset('assets/images/icons/password.png', width: 24, height: 24);
  final eyeSlashIcon =
      Image.asset('assets/images/icons/show.png', width: 24, height: 24);
  final eyeIcon =
      Image.asset('assets/images/icons/hide.png', width: 24, height: 24);

  void _changePassword() async {
    if (_isChanging) return;
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please fill in all fields.",
        backgroundColor: AppColors.error,
      );
      return;
    }

    if (newPassword != confirmPassword) {
      Fluttertoast.showToast(
        msg: "Passwords do not match.",
        backgroundColor: AppColors.error,
      );
      return;
    }

    try {
      setState(() => _isChanging = true);
      await _auth.currentUser!.updatePassword(newPassword);

      Fluttertoast.showToast(
        msg: "Password changed successfully!",
        backgroundColor: AppColors.success,
      );

      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      String errorMessage = "An error occurred. Please try again.";

      if (e is FirebaseAuthException) {
        if (e.code == 'weak-password') {
          errorMessage = "The password is too weak.";
        } else if (e.code == 'requires-recent-login') {
          errorMessage = "Please log in again to change your password.";
        }
      }

      Fluttertoast.showToast(
        msg: errorMessage,
        backgroundColor: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _isChanging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const AuthHeader(heightFactor: 0.30, showBack: true),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Change Password",
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Enter your new password.",
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 30),
                  CustomTextField(
                    controller: _newPasswordController,
                    hintText: 'New Password',
                    obscureText: !_isNewPasswordVisible,
                    prefixIcon: passwordIcon,
                    suffixIcon: _isNewPasswordVisible ? eyeSlashIcon : eyeIcon,
                    onSuffixTap: () {
                      setState(() {
                        _isNewPasswordVisible = !_isNewPasswordVisible;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: _confirmPasswordController,
                    hintText: 'Confirm New Password',
                    obscureText: !_isConfirmPasswordVisible,
                    prefixIcon: passwordIcon,
                    suffixIcon:
                        _isConfirmPasswordVisible ? eyeSlashIcon : eyeIcon,
                    onSuffixTap: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: CustomButton(
                      text: "Change",
                      onPressed: _changePassword,
                      isLoading: _isChanging,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
