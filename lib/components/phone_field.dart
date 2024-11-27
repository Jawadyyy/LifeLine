// phone_field.dart
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:google_fonts/google_fonts.dart';

class PhoneForm extends StatefulWidget {
  final Function(String) onPhoneChanged;

  const PhoneForm({super.key, required this.onPhoneChanged});

  @override
  // ignore: library_private_types_in_public_api
  _PhoneFormState createState() => _PhoneFormState();
}

class _PhoneFormState extends State<PhoneForm> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return IntlPhoneField(
      controller: _phoneController,
      focusNode: _phoneFocusNode,
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Image.asset(
            'assets/images/icons/phone.png',
            width: 24,
            height: 24,
          ),
        ),
        hintText: 'Phone Number',
        hintStyle: GoogleFonts.nunito(),
        border: const UnderlineInputBorder(),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF1565C0), width: 2),
        ),
      ),
      initialCountryCode: 'US',
      onChanged: (phone) {
        widget.onPhoneChanged(phone.completeNumber);
      },
      onCountryChanged: (country) {
        // ignore: avoid_print
        print('Country changed to: ${country.name}');
      },
    );
  }
}
