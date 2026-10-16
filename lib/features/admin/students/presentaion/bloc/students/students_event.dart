part of 'students_bloc.dart';

sealed class StudentsEvent extends Equatable {
  const StudentsEvent();

  @override
  List<Object?> get props => [];
}

class FetchStudents extends StudentsEvent {
  final String token;

  const FetchStudents(this.token);

  @override
  List<Object> get props => [token];
}

final class CreateStudentEvent extends StudentsEvent {
  final StudentModel student;

  const CreateStudentEvent({required this.student});

  @override
  List<Object> get props => [student];
}

final class CreateNewStudentEvent extends StudentsEvent {
  final StudentModel student;

  const CreateNewStudentEvent({required this.student});

  @override
  List<Object> get props => [student];
}
