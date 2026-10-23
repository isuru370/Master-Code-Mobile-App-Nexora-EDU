class ScanAttendanceRequestModel {
  final String code;
  final String markMethod;

  /// Set only after the server asked which class (409) and the user picked one.
  final int? scheduleId;

  ScanAttendanceRequestModel({
    required this.code,
    required this.markMethod,
    this.scheduleId,
  });

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'mark_method': markMethod,
      if (scheduleId != null) 'schedule_id': scheduleId,
    };
  }
}
