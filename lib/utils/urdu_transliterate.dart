// Best-effort Roman/Latin → Urdu-script transliteration for display of
// proper names when the app locale is Urdu.
//
// This is approximate: Urdu has no capital letters and Roman spellings map
// ambiguously to Urdu vowels, so results may not match a name's canonical
// spelling. It only runs when the user picks Urdu; the stored English name is
// never changed. Non-Latin input (already Urdu, digits, etc.) passes through.

/// Ordered digraphs — matched before single letters so "sh", "kh" … win.
const Map<String, String> _digraphs = {
  'kh': 'خ',
  'gh': 'غ',
  'ch': 'چ',
  'sh': 'ش',
  'ph': 'پھ',
  'th': 'تھ',
  'dh': 'دھ',
  'zh': 'ژ',
  'aa': 'ا',
  'ee': 'ی',
  'ii': 'ی',
  'oo': 'و',
  'uu': 'و',
  'ai': 'ے',
  'ay': 'ے',
  'ei': 'ے',
  'au': 'و',
  'aw': 'و',
  'ou': 'و',
};

const Map<String, String> _singles = {
  'a': 'ا',
  'b': 'ب',
  'c': 'ک',
  'd': 'د',
  'e': 'ی',
  'f': 'ف',
  'g': 'گ',
  'h': 'ہ',
  'i': 'ی',
  'j': 'ج',
  'k': 'ک',
  'l': 'ل',
  'm': 'م',
  'n': 'ن',
  'o': 'و',
  'p': 'پ',
  'q': 'ق',
  'r': 'ر',
  's': 'س',
  't': 'ت',
  'u': 'و',
  'v': 'و',
  'w': 'و',
  'x': 'کس',
  'y': 'ی',
  'z': 'ز',
};

/// Transliterates [input] to Urdu script, word by word. Anything without a
/// mapping (spaces, digits, punctuation, already-Urdu text) is kept as-is.
String transliterateToUrdu(String input) {
  if (input.isEmpty) return input;
  final lower = input.toLowerCase();
  final out = StringBuffer();
  var i = 0;
  while (i < lower.length) {
    // Try a two-character digraph first.
    if (i + 1 < lower.length) {
      final pair = lower.substring(i, i + 2);
      final mapped = _digraphs[pair];
      if (mapped != null) {
        out.write(mapped);
        i += 2;
        continue;
      }
    }
    final ch = lower[i];
    final single = _singles[ch];
    out.write(single ?? input[i]); // fall back to original char (keeps case)
    i += 1;
  }
  return out.toString();
}
