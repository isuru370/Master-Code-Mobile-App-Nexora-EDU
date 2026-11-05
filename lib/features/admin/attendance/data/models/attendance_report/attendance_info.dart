class AttendanceInfo {
  final int attendanceId;
  final bool isPresent;
  final String? attendedAt;

  /// qr_mobile / qr_web = card scanned, manual_* = Student ID typed
  final String? markMethod;

  /// Marked by typing the Student ID (did not bring the card)
  final bool isManual;

  AttendanceInfo({
    required this.attendanceId,
    required this.isPresent,
    this.attendedAt,
    this.markMethod,
    this.isManual = false,
  });

  factory AttendanceInfo.fromJson(Map<String, dynamic> json) {
    return AttendanceInfo(
      attendanceId: json['id'] ?? 0,
      isPresent: json['is_present'] ?? false,
      attendedAt: json['attended_at'],
      markMethod: json['mark_method']?.toString(),
      isManual: json['is_manual'] == true ||
          (json['mark_method']?.toString().startsWith('manual') ?? false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_present': isPresent,
      'attended_at': attendedAt,
      'mark_method': markMethod,
      'is_manual': isManual,
    };
  }
}