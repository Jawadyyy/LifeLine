import 'package:flutter/material.dart';
import 'package:lifeline/models/user_model.dart';

/// High-contrast, glanceable medical summary built from a [UserModel].
///
/// Pure/presentational — it takes already-loaded data so it is trivial to
/// widget-test with full or missing fields. Empty/`'N/A'` values render as
/// "Not set" rather than blanks.
class MedicalIdCard extends StatelessWidget {
  final UserModel user;
  final String? primaryContactName;
  final String? primaryContactPhone;
  final VoidCallback? onCallContact;

  const MedicalIdCard({
    super.key,
    required this.user,
    this.primaryContactName,
    this.primaryContactPhone,
    this.onCallContact,
  });

  static const _ink = Color(0xFF14213D);
  static const _blood = Color(0xFFE63946);

  String _orNotSet(String? v) {
    final s = v?.trim();
    if (s == null || s.isEmpty || s.toUpperCase() == 'N/A') return 'Not set';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _bloodBlock(),
                const SizedBox(height: 18),
                _field('Allergies', _orNotSet(user.allergy),
                    icon: Icons.warning_amber_rounded, highlight: true),
                const SizedBox(height: 14),
                _field('Medical conditions', _orNotSet(user.disease),
                    icon: Icons.healing_rounded),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                        child: _vital('Age', _orNotSet(user.age))),
                    Expanded(
                        child: _vital('Height', _orNotSet(user.height))),
                    Expanded(
                        child: _vital('Weight', _orNotSet(user.weight))),
                  ],
                ),
                if (_orNotSet(user.emergencyText) != 'Not set') ...[
                  const SizedBox(height: 16),
                  _field('Emergency note', _orNotSet(user.emergencyText),
                      icon: Icons.notes_rounded),
                ],
                const SizedBox(height: 18),
                _emergencyContact(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: _blood,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.medical_information_rounded,
              color: Colors.white, size: 26),
          const SizedBox(width: 10),
          const Text('MEDICAL ID',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
          const Spacer(),
          Flexible(
            child: Text(
              _orNotSet(user.name),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bloodBlock() {
    return Row(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: _blood.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(color: _blood, width: 3),
          ),
          alignment: Alignment.center,
          child: Text(
            _orNotSet(user.bloodType) == 'Not set'
                ? '—'
                : user.bloodType,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BLOOD TYPE',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text('Show this screen to first responders',
                  style: TextStyle(color: Colors.white54, fontSize: 12.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(String label, String value,
      {required IconData icon, bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(highlight ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: highlight
            ? Border.all(color: _blood.withOpacity(0.6))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: highlight ? _blood : Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vital(String label, String value) {
    return Column(
      children: [
        Text(value,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }

  Widget _emergencyContact() {
    final name = _orNotSet(primaryContactName);
    final hasContact =
        name != 'Not set' && (primaryContactPhone?.isNotEmpty ?? false);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.contact_emergency_rounded,
              color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('EMERGENCY CONTACT',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(hasContact ? name : 'Not set',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600)),
                if (hasContact)
                  Text(primaryContactPhone!,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 13)),
              ],
            ),
          ),
          if (hasContact)
            IconButton(
              onPressed: onCallContact,
              icon: const Icon(Icons.call, color: Color(0xFF4ADE80)),
            ),
        ],
      ),
    );
  }
}
