import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'package:lifeline/screens/auth_screens/otp_screen.dart';
import 'package:lifeline/components/phone_field.dart';

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

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OTPScreen(phone: phone, otp: otp),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _validateAndSend() {
    if (_phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid phone number"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _sendOTP(_phoneNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 10.0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/placeholders/forgotpass.png',
                        width: MediaQuery.of(context).size.width * 0.8,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Text(
                        "Forgot Password?",
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.bold,
                          fontSize: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Text(
                        "Don't worry, enter your phone number to reset your password.",
                        style: GoogleFonts.nunito(
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
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
                      child: ElevatedButton(
                        onPressed: _validateAndSend,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          "Send OTP via WhatsApp",
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
