part of 'scan_attendance_bloc.dart';

sealed class ScanAttendanceEvent extends Equatable {
  const ScanAttendanceEvent();

  @override
  List<Object?> get props => [];
}

class ScanAttendanceRequested extends ScanAttendanceEvent {
  final String code;
  final String markMethod;

  /// The class the user picked after a "choose the class" answer.
  final int? scheduleId;

  const ScanAttendanceRequested({
    required this.code,
    this.markMethod = 'qr_mobile',
    this.scheduleId,
  });

  @override
  List<Object?> get props => [
        code,
        markMethod,
        scheduleId,
      ];
}

class ScanAttendanceReset extends ScanAttendanceEvent {
  const ScanAttendanceReset();
}