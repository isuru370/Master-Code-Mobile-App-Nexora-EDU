/// One class the student could be marked for, when the server answers 409
/// "choose the class" (e.g. A 4:30-6:00 PM and B 6:00-8:00 PM at 5:30 PM).
class AttendanceClassChoiceModel {
  final int scheduleId;
  final String className;
  final String category;
  final String teacher;
  final String hall;
  final String startTime;
  final String endTime;
  final bool isStarted;
  final bool alreadyMarked;

  const AttendanceClassChoiceModel({
    required this.scheduleId,
    required this.className,
    required this.category,
    required this.teacher,
    required this.hall,
    required this.startTime,
    required this.endTime,
    required this.isStarted,
    required this.alreadyMarked,
  });

  factory AttendanceClassChoiceModel.fromJson(Map<String, dynamic> json) {
    final info = json['class'] is Map<String, dynamic>
        ? json['class'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return AttendanceClassChoiceModel(
      scheduleId: int.tryParse('${json['schedule_id'] ?? json['id']}') ?? 0,
      className: (info['class_name'] ?? '').toString(),
      category: (info['category'] ?? '').toString(),
      teacher: (info['teacher'] ?? '').toString(),
      hall: (json['hall'] ?? '').toString(),
      startTime: (json['start_time'] ?? '').toString(),
      endTime: (json['end_time'] ?? '').toString(),
      isStarted: json['is_started'] == true,
      alreadyMarked: json['already_marked'] == true,
    );
  }
}

/// Thrown by the datasource when the scan needs the user to pick a class.
class ClassSelectionRequiredException implements Exception {
  final String message;
  final String studentName;
  final String studentCode;
  final List<AttendanceClassChoiceModel> classes;

  const ClassSelectionRequiredException({
    required this.message,
    required this.studentName,
    required this.studentCode,
    required this.classes,
  });

  @override
  String toString() => message;
}
