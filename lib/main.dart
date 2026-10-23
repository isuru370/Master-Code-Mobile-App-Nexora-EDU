import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'core/constants/api_constants.dart';
import 'core/di/injection_container.dart' as di;
import 'core/di/injection_container.dart';
import 'core/network/app_http_client.dart';
import 'features/admin/admission/presentaion/bloc/admission/admission_bloc.dart';
import 'features/admin/attendance/presentaion/bloc/attendance/attendance_bloc.dart';
import 'features/admin/class_schedule/presentaion/bloc/class_category/class_category_bloc.dart';
import 'features/admin/class_schedule/presentaion/bloc/class_schedule/class_schedule_bloc.dart';
import 'features/admin/class_schedule/presentaion/bloc/ongoing_class/ongoing_class_bloc.dart';
import 'features/admin/dashboard/presentaion/bloc/mobile_dashboard/mobile_dashboard_bloc.dart';
import 'features/admin/image_upload/presentation/bloc/image_upload/image_upload_bloc.dart';
import 'features/admin/institute_hall/presentaion/bloc/institute_hall/institute_hall_bloc.dart';
import 'features/admin/payment/presentaion/bloc/mark_payment/mark_payment_bloc.dart';
import 'features/admin/qr/presentation/bloc/read_attendance/read_attendance_bloc.dart';
import 'features/admin/qr/presentation/bloc/read_payment/read_payment_bloc.dart';
import 'features/admin/qr/presentation/bloc/read_student/read_student_bloc.dart';
import 'features/admin/qr/presentation/bloc/read_student_classes/read_student_classes_bloc.dart';
import 'features/admin/qr/presentation/bloc/read_tute/read_tute_bloc.dart';
import 'features/admin/qr/presentation/bloc/scan_attendance/scan_attendance_bloc.dart';
import 'features/admin/qr/presentation/bloc/scan_payment/scan_payment_bloc.dart';
import 'features/admin/student_card/presentaion/bloc/student_card/student_card_bloc.dart';
import 'features/admin/student_classes/presentaion/bloc/class_room/class_room_bloc.dart';
import 'features/admin/student_grade/presentation/bloc/student_grade/student_grade_bloc.dart';
import 'features/admin/student_image/presentaion/bloc/student_image/student_image_bloc.dart';
import 'features/admin/student_tute/presentation/bloc/tute/tute_bloc.dart';
import 'features/admin/students/presentaion/bloc/student_classes/student_classes_bloc.dart';
import 'features/admin/students/presentaion/bloc/students/students_bloc.dart';
import 'features/admin/today_classes/presentaion/bloc/today_classes/today_classes_bloc.dart';
import 'features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'features/teacher/classess/presentaion/bloc/teacher_classes/teacher_classes_bloc.dart';
import 'features/teacher/dashboard/presentaion/bloc/teacher_dashboard/teacher_dashboard_bloc.dart';
import 'features/teacher/profile/presentaion/bloc/teacher_profile/teacher_profile_bloc.dart';
import 'features/teacher/students/presentaion/bloc/teacher_students/teacher_students_bloc.dart';
import 'features/teacher/timetable/presentaion/bloc/teacher_timetable/teacher_timetable_bloc.dart';
import 'simple_bloc_observer.dart';

/// The whole app runs inside http.runWithClient, so every http.get / post /
/// put / patch / delete and MultipartRequest in the datasources uses
/// AppHttpClient (timeout + Accept header + session-expired handling).
Future<void> main() => http.runWithClient(_startApp, () => AppHttpClient());

Future<void> _startApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Release builds: no debugPrint output. The datasources print API
  // responses (student names, phone numbers, payments) for debugging,
  // and those must not end up in the phone's logcat.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // A release build must say which institute server it uses:
  //   flutter build apk --release --dart-define=API_BASE_URL=https://<institute>.nexorait.lk
  if (kReleaseMode && !ApiConstants.isBaseUrlConfigured) {
    runApp(const _MissingServerApp());
    return;
  }

  await initializeDateFormatting('en', null);

  // Sri Lanka Timezone
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Colombo'));

  Bloc.observer = SimpleBlocObserver();

  await di.init();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<AuthBloc>()),
        BlocProvider(create: (_) => sl<StudentsBloc>()),
        BlocProvider(create: (_) => sl<ReadPaymentBloc>()),
        BlocProvider(create: (_) => sl<MarkPaymentBloc>()),
        BlocProvider(create: (_) => sl<ReadAttendanceBloc>()),
        BlocProvider(create: (_) => sl<ScanAttendanceBloc>()),
        BlocProvider(create: (_) => sl<AttendanceBloc>()),
        BlocProvider(create: (_) => sl<ReadStudentBloc>()),
        BlocProvider(create: (_) => sl<StudentClassesBloc>()),
        BlocProvider(create: (_) => sl<StudentGradeBloc>()),
        BlocProvider(create: (_) => sl<ImageUploadBloc>()),
        BlocProvider(create: (_) => sl<MobileDashboardBloc>()),
        BlocProvider(create: (_) => sl<StudentImageBloc>()),
        BlocProvider(create: (_) => sl<TuteBloc>()),
        BlocProvider(create: (_) => sl<ReadTuteBloc>()),
        BlocProvider(create: (_) => sl<ReadStudentClassesBloc>()),
        BlocProvider(create: (_) => sl<ClassRoomBloc>()),
        BlocProvider(create: (_) => sl<TodayClassesBloc>()),
        BlocProvider(create: (_) => sl<AdmissionBloc>()),
        BlocProvider(create: (_) => sl<ClassScheduleBloc>()),
        BlocProvider(create: (_) => sl<OngoingClassBloc>()),
        BlocProvider(create: (_) => sl<ClassCategoryBloc>()),
        BlocProvider(create: (_) => sl<InstituteHallBloc>()),
        BlocProvider(create: (_) => sl<StudentCardBloc>()),
        BlocProvider(create: (_) => sl<ScanPaymentBloc>()),

        // Teacher Bloc
        BlocProvider(create: (_) => sl<TeacherDashboardBloc>()),
        BlocProvider(create: (_) => sl<TeacherProfileBloc>()),
        BlocProvider(create: (_) => sl<TeacherClassesBloc>()),
        BlocProvider(create: (_) => sl<TeacherTimetableBloc>()),
        BlocProvider(create: (_) => sl<TeacherStudentsBloc>()),
      ],
      child: const NexoraMobileApp(),
    ),
  );
}

/// Shown instead of the app when a release build was made without
/// --dart-define=API_BASE_URL (so it is never shipped pointing at a test server).
class _MissingServerApp extends StatelessWidget {
  const _MissingServerApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This build has no server address.\n\n'
              'Build it again with:\n'
              '--dart-define=API_BASE_URL=https://<institute>.nexorait.lk',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
