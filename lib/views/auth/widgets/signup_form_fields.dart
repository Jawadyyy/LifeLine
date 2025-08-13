import 'package:flutter/material.dart';
import 'package:lifeline/components/custom_text_field.dart';

class SignupFormFields extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final Widget nameIcon;
  final Widget emailIcon;
  final Widget passwordIcon;
  final Widget eyeIcon;
  final Widget eyeSlashIcon;
  final bool isPasswordVisible;
  final VoidCallback onTogglePassword;

  const SignupFormFields({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.nameIcon,
    required this.emailIcon,
    required this.passwordIcon,
    required this.eyeIcon,
    required this.eyeSlashIcon,
    required this.isPasswordVisible,
    required this.onTogglePassword,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: nameController,
          hintText: "Full Name",
          prefixIcon: nameIcon,
        ),
        const SizedBox(height: 20),
        CustomTextField(
          controller: emailController,
          hintText: "Email Address",
          prefixIcon: emailIcon,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        CustomTextField(
          controller: passwordController,
          hintText: "Password",
          prefixIcon: passwordIcon,
          obscureText: !isPasswordVisible,
          suffixIcon: isPasswordVisible ? eyeSlashIcon : eyeIcon,
          onSuffixTap: onTogglePassword,
        ),
      ],
    );
  }
}
