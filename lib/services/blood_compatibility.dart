/// Pure ABO/Rh blood donation compatibility.
///
/// A request post stores the blood group that is *needed* (the recipient).
/// A donor with group [donor] can fulfil a request needing [recipient] when
/// [canDonate] is true. O- is the universal donor; AB+ the universal recipient.
class BloodCompatibility {
  BloodCompatibility._();

  static const allGroups = [
    'O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'
  ];

  /// For each recipient group, the donor groups that can give to it.
  static const Map<String, Set<String>> _donorsFor = {
    'O-': {'O-'},
    'O+': {'O-', 'O+'},
    'A-': {'O-', 'A-'},
    'A+': {'O-', 'O+', 'A-', 'A+'},
    'B-': {'O-', 'B-'},
    'B+': {'O-', 'O+', 'B-', 'B+'},
    'AB-': {'O-', 'A-', 'B-', 'AB-'},
    'AB+': {'O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'},
  };

  static String _norm(String g) => g.trim().toUpperCase();

  static bool isValidGroup(String group) =>
      _donorsFor.containsKey(_norm(group));

  /// Whether [donor] blood can be given to a recipient needing [recipient].
  static bool canDonate({required String donor, required String recipient}) {
    final r = _donorsFor[_norm(recipient)];
    if (r == null) return false;
    return r.contains(_norm(donor));
  }

  /// Recipient groups a [donor] can give to (used to filter requests a donor
  /// can fulfil).
  static Set<String> canDonateTo(String donor) {
    final d = _norm(donor);
    return _donorsFor.entries
        .where((e) => e.value.contains(d))
        .map((e) => e.key)
        .toSet();
  }
}
