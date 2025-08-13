import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lifeline/components/custom_button.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/views/auth/widgets/auth_header.dart';
import 'package:lifeline/components/custom_text_field.dart';
import 'package:lifeline/views/auth/auth_validators.dart';

class ForgotpassScreen extends StatefulWidget {
  const ForgotpassScreen({super.key});

  @override
  State<ForgotpassScreen> createState() => _ForgotpassScreenState();
}

class _ForgotpassScreenState extends State<ForgotpassScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isSending = false;
  final Widget emailIcon =
      Image.asset('assets/images/icons/email.png', width: 24, height: 24);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _sendResetLink(String email) async {
    try {
      setState(() => _isSending = true);
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent.'),
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      _showSnackBar("Error: $e", AppColors.error);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _validateAndSend() async {
    if (_isSending) return;
    final email = _emailController.text.trim();
    if (!AuthValidators.isValidEmail(email)) {
      _showSnackBar("Please enter a valid email", AppColors.error);
      return;
    }
    try {
      setState(() => _isSending = true);
      // Check existence using your own users collection to avoid enumeration protection issues
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        _showSnackBar("No account found for this email", AppColors.error);
        return;
      }
      await _sendResetLink(email);
    } catch (e) {
      _showSnackBar("Error: $e", AppColors.error);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const AuthHeader(heightFactor: 0.40, showBack: true),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Forgot Password?",
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Enter your email, and we’ll send you a password reset link.",
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 30),
                  CustomTextField(
                    controller: _emailController,
                    hintText: 'Email Address',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: emailIcon,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: CustomButton(
                      text: "Send Reset Link",
                      onPressed: _validateAndSend,
                      isLoading: _isSending,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
