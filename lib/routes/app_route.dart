import 'package:flutter/material.dart';
import 'package:nexorait_education_app/features/admin/class_schedule/presentaion/page/ongoing_class_page.dart';
import 'package:nexorait_education_app/features/admin/student_classes/presentaion/pages/create_student_classes.dart';
import 'package:nexorait_education_app/features/admin/students/presentaion/pages/create_student_page.dart';
import 'package:nexorait_education_app/features/admin/students/presentaion/pages/student_list_page.dart';
import 'package:nexorait_education_app/features/admin/today_classes/presentaion/page/today_classes_page.dart';

import '../features/admin/admission/presentaion/page/admission_payment_page.dart';
import '../features/admin/attendance/presentaion/pages/attendance_history_page.dart';
import '../features/admin/attendance/presentaion/pages/attendance_page.dart';
import '../features/admin/attendance/presentaion/pages/attendance_page_new.dart';
import '../features/admin/attendance/presentaion/pages/attendance_report_page.dart';
import '../features/admin/attendance/presentaion/pages/attendance_schedule_page.dart';
import '../features/admin/courses/presentation/pages/course_attendance_page.dart';
import '../features/admin/courses/presentation/pages/course_payment_page.dart';
import '../features/admin/dashboard/presentaion/pages/dashboard_page.dart';
import '../features/admin/image_upload/presentation/pages/camera_screen_page.dart';
import '../features/admin/image_upload/presentation/pages/student_image_capture_page.dart';
import '../features/admin/payment/presentaion/pages/payment_history_view_page.dart';
import '../features/admin/payment/presentaion/pages/payment_page.dart';
import '../features/admin/payment/presentaion/pages/today_payment_page.dart';
import '../features/admin/printer/presentaion/page/print_test_page.dart';
import '../features/admin/qr/data/model/read_attendance/read_attendance_data_model.dart';
import '../features/admin/qr/data/model/read_student_classes/read_student_classes_response_model.dart';
import '../features/admin/qr/data/model/read_tute/read_tute_response_model.dart';
import '../features/admin/qr/data/model/scan_attendance_new/scan_attendance_response_model.dart';
import '../features/admin/qr/presentation/pages/attendance_qr_scanner_page.dart';
import '../features/admin/qr/presentation/pages/qr_scanner_page.dart';
import '../features/admin/qr/presentation/pages/scan_payment_page.dart';
import '../features/admin/student_card/data/model/assignment/assignment_search_student_response_model.dart';
import '../features/admin/student_card/presentaion/page/re_assign_card_page.dart';
import '../features/admin/student_card/presentaion/page/register_details_page.dart';
import '../features/admin/student_card/presentaion/page/scan_student_card_page.dart';
import '../features/admin/student_card/presentaion/page/student_card_assignment_page.dart';
import '../features/admin/student_image/presentaion/pages/student_image_page.dart';
import '../features/admin/student_tute/presentation/pages/create_tute_page.dart';
import '../features/admin/student_tute/presentation/pages/tute_view_page.dart';
import '../features/admin/students/presentaion/pages/create_new_student_page.dart';
import '../features/auth/presentation/pages/signin_page.dart';
import '../features/splash_screen.dart';
import '../features/teacher/dashboard/presentaion/pages/teacher_dashboard_page.dart';

class AppRoutes {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    // AuthBloc comes from the MultiBlocProvider in main.dart (one for the
    // whole app). It used to be created here on every navigation and was
    // never closed.
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case '/signup':
      case '/signin':
        return MaterialPageRoute(builder: (_) => const SigninPage());

      case '/dashboard':
        return MaterialPageRoute(
          builder: (_) => DashboardPage(),
        );
      case '/teacher-dashboard':
        return MaterialPageRoute(
          builder: (_) => TeacherDashboardPage(),
        );

      // Courses (only shown when the institute has the "courses" feature)
      case '/course-attendance':
        return MaterialPageRoute(builder: (_) => const CourseAttendancePage());
      case '/course-payment':
        return MaterialPageRoute(builder: (_) => const CoursePaymentPage());

      case '/print_test_screen':
        return MaterialPageRoute(builder: (_) => PrintTestPage());

      case '/students':
        return MaterialPageRoute(builder: (_) => StudentListPage());
      case '/add-student-class':
        final response = settings.arguments as ReadStudentClassesResponseModel;

        return MaterialPageRoute(
          builder: (_) =>
              CreateStudentClasses(readStudentClassesState: response),
        );
      case '/create_student':
        return MaterialPageRoute(builder: (_) => CreateStudentPage());
      case '/register-student':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => CreateNewStudentPage(
            qrCode: args['qrCode'],
            cardBranchId: args['cardBranchId'] as int?,
            cardBranchName: args['cardBranchName'] as String?,
          ),
        );
      case '/register-details':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => RegisterDetailsPage(
            qrCode: args['qrCode'],
            studentCardLoaded: args['response'],
          ),
        );
      case '/qr-scan':
        final args = settings.arguments as Map<String, dynamic>;

        return MaterialPageRoute(
          settings: settings,
          builder: (_) => QrScannerPage(
            scanType: args['type'], // required
            studentClassId: args['student_class_id'],
            classCategoryFeeId: args['class_category_fee_id'],
            classScheduleId: args['class_schedule_id'],
          ),
        );

      case '/qr-scan-student-card':
        final args = settings.arguments as Map<String, dynamic>;

        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ScanStudentCardPage(
            scanStudentCard: args['type'], // required
          ),
        );

      case '/student-card-assignment':
        final response =
            settings.arguments as AssignmentSearchStudentResponseModel;

        return MaterialPageRoute(
          settings: settings,
          builder: (_) => StudentCardAssignmentPage(response: response),
        );

      case '/re-assign':
        final args = settings.arguments as Map<String, dynamic>;

        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ReAssignCardPage(oldQrCode: args['oldQrCode']),
        );

      case '/capture-image':
        final args = settings.arguments as Map<String, dynamic>;

        return MaterialPageRoute(
          settings: settings,
          builder: (_) =>
              CameraScreenPage(studentId: args['student-id'] as String),
        );

      case '/today-class':
        return MaterialPageRoute(builder: (_) => TodayClassesPage());

      case '/class_ongoing':
        return MaterialPageRoute(builder: (_) => OngoingClassPage());

      case '/attendance-scan':
        return MaterialPageRoute(builder: (_) => AttendanceQrScannerPage());

      case '/attendance-details':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => AttendancePage(
            classScheduleId: args['class_schedule_id'],
            attendanceData: args['attendanceData'] as ReadAttendanceDataModel,
            markMethod: args['mark_method'] as String?,
          ),
        );
      case '/attendance-details-new':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => AttendancePageNew(
            attendanceData:
                args['attendanceData'] as ScanAttendanceResponseModel,
            markMethod: args['mark_method'] as String?,
          ),
        );
      case '/attendance_schedule':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => AttendanceSchedulePage(
            studentClassId: args['student_class_id'],
            classCategoryFeeId: args['class_category_fee_id'],
            className: args['class_name'],
            categoryName: args['category_name'],
          ),
        );

      case '/attendance_report':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => AttendanceReportPage(scheduleId: args['schedule_id']),
        );
      case '/attendance-history':
        final args = settings.arguments as Map<String, dynamic>; // cast as Map

        return MaterialPageRoute(
          builder: (_) => AttendanceHistoryPage(
            studentId: args['student_id'],
            enrollmentId: args['enrollment_id'],
          ),
        );

      case '/image_capture':
        return MaterialPageRoute(
          builder: (_) => StudentImageCapturePage(
            registered:
                (settings.arguments as Map<String, dynamic>)['registered']
                    as bool? ??
                false,
          ),
        );
      case '/payment-scan':
        return MaterialPageRoute(builder: (_) => ScanPaymentPage());

      case '/payment-details':
        final args = settings.arguments as Map<String, dynamic>; // cast as Map

        return MaterialPageRoute(
          builder: (_) => PaymentPage(
            paymentResponse: args['paymentState'], // pass the loaded state
            markMethod: args['mark_method'] as String?,
          ),
        );
      case '/today-payment':
        return MaterialPageRoute(builder: (_) => TodayPaymentPage());
      case '/admission-payment':
        return MaterialPageRoute(builder: (_) => AdmissionPaymentPage());
      case '/student-tute-screen':
        final response = settings.arguments as ReadTuteResponseModel;

        return MaterialPageRoute(
          builder: (_) => CreateTutePage(readTuteResponse: response),
        );
      case '/tute':
        final args = settings.arguments as Map<String, dynamic>; // cast as Map
        return MaterialPageRoute(
          builder: (_) => TuteViewPage(
            studentId: args['student_id'], // pass the studentId
            enrollmentId:
                args['enrollment_id'], // pass the classCategoryStudentClassId
          ),
        );
      case '/payment-history':
        final args = settings.arguments as Map<String, dynamic>; // cast as Map

        return MaterialPageRoute(
          builder: (_) => PaymentHistoryViewPage(
            studentId: args['student_id'],
            enrollmentId: args['enrollment_id'],
          ),
        );
      case '/student_image_page':
        return MaterialPageRoute(builder: (_) => StudentImagePage());
      // case '/user-profile':
      //   final args = settings.arguments as Map<String, dynamic>;

      //   return MaterialPageRoute(
      //     builder: (_) =>
      //         UserProfilePage(token: args['token'], user: args['user_model']),
      //   );
      default:
        return MaterialPageRoute(builder: (_) => const SigninPage());
    }
  }
}
