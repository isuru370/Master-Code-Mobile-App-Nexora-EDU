part of 'students_bloc.dart';

sealed class StudentsState extends Equatable {
  const StudentsState();

  @override
  List<Object> get props => [];
}

final class StudentsInitial extends StudentsState {}

final class StudentsLoading extends StudentsState {}

class StudentsLoaded extends StudentsState {
  final List<StudentModel> students;

  const StudentsLoaded(this.students);

  @override
  List<Object> get props => [students];
}

class StudentsCreated extends StudentsState {
  final CreateStudentResponseModel response;
  final String message;

  const StudentsCreated({required this.response, required this.message});

  @override
  List<Object> get props => [response, message];
}

final class StudentsError extends StudentsState {
  final String message;

  const StudentsError(this.message);

  @override
  List<Object> get props => [message];
}
