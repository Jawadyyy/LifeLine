import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lifeline/constants/app_colors.dart';

/// A cancellable 5-second countdown shown before an SOS alert fires.
///
/// Returns `true` if the countdown completed (send the alert) or `false` if
/// the user cancelled. Prevents accidental triggers.
class SosCountdownDialog extends StatefulWidget {
  final String emergencyType;
  final int seconds;

  const SosCountdownDialog({
    super.key,
    required this.emergencyType,
    this.seconds = 5,
  });

  /// Shows the dialog and resolves to whether the alert should be sent.
  static Future<bool> show(BuildContext context, String emergencyType) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SosCountdownDialog(emergencyType: emergencyType),
    );
    return result ?? false;
  }

  @override
  State<SosCountdownDialog> createState() => _SosCountdownDialogState();
}

class _SosCountdownDialogState extends State<SosCountdownDialog> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) {
        timer.cancel();
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: CircularProgressIndicator(
                    value: _remaining / widget.seconds,
                    strokeWidth: 6,
                    backgroundColor: AppColors.error.withOpacity(0.15),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.error),
                  ),
                ),
                Text(
                  '$_remaining',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              loc.sendingType(widget.emergencyType),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.sosLocationShared,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  loc.cancel.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                loc.sendNow,
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
