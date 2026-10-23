part of 'scan_attendance_bloc.dart';

sealed class ScanAttendanceState extends Equatable {
  const ScanAttendanceState();

  @override
  List<Object?> get props => [];
}

class ScanAttendanceInitial extends ScanAttendanceState {
  const ScanAttendanceInitial();
}

class ScanAttendanceLoading extends ScanAttendanceState {
  const ScanAttendanceLoading();
}

class ScanAttendanceSuccess extends ScanAttendanceState {
  final ScanAttendanceResponseModel response;

  const ScanAttendanceSuccess({
    required this.response,
  });

  @override
  List<Object?> get props => [response];
}

/// More than one class is open for this student now; nothing was marked.
/// Show [classes] and send ScanAttendanceRequested again with the picked
/// scheduleId.
class ScanAttendanceChooseClass extends ScanAttendanceState {
  final String code;
  final String markMethod;
  final String message;
  final String studentName;
  final List<AttendanceClassChoiceModel> classes;

  const ScanAttendanceChooseClass({
    required this.code,
    required this.markMethod,
    required this.message,
    required this.studentName,
    required this.classes,
  });

  @override
  List<Object?> get props => [code, markMethod, message, studentName, classes];
}

class ScanAttendanceFailure extends ScanAttendanceState {
  final String message;

  const ScanAttendanceFailure({
    required this.message,
  });

  @override
  List<Object?> get props => [message];
}