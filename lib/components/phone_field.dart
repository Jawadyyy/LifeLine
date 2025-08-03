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
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
    );

    return IntlPhoneField(
      controller: _phoneController,
      focusNode: _phoneFocusNode,
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
          child: SizedBox(
            width: 24,
            child: Image.asset(
              'assets/images/icons/phone.png',
              width: 24,
              height: 24,
            ),
          ),
        ),
        hintText: 'Phone Number',
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
        border: border,
      ),
      dropdownIconPosition: IconPosition.trailing,
      dropdownDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.transparent,
      ),
      flagsButtonPadding: const EdgeInsets.only(left: 10),
      initialCountryCode: 'US',
      onChanged: (phone) {
        widget.onPhoneChanged(phone.completeNumber);
      },
      onCountryChanged: (country) {},
    );
  }
}
