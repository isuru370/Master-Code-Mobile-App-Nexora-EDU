import '../../../../core/di/injection_container.dart';
import '../data/datasources/teacher_profile_remote_datasource.dart';
import '../data/repository/teacher_profile_repository_impl.dart';
import '../domain/repository/teacher_profile_repository.dart';
import '../domain/usecase/change_teacher_password.dart';
import '../domain/usecase/get_teacher_profile.dart';
import '../domain/usecase/update_teacher_profile.dart';
import '../presentaion/bloc/teacher_profile/teacher_profile_bloc.dart';

Future<void> initTeacherProfileDI() async {
  // DATA SOURCE
  sl.registerLazySingleton<TeacherProfileRemoteDataSource>(
    () => TeacherProfileRemoteDataSourceImpl(),
  );

  // REPOSITORY
  sl.registerLazySingleton<TeacherProfileRepository>(
    () => TeacherProfileRepositoryImpl(remoteDataSource: sl()),
  );

  // USECASES
  sl.registerLazySingleton(() => GetTeacherProfile(repository: sl()));
  sl.registerLazySingleton(() => UpdateTeacherProfile(repository: sl()));
  sl.registerLazySingleton(() => ChangeTeacherPassword(repository: sl()));

  // BLOC
  sl.registerFactory<TeacherProfileBloc>(
    () => TeacherProfileBloc(
      getTeacherProfile: sl(),
      updateTeacherProfile: sl(),
      changeTeacherPassword: sl(),
    ),
  );
}
