import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lifeline/components/custom_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lifeline/components/phone_field.dart';
import 'package:lifeline/views/auth/otp_screen.dart';
import 'package:lifeline/components/clip_wave.dart';
import 'package:lifeline/constants/app_colors.dart';

class ForgotpassScreen extends StatefulWidget {
  const ForgotpassScreen({super.key});

  @override
  State<ForgotpassScreen> createState() => _ForgotpassScreenState();
}

class _ForgotpassScreenState extends State<ForgotpassScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _phoneNumber = "";

  Future<void> _sendOTP(String phone) async {
    try {
      final otp = Random().nextInt(900000) + 100000;
      String formattedPhone = phone.replaceAll(RegExp(r'\D'), '');

      final whatsappUrl =
          'https://wa.me/$formattedPhone?text=${Uri.encodeFull("Your OTP is $otp")}';

      await _firestore.collection('otps').doc(phone).set({
        'otp': otp,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!await launchUrl(
        Uri.parse(whatsappUrl),
        mode: LaunchMode.externalApplication,
      )) {
        throw 'Could not launch $whatsappUrl';
      }

      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              OTPScreen(phone: phone, otp: otp),
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
      _showSnackBar("Error: $e", AppColors.error);
    }
  }

  void _validateAndSend() {
    if (_phoneNumber.isEmpty) {
      _showSnackBar("Please enter a valid phone number", AppColors.error);
      return;
    }
    _sendOTP(_phoneNumber);
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          SizedBox(
            height: size.height * 0.40,
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
                        colors: [AppColors.primary, AppColors.primary],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, top: 10),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.textTertiary),
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
                    "Forgot Password?",
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Don’t worry! Enter your phone number and we’ll send you an OTP via WhatsApp.",
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 30),
                  PhoneForm(
                    onPhoneChanged: (phone) {
                      setState(() {
                        _phoneNumber = phone;
                      });
                    },
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: CustomButton(
                      text: "Send OTP via WhatsApp",
                      onPressed: _validateAndSend,
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
