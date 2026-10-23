import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/model/teacher_profile_model.dart';
import '../../../domain/usecase/change_teacher_password.dart';
import '../../../domain/usecase/get_teacher_profile.dart';
import '../../../domain/usecase/update_teacher_profile.dart';

part 'teacher_profile_event.dart';
part 'teacher_profile_state.dart';

class TeacherProfileBloc
    extends Bloc<TeacherProfileEvent, TeacherProfileState> {
  final GetTeacherProfile getTeacherProfile;
  final UpdateTeacherProfile updateTeacherProfile;
  final ChangeTeacherPassword changeTeacherPassword;

  TeacherProfileBloc({
    required this.getTeacherProfile,
    required this.updateTeacherProfile,
    required this.changeTeacherPassword,
  }) : super(TeacherProfileInitial()) {
    on<FetchTeacherProfile>(_onFetch);
    on<TeacherProfileUpdateRequested>(_onUpdate);
    on<TeacherPasswordChangeRequested>(_onChangePassword);
  }

  /// The profile currently on screen, whatever the state.
  TeacherProfileModel? get _current => switch (state) {
        TeacherProfileLoaded(:final profile) => profile,
        TeacherProfileUpdating(:final profile) => profile,
        TeacherProfileUpdated(:final profile) => profile,
        TeacherPasswordChanging(:final profile) => profile,
        TeacherPasswordChanged(:final profile) => profile,
        TeacherProfileError(:final profile) => profile,
        _ => null,
      };

  Future<void> _onFetch(
    FetchTeacherProfile event,
    Emitter<TeacherProfileState> emit,
  ) async {
    emit(TeacherProfileLoading());

    try {
      emit(TeacherProfileLoaded(profile: await getTeacherProfile()));
    } catch (e) {
      emit(TeacherProfileError(message: _clean(e)));
    }
  }

  Future<void> _onUpdate(
    TeacherProfileUpdateRequested event,
    Emitter<TeacherProfileState> emit,
  ) async {
    final current = _current;
    if (current == null) return;

    emit(TeacherProfileUpdating(profile: current));

    try {
      final updated = await updateTeacherProfile(data: event.data);
      emit(TeacherProfileUpdated(profile: updated));
    } catch (e) {
      emit(TeacherProfileError(message: _clean(e), profile: current));
    }
  }

  Future<void> _onChangePassword(
    TeacherPasswordChangeRequested event,
    Emitter<TeacherProfileState> emit,
  ) async {
    final current = _current;

    emit(TeacherPasswordChanging(profile: current));

    try {
      await changeTeacherPassword(
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
        newPasswordConfirmation: event.newPasswordConfirmation,
      );

      emit(TeacherPasswordChanged(profile: current));
    } catch (e) {
      emit(TeacherProfileError(message: _clean(e), profile: current));
    }
  }

  String _clean(Object e) {
    final text = e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), '').trim();
    return text.isEmpty ? 'Something went wrong. Please try again.' : text;
  }
}
