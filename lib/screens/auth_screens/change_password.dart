import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lifeline/components/clip_wave.dart';
import 'package:lifeline/screens/auth_screens/login_screen.dart';

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

  final OutlineInputBorder border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
  );

  final passwordIcon =
      Image.asset('assets/images/icons/password.png', width: 24, height: 24);
  final eyeSlashIcon =
      Image.asset('assets/images/icons/show.png', width: 24, height: 24);
  final eyeIcon =
      Image.asset('assets/images/icons/hide.png', width: 24, height: 24);

  void _changePassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please fill in all fields.",
        backgroundColor: Colors.red,
      );
      return;
    }

    if (newPassword != confirmPassword) {
      Fluttertoast.showToast(
        msg: "Passwords do not match.",
        backgroundColor: Colors.red,
      );
      return;
    }

    try {
      await _auth.currentUser!.updatePassword(newPassword);

      Fluttertoast.showToast(
        msg: "Password changed successfully!",
        backgroundColor: Colors.green,
      );

      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
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
        backgroundColor: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SizedBox(
            height: size.height * 0.30,
            child: Stack(
              children: [
                ClipPath(
                  clipper: TopWaveClipper(),
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF6F61), Color(0xFFFF6F61)],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, top: 10),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Enter your new password.",
                    style: GoogleFonts.nunito(fontSize: 16),
                  ),
                  const SizedBox(height: 30),

                  /// New Password
                  TextField(
                    controller: _newPasswordController,
                    obscureText: !_isNewPasswordVisible,
                    style: GoogleFonts.nunito(fontSize: 16),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(width: 24, child: passwordIcon),
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: IconButton(
                          icon: SizedBox(
                            width: 24,
                            child:
                                _isNewPasswordVisible ? eyeSlashIcon : eyeIcon,
                          ),
                          onPressed: () {
                            setState(() {
                              _isNewPasswordVisible = !_isNewPasswordVisible;
                            });
                          },
                        ),
                      ),
                      hintText: 'New Password',
                      hintStyle: GoogleFonts.nunito(
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      enabledBorder: border,
                      focusedBorder: border.copyWith(
                        borderSide: const BorderSide(
                          color: Color(0xFFFF6F61),
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// Confirm Password
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    style: GoogleFonts.nunito(fontSize: 16),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(width: 24, child: passwordIcon),
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: IconButton(
                          icon: SizedBox(
                            width: 24,
                            child: _isConfirmPasswordVisible
                                ? eyeSlashIcon
                                : eyeIcon,
                          ),
                          onPressed: () {
                            setState(() {
                              _isConfirmPasswordVisible =
                                  !_isConfirmPasswordVisible;
                            });
                          },
                        ),
                      ),
                      hintText: 'Confirm New Password',
                      hintStyle: GoogleFonts.nunito(
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      enabledBorder: border,
                      focusedBorder: border.copyWith(
                        borderSide: const BorderSide(
                          color: Color(0xFFFF6F61),
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6F61),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        "Change",
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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
