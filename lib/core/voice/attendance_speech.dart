/// What the phone says after an attendance scan (the "tts" feature).
///
///   English voice : "K. Perera. ICT, 2027 A L."      (name, subject, grade)
///   Sinhala voice : "මේ මාසේ ගාස්තු ගෙවා ඇත." / "... ගෙවා නැත."
///   Free card     : a short beep instead of the Sinhala part.
///
/// Only text here (no sound), so it can be tested.
class AttendanceSpeech {
  AttendanceSpeech._();

  static const String paidSinhala = 'මේ මාසේ ගාස්තු ගෙවා ඇත.';
  static const String notPaidSinhala = 'මේ මාසේ ගාස්තු ගෙවා නැත.';

  /// When the phone has no Sinhala voice.
  static const String paidEnglish = 'Paid.';
  static const String notPaidEnglish = 'Not paid.';

  /// Long subject names said in short.
  static const Map<String, String> _shortSubjects = {
    'INFORMATION AND COMMUNICATION TECHNOLOGY': 'ICT',
    'INFORMATION & COMMUNICATION TECHNOLOGY': 'ICT',
    'BUSINESS AND ACCOUNTING STUDIES': 'Business and Accounting',
    'SCIENCE FOR TECHNOLOGY': 'S F T',
    'ENGINEERING TECHNOLOGY': 'E T',
    'BIO SYSTEM TECHNOLOGY': 'B S T',
  };

  /// "K. Perera. ICT, 2027 A L." (with "Already marked." first when it was).
  static String english({
    required String name,
    required String subject,
    required String grade,
    bool alreadyMarked = false,
  }) {
    final parts = <String>[];

    if (alreadyMarked) parts.add('Already marked.');

    final cleanName = _titleCase(_clean(name));
    if (cleanName.isNotEmpty) parts.add(cleanName.endsWith('.') ? cleanName : '$cleanName.');

    final classPart = [subjectText(subject), gradeText(grade)]
        .where((p) => p.isNotEmpty)
        .join(', ');
    if (classPart.isNotEmpty) parts.add('$classPart.');

    return parts.join(' ');
  }

  /// Sinhala (or English) words for this month's fee; null = free card
  /// (beep) or nothing to say.
  ///
  /// status: paid | partial | unpaid | free (partial = not fully paid).
  static String? payment(String? status, {required bool sinhala}) {
    switch ((status ?? '').toLowerCase()) {
      case 'paid':
        return sinhala ? paidSinhala : paidEnglish;
      case 'partial':
      case 'unpaid':
        return sinhala ? notPaidSinhala : notPaidEnglish;
      default:
        return null;
    }
  }

  static bool isFree(String? status) => (status ?? '').toLowerCase() == 'free';

  /// "INFORMATION AND COMMUNICATION TECHNOLOGY" -> "ICT", "ENGLISH" -> "English".
  static String subjectText(String subject) {
    final s = _clean(subject);
    if (s.isEmpty) return '';

    final short = _shortSubjects[s.toUpperCase()];
    if (short != null) return short;

    return _titleCase(s);
  }

  /// "10" -> "Grade 10", "2027 A/L" -> "2027 A L", "ALL" -> "All grades".
  static String gradeText(String grade) {
    var g = _clean(grade);
    if (g.isEmpty) return '';

    if (RegExp(r'^\d{1,2}$').hasMatch(g)) return 'Grade $g';
    if (g.toUpperCase() == 'ALL') return 'All grades';

    // A/L, O/L read letter by letter, not "A slash L"
    g = g.replaceAllMapped(
      RegExp(r'\b([AO])\s*/\s*L\b', caseSensitive: false),
      (m) => '${m[1]!.toUpperCase()} L',
    );

    return _titleCase(g);
  }

  static String _clean(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Upper-case words of 4+ letters become "Word" (else some voices spell
  /// them); short ones (A L, ICT) stay as they are.
  static String _titleCase(String value) {
    return value.split(' ').map((w) {
      // only plain words: "K.A." and "2027" stay as they are
      if (RegExp(r'^[A-Z]{4,}[.,]?$').hasMatch(w)) {
        return w[0] + w.substring(1).toLowerCase();
      }
      return w;
    }).join(' ');
  }
}
