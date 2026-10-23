import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/model/scan_attendance_new/attendance_class_choice_model.dart';
import '../../../data/model/scan_attendance_new/scan_attendance_request_model.dart';
import '../../../data/model/scan_attendance_new/scan_attendance_response_model.dart';
import '../../../domain/usecases/scan_attendance_usecase.dart';
import 'package:nexorait_education_app/core/errors/error_message.dart';

part 'scan_attendance_event.dart';
part 'scan_attendance_state.dart';

class ScanAttendanceBloc
    extends Bloc<ScanAttendanceEvent, ScanAttendanceState> {
  final ScanAttendanceUsecase scanAttendanceUseCase;

  ScanAttendanceBloc({
    required this.scanAttendanceUseCase,
  }) : super(ScanAttendanceInitial()) {
    on<ScanAttendanceRequested>(
      _onScanAttendance,
    );

    on<ScanAttendanceReset>(
      (event, emit) {
        emit(ScanAttendanceInitial());
      },
    );
  }

  Future<void> _onScanAttendance(
    ScanAttendanceRequested event,
    Emitter<ScanAttendanceState> emit,
  ) async {
    emit(ScanAttendanceLoading());

    try {
      final response = await scanAttendanceUseCase(
        requestModel: ScanAttendanceRequestModel(
          code: event.code,
          markMethod: event.markMethod,
          scheduleId: event.scheduleId,
        ),
      );

      emit(
        ScanAttendanceSuccess(
          response: response,
        ),
      );
    } on ClassSelectionRequiredException catch (e) {
      emit(
        ScanAttendanceChooseClass(
          code: event.code,
          markMethod: event.markMethod,
          message: e.message,
          studentName: e.studentName,
          classes: e.classes,
        ),
      );
    } catch (e) {
      emit(
        ScanAttendanceFailure(
          message: friendlyError(e),
        ),
      );
    }
  }
}