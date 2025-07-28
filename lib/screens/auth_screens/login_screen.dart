import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeline/components/navigation.dart';
import 'package:lifeline/screens/auth_screens/forgotpass_screen.dart';
import 'package:lifeline/screens/auth_screens/signup_screen.dart';

import 'package:lifeline/services/auth_service.dart';
import 'package:lifeline/screens/main_screens/home_screen.dart';
import 'package:lifeline/components/clip_wave.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  // Custom icons (make sure to add these assets to your project)
  final emailIcon =
      Image.asset('assets/images/icons/email.png', width: 24, height: 24);
  final passwordIcon =
      Image.asset('assets/images/icons/password.png', width: 24, height: 24);
  final eyeSlashIcon =
      Image.asset('assets/images/icons/show.png', width: 24, height: 24);
  final eyeIcon =
      Image.asset('assets/images/icons/hide.png', width: 24, height: 24);

// Custom border with subtle animation
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
  );

  final RegExp _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  void _validateAndLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!_emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Wrong email format"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password cannot be empty"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      bool isSuccess =
          await AuthService().login(email: email, password: password);

      if (isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Login successful"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        );
      }
    } catch (e) {
      String message = "Error: ${e.toString()}";
      if (e is FirebaseAuthException) {
        if (e.code == 'user-not-found') {
          message = 'No user exists with that email';
        } else if (e.code == 'wrong-password') {
          message = 'Wrong password provided';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
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
            height: size.height * 0.35,
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
                        colors: [
                          Color(0xFFFF6F61),
                          Color(0xFFFF6F61),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom content (form)
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 300),
                    tween: Tween<double>(begin: 0.98, end: 1.0),
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: TextField(
                      controller: _emailController,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(width: 24, child: emailIcon),
                        ),
                        hintText: 'Email Address',
                        hintStyle: GoogleFonts.nunito(
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 18),
                        enabledBorder: border,
                        focusedBorder: border.copyWith(
                          borderSide: const BorderSide(
                            color: Color(0xFFFF6F61),
                            width: 2,
                          ),
                        ),
                        border: border,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

// Password TextField
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 300),
                    tween: Tween<double>(begin: 0.98, end: 1.0),
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
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
                                  _isPasswordVisible ? eyeSlashIcon : eyeIcon,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        hintText: 'Password',
                        hintStyle: GoogleFonts.nunito(
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 18),
                        enabledBorder: border,
                        focusedBorder: border.copyWith(
                          borderSide: const BorderSide(
                            color: Color(0xFFFF6F61),
                            width: 2,
                          ),
                        ),
                        border: border,
                      ),
                    ),
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
                          color: Color(0xFFFF6F61),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _validateAndLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6F61),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        "Login",
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final user = await AuthService().signInWithGoogle();
                          if (user != null) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HomeScreen(),
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  "Google Sign-In Failed: ${e.toString()}"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: Image.asset('assets/images/icons/google.png',
                          width: 24, height: 24),
                      label: Text(
                        "Login with Google",
                        style: GoogleFonts.nunito(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE0E0E0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: GoogleFonts.nunito(),
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
                            color: const Color(0xFFFF6F61),
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
