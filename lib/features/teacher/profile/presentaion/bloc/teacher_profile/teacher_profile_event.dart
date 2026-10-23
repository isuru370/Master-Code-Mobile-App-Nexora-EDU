part of 'teacher_profile_bloc.dart';

sealed class TeacherProfileEvent extends Equatable {
  const TeacherProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Load the logged-in teacher's profile from the server.
final class FetchTeacherProfile extends TeacherProfileEvent {
  const FetchTeacherProfile();
}

/// Save changed profile fields (PUT /v1/teacher/profile).
final class TeacherProfileUpdateRequested extends TeacherProfileEvent {
  final Map<String, dynamic> data;

  const TeacherProfileUpdateRequested(this.data);

  @override
  List<Object?> get props => [data];
}

/// Change the teacher's login password.
final class TeacherPasswordChangeRequested extends TeacherProfileEvent {
  final String currentPassword;
  final String newPassword;
  final String newPasswordConfirmation;

  const TeacherPasswordChangeRequested({
    required this.currentPassword,
    required this.newPassword,
    required this.newPasswordConfirmation,
  });

  @override
  List<Object?> get props => [currentPassword, newPassword, newPasswordConfirmation];
}
