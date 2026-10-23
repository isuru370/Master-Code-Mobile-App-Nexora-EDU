/// Models for the course screens (GET/POST /api/courses/...).
/// See docs/COURSES_API.md in the backend.
library;

double _num(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _str(dynamic value) => value?.toString() ?? '';

String? _strOrNull(dynamic value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};

List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value.whereType<Map<String, dynamic>>().toList()
    : <Map<String, dynamic>>[];

/* -------------------------------------------------------------------------- */
/* Student                                                                     */
/* -------------------------------------------------------------------------- */

class CourseStudent {
  final int id;
  final String customId;
  final String name;
  final String? mobile;
  final String? guardianMobile;

  const CourseStudent({
    required this.id,
    required this.customId,
    required this.name,
    this.mobile,
    this.guardianMobile,
  });

  factory CourseStudent.fromJson(Map<String, dynamic> json) => CourseStudent(
        id: _int(json['id']),
        customId: _str(json['custom_id']),
        name: _str(json['initial_name']),
        mobile: _strOrNull(json['mobile']),
        guardianMobile: _strOrNull(json['guardian_mobile']),
      );
}

/* -------------------------------------------------------------------------- */
/* Course                                                                      */
/* -------------------------------------------------------------------------- */

class CourseItem {
  final int id;
  final String code;
  final String name;
  final double fullFee;
  final double oneTimeFee;
  final int installmentCount;
  final double installmentAmount;
  final String startDate;
  final String endDate;
  final String schedule;

  const CourseItem({
    required this.id,
    required this.code,
    required this.name,
    required this.fullFee,
    required this.oneTimeFee,
    required this.installmentCount,
    required this.installmentAmount,
    required this.startDate,
    required this.endDate,
    required this.schedule,
  });

  factory CourseItem.fromJson(Map<String, dynamic> json) => CourseItem(
        id: _int(json['id']),
        code: _str(json['code']),
        name: _str(json['name']),
        fullFee: _num(json['full_fee']),
        oneTimeFee: _num(json['one_time_fee']),
        installmentCount: _int(json['installment_count']),
        installmentAmount: _num(json['installment_amount']),
        startDate: _str(json['start_date']),
        endDate: _str(json['end_date']),
        schedule: _str(json['schedule']),
      );
}

/* -------------------------------------------------------------------------- */
/* Fees / enrollment                                                           */
/* -------------------------------------------------------------------------- */

class CourseInstallment {
  final int number;
  final double amount;
  final double paid;
  final double remaining;
  final String dueDate;

  /// paid / partly_paid / overdue / due
  final String status;

  const CourseInstallment({
    required this.number,
    required this.amount,
    required this.paid,
    required this.remaining,
    required this.dueDate,
    required this.status,
  });

  factory CourseInstallment.fromJson(Map<String, dynamic> json) =>
      CourseInstallment(
        number: _int(json['installment_no']),
        amount: _num(json['amount']),
        paid: _num(json['paid']),
        remaining: _num(json['remaining']),
        dueDate: _str(json['due_date']),
        status: _str(json['status']),
      );
}

class CourseFees {
  final double totalFee;
  final double standardFee;
  final bool specialFee;
  final String? feeReason;
  final double paid;
  final double balance;
  final double overdue;
  final CourseInstallment? next;
  final List<CourseInstallment> installments;

  const CourseFees({
    required this.totalFee,
    required this.standardFee,
    required this.specialFee,
    required this.feeReason,
    required this.paid,
    required this.balance,
    required this.overdue,
    required this.next,
    required this.installments,
  });

  factory CourseFees.fromJson(Map<String, dynamic> json) {
    final next = json['next_installment'];

    return CourseFees(
      totalFee: _num(json['total_fee']),
      standardFee: _num(json['standard_fee']),
      specialFee: json['special_fee'] == true,
      feeReason: _strOrNull(json['fee_reason']),
      paid: _num(json['paid']),
      balance: _num(json['balance']),
      overdue: _num(json['overdue']),
      next: next is Map<String, dynamic> ? CourseInstallment.fromJson(next) : null,
      installments:
          _list(json['installments']).map(CourseInstallment.fromJson).toList(),
    );
  }
}

class CourseEnrollmentItem {
  final int id;
  final int courseId;
  final String courseCode;
  final String courseName;

  /// installment / full
  final String paymentPlan;
  final CourseFees fees;

  const CourseEnrollmentItem({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.paymentPlan,
    required this.fees,
  });

  factory CourseEnrollmentItem.fromJson(Map<String, dynamic> json) {
    final course = _map(json['course']);

    return CourseEnrollmentItem(
      id: _int(json['id']),
      courseId: _int(course['id']),
      courseCode: _str(course['code']),
      courseName: _str(course['name']),
      paymentPlan: _str(json['payment_plan']),
      fees: CourseFees.fromJson(_map(json['fees'])),
    );
  }
}

/// POST /api/courses/student
class CourseStudentResult {
  final CourseStudent student;
  final List<CourseEnrollmentItem> enrollments;
  final List<CourseItem> availableCourses;
  final List<String> paymentMethods;

  const CourseStudentResult({
    required this.student,
    required this.enrollments,
    required this.availableCourses,
    required this.paymentMethods,
  });

  factory CourseStudentResult.fromJson(Map<String, dynamic> json) {
    final methods = json['payment_methods'];

    return CourseStudentResult(
      student: CourseStudent.fromJson(_map(json['student'])),
      enrollments:
          _list(json['enrollments']).map(CourseEnrollmentItem.fromJson).toList(),
      availableCourses:
          _list(json['available_courses']).map(CourseItem.fromJson).toList(),
      paymentMethods: methods is List
          ? methods.map((m) => m.toString()).toList()
          : const ['cash'],
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Receipt                                                                     */
/* -------------------------------------------------------------------------- */

class CourseReceipt {
  final int id;
  final String instituteName;
  final String? branch;
  final String title;
  final String receiptNumber;
  final String paidAt;
  final String status;
  final String studentId;
  final String studentName;
  final String courseCode;
  final String courseName;
  final String paymentMethod;
  final double amount;
  final String? specialFeeReason;
  final double courseFee;
  final double totalPaid;
  final double balance;
  final String? nextDueDate;
  final double? nextDueAmount;
  final String? takenBy;

  const CourseReceipt({
    required this.id,
    required this.instituteName,
    required this.branch,
    required this.title,
    required this.receiptNumber,
    required this.paidAt,
    required this.status,
    required this.studentId,
    required this.studentName,
    required this.courseCode,
    required this.courseName,
    required this.paymentMethod,
    required this.amount,
    required this.specialFeeReason,
    required this.courseFee,
    required this.totalPaid,
    required this.balance,
    required this.nextDueDate,
    required this.nextDueAmount,
    required this.takenBy,
  });

  factory CourseReceipt.fromJson(Map<String, dynamic> json) => CourseReceipt(
        id: _int(json['id']),
        instituteName: _str(json['institute_name']),
        branch: _strOrNull(json['branch']),
        title: _str(json['title']).isEmpty ? 'COURSE PAYMENT' : _str(json['title']),
        receiptNumber: _str(json['receipt_number']),
        paidAt: _str(json['paid_at']),
        status: _str(json['status']),
        studentId: _str(json['student_id']),
        studentName: _str(json['student_name']),
        courseCode: _str(json['course_code']),
        courseName: _str(json['course_name']),
        paymentMethod: _str(json['payment_method']),
        amount: _num(json['amount']),
        specialFeeReason: _strOrNull(json['special_fee_reason']),
        courseFee: _num(json['course_fee']),
        totalPaid: _num(json['total_paid']),
        balance: _num(json['balance']),
        nextDueDate: _strOrNull(json['next_due_date']),
        nextDueAmount:
            json['next_due_amount'] == null ? null : _num(json['next_due_amount']),
        takenBy: _strOrNull(json['taken_by']),
      );
}

/* -------------------------------------------------------------------------- */
/* Class days / attendance                                                     */
/* -------------------------------------------------------------------------- */

class CourseSessionItem {
  final int id;
  final int courseId;
  final String courseName;
  final String courseCode;
  final String date;
  final String startTime;
  final String endTime;
  final String? hall;

  /// scheduled / ongoing / completed / cancelled
  final String status;
  final bool isExtra;
  final bool canMark;
  final int presentCount;
  final int studentsCount;

  const CourseSessionItem({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.courseCode,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.hall,
    required this.status,
    required this.isExtra,
    required this.canMark,
    required this.presentCount,
    required this.studentsCount,
  });

  factory CourseSessionItem.fromJson(Map<String, dynamic> json) =>
      CourseSessionItem(
        id: _int(json['id']),
        courseId: _int(json['course_id']),
        courseName: _str(json['course_name']),
        courseCode: _str(json['course_code']),
        date: _str(json['date']),
        startTime: _str(json['start_time']),
        endTime: _str(json['end_time']),
        hall: _strOrNull(json['hall']),
        status: _str(json['status']),
        isExtra: json['is_extra'] == true,
        canMark: json['can_mark'] == true,
        presentCount: _int(json['present_count']),
        studentsCount: _int(json['students_count']),
      );
}

/// POST /api/courses/sessions/{id}/attendance
class CourseAttendanceResult {
  final bool alreadyMarked;
  final String message;
  final CourseStudent student;
  final CourseSessionItem session;
  final CourseFees fees;
  final int attended;
  final int held;
  final int percentage;

  const CourseAttendanceResult({
    required this.alreadyMarked,
    required this.message,
    required this.student,
    required this.session,
    required this.fees,
    required this.attended,
    required this.held,
    required this.percentage,
  });

  factory CourseAttendanceResult.fromJson(Map<String, dynamic> json, String message) {
    final attendance = _map(json['attendance']);

    return CourseAttendanceResult(
      alreadyMarked: json['already_marked'] == true,
      message: message,
      student: CourseStudent.fromJson(_map(json['student'])),
      session: CourseSessionItem.fromJson(_map(json['session'])),
      fees: CourseFees.fromJson(_map(json['fees'])),
      attended: _int(attendance['attended']),
      held: _int(attendance['held']),
      percentage: _int(attendance['percentage']),
    );
  }
}

class CourseReportStudent {
  final int studentId;
  final String customId;
  final String name;
  final String? mobile;
  final String? guardianMobile;
  final String? attendedAt;

  const CourseReportStudent({
    required this.studentId,
    required this.customId,
    required this.name,
    this.mobile,
    this.guardianMobile,
    this.attendedAt,
  });

  factory CourseReportStudent.fromJson(Map<String, dynamic> json) =>
      CourseReportStudent(
        studentId: _int(json['student_id']),
        customId: _str(json['custom_id']),
        name: _str(json['initial_name']),
        mobile: _strOrNull(json['mobile']),
        guardianMobile: _strOrNull(json['guardian_mobile']),
        attendedAt: _strOrNull(json['attended_at']),
      );
}

class CourseReportTeacher {
  final int id;
  final String name;
  final String? mobile;
  final String? whatsappUrl;

  const CourseReportTeacher({
    required this.id,
    required this.name,
    this.mobile,
    this.whatsappUrl,
  });

  factory CourseReportTeacher.fromJson(Map<String, dynamic> json) =>
      CourseReportTeacher(
        id: _int(json['id']),
        name: _str(json['name']),
        mobile: _strOrNull(json['mobile']),
        whatsappUrl: _strOrNull(json['whatsapp_url']),
      );
}

/// GET /api/courses/sessions/{id}/report
class CourseSessionReport {
  final CourseSessionItem session;
  final int students;
  final int present;
  final int absent;
  final int percentage;
  final List<CourseReportStudent> presentList;
  final List<CourseReportStudent> absentList;
  final String shareText;
  final List<CourseReportTeacher> teachers;

  const CourseSessionReport({
    required this.session,
    required this.students,
    required this.present,
    required this.absent,
    required this.percentage,
    required this.presentList,
    required this.absentList,
    required this.shareText,
    required this.teachers,
  });

  factory CourseSessionReport.fromJson(Map<String, dynamic> json) {
    final summary = _map(json['summary']);

    return CourseSessionReport(
      session: CourseSessionItem.fromJson(_map(json['session'])),
      students: _int(summary['students']),
      present: _int(summary['present']),
      absent: _int(summary['absent']),
      percentage: _int(summary['percentage']),
      presentList:
          _list(json['present']).map(CourseReportStudent.fromJson).toList(),
      absentList:
          _list(json['absent']).map(CourseReportStudent.fromJson).toList(),
      shareText: _str(json['share_text']),
      teachers:
          _list(json['teachers']).map(CourseReportTeacher.fromJson).toList(),
    );
  }
}
