import 'package:flutter/material.dart';
import 'package:lifeline/constants/app_design.dart';
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

  String _orNotSet(String? v) {
    final s = v?.trim();
    if (s == null || s.isEmpty || s.toUpperCase() == 'N/A') return 'Not set';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LL.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF0E1DA)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF141828).withOpacity(0.10),
            blurRadius: 44,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Top accent bar.
            Container(
              height: 5,
              decoration: const BoxDecoration(gradient: LL.grad),
            ),
            // Soft corner glow.
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [LL.orange.withOpacity(0.12), Colors.transparent],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 27, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _cardHead(),
                  const SizedBox(height: 18),
                  _nameAndBlood(),
                  const SizedBox(height: 18),
                  _allergyHighlight(),
                  const SizedBox(height: 10),
                  _grid(),
                  const SizedBox(height: 10),
                  _emergencyContact(),
                  if (_orNotSet(user.emergencyText) != 'Not set') ...[
                    const SizedBox(height: 10),
                    _noteBlock(),
                  ],
                  const SizedBox(height: 18),
                  _scanStrip(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardHead() {
    return Row(
      children: [
        const Icon(Icons.medical_information_outlined,
            color: LL.orange, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text('EMERGENCY MEDICAL ID',
              style: LL.body(11,
                  weight: FontWeight.w800,
                  color: LL.orange,
                  letterSpacing: 1.8)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: LL.soft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('VERIFIED',
              style: LL.body(10,
                  weight: FontWeight.w700,
                  color: LL.orange,
                  letterSpacing: 1.4)),
        ),
      ],
    );
  }

  Widget _nameAndBlood() {
    final age = _orNotSet(user.age);
    final sub = age == 'Not set' ? 'Age not set' : '$age years';
    final blood = _orNotSet(user.bloodType) == 'Not set' ? '—' : user.bloodType;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_orNotSet(user.name),
                  style: LL.display(25, height: 1.1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(sub, style: LL.body(13, color: LL.muted)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            Text(blood,
                style: LL.display(40,
                    weight: FontWeight.w800, color: LL.orange, height: 0.9)),
            const SizedBox(height: 3),
            Text('BLOOD TYPE',
                style: LL.body(10,
                    weight: FontWeight.w700,
                    color: LL.orangeText,
                    letterSpacing: 1.4)),
          ],
        ),
      ],
    );
  }

  Widget _allergyHighlight() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: LL.soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LL.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: LL.orange, size: 15),
              const SizedBox(width: 7),
              Text('CRITICAL ALLERGY',
                  style: LL.body(10.5,
                      weight: FontWeight.w800,
                      color: LL.orange,
                      letterSpacing: 1.4)),
            ],
          ),
          const SizedBox(height: 5),
          Text(_orNotSet(user.allergy),
              style: LL.body(17, weight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _grid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _cell('CONDITION', _orNotSet(user.disease))),
            const SizedBox(width: 10),
            Expanded(child: _cell('BMI', _orNotSet(user.bmi))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _cell('HEIGHT', _orNotSet(user.height))),
            const SizedBox(width: 10),
            Expanded(child: _cell('WEIGHT', _orNotSet(user.weight))),
          ],
        ),
      ],
    );
  }

  Widget _cell(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: LL.softTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: LL.body(10,
                  weight: FontWeight.w700,
                  color: LL.orangeText,
                  letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text(value,
              style: LL.body(15, weight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _noteBlock() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: LL.softTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EMERGENCY NOTE',
              style: LL.body(10,
                  weight: FontWeight.w700,
                  color: LL.orangeText,
                  letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text(_orNotSet(user.emergencyText),
              style: LL.body(14.5, weight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _emergencyContact() {
    final name = _orNotSet(primaryContactName);
    final hasContact =
        name != 'Not set' && (primaryContactPhone?.isNotEmpty ?? false);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: LL.softTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EMERGENCY CONTACT',
                    style: LL.body(10,
                        weight: FontWeight.w700,
                        color: LL.orangeText,
                        letterSpacing: 1.2)),
                const SizedBox(height: 3),
                Text(hasContact ? name : 'Not set',
                    style: LL.body(16, weight: FontWeight.w700)),
                if (hasContact)
                  Text(primaryContactPhone!,
                      style: LL.body(12.5, color: LL.muted)),
              ],
            ),
          ),
          if (hasContact)
            GestureDetector(
              onTap: onCallContact,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: LL.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: LL.green.withOpacity(0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.call, color: Colors.white, size: 22),
              ),
            ),
        ],
      ),
    );
  }

  Widget _scanStrip() {
    // Decorative barcode — deterministic bar heights for a stable render.
    const heights = [1.0, .7, 1.0, .55, 1.0, .8, 1.0, .6, 1.0, .75, 1.0, .5,
        1.0, .85, 1.0];
    const widths = [2.0, 3, 1.5, 4, 1.5, 2, 3, 1.5, 2, 4, 1.5, 2, 3, 1.5, 2];
    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF0E1DA))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 30,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < heights.length; i++) ...[
                  Container(
                    width: widths[i].toDouble(),
                    height: 30 * heights[i],
                    color: LL.ink,
                  ),
                  const SizedBox(width: 1.5),
                ],
              ],
            ),
          ),
          Text('SCAN AT ER',
              style: LL.body(10,
                  weight: FontWeight.w700,
                  color: LL.orange,
                  letterSpacing: 1)),
        ],
      ),
    );
  }
}
