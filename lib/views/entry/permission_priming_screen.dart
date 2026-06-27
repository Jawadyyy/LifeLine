import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First-run rationale shown before the OS asks for location & contacts.
/// Explaining why up front reduces denials (and Play sensitive-perm flags).
class PermissionPrimingScreen extends StatefulWidget {
  const PermissionPrimingScreen({super.key});

  static const _prefKey = 'perm_priming_shown';

  /// Shows the priming screen once per install. Safe to call on every app
  /// start — it returns immediately if already shown.
  static Future<void> showIfFirstRun(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKey) == true) return;
    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PermissionPrimingScreen(),
      ),
    );
    await prefs.setBool(_prefKey, true);
  }

  @override
  State<PermissionPrimingScreen> createState() =>
      _PermissionPrimingScreenState();
}

class _PermissionPrimingScreenState extends State<PermissionPrimingScreen> {
  bool _requesting = false;

  Future<void> _continue() async {
    setState(() => _requesting = true);
    // Trigger the real OS prompts now that the user understands why.
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      await FlutterContacts.requestPermission(readonly: true);
      // Android 13+ POST_NOTIFICATIONS / iOS alert permission for SOS pushes.
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {
      // Permission flow errors are non-fatal — the user can grant later.
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'Before you start',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'LifeLine needs a couple of permissions to keep you safe in an '
                'emergency.',
                style: TextStyle(fontSize: 14.5, color: AppColors.textGrey),
              ),
              const SizedBox(height: 32),
              _rationale(
                icon: Icons.location_on_outlined,
                title: 'Location',
                body:
                    'So we can share your exact position with your emergency '
                    'contacts and find help nearby.',
              ),
              const SizedBox(height: 24),
              _rationale(
                icon: Icons.contacts_outlined,
                title: 'Contacts',
                body:
                    'So you can quickly pick the people who should be alerted '
                    'when you fire an SOS.',
              ),
              const SizedBox(height: 24),
              _rationale(
                icon: Icons.notifications_active_outlined,
                title: 'Notifications',
                body:
                    'So you get instant alerts when a contact fires an SOS, '
                    'marks themselves safe, or accepts your blood request.',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _requesting ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _requesting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textTertiary,
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed:
                      _requesting ? null : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Maybe later',
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rationale({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textGrey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
