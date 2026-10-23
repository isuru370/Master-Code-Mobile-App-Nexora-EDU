part of 'teacher_profile_bloc.dart';

sealed class TeacherProfileState extends Equatable {
  const TeacherProfileState();

  @override
  List<Object?> get props => [];
}

final class TeacherProfileInitial extends TeacherProfileState {}

final class TeacherProfileLoading extends TeacherProfileState {}

final class TeacherProfileLoaded extends TeacherProfileState {
  final TeacherProfileModel profile;

  const TeacherProfileLoaded({
    required this.profile,
  });

  @override
  List<Object?> get props => [profile];
}

final class TeacherProfileUpdating extends TeacherProfileState {
  final TeacherProfileModel profile;

  const TeacherProfileUpdating({
    required this.profile,
  });

  @override
  List<Object?> get props => [profile];
}

final class TeacherProfileUpdated extends TeacherProfileState {
  final TeacherProfileModel profile;

  const TeacherProfileUpdated({
    required this.profile,
  });

  @override
  List<Object?> get props => [profile];
}

final class TeacherPasswordChanging extends TeacherProfileState {
  final TeacherProfileModel? profile;

  const TeacherPasswordChanging({
    this.profile,
  });

  @override
  List<Object?> get props => [profile];
}

final class TeacherPasswordChanged extends TeacherProfileState {
  final TeacherProfileModel? profile;

  const TeacherPasswordChanged({
    this.profile,
  });

  @override
  List<Object?> get props => [profile];
}

final class TeacherProfileError extends TeacherProfileState {
  final String message;

  /// The profile shown before the error (null when loading failed).
  final TeacherProfileModel? profile;

  const TeacherProfileError({
    required this.message,
    this.profile,
  });

  @override
  List<Object?> get props => [message, profile];
}