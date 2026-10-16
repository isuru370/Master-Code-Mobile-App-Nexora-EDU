/// Models for the grouped sections of GET /api/mobile-dashboard.
///
/// Every fromJson is null-safe: a missing / wrong value becomes 0, '' or null,
/// so an older backend never crashes the dashboard.

/// Small safe JSON readers used by the dashboard models.
class JsonRead {
  JsonRead._();

  static int toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? toStr(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static Map<String, dynamic> map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<T> list<T>(
    dynamic value,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    if (value is! List) return <T>[];
    return value.whereType<Map>().map((e) => fromJson(map(e))).toList();
  }
}

/*
|--------------------------------------------------------------------------
| students
|--------------------------------------------------------------------------
*/

class DashboardStudentStats {
  final int total;
  final int active;
  final int inactive;
  final int permanent;
  final int temporary;
  final int newToday;
  final int newThisMonth;

  const DashboardStudentStats({
    this.total = 0,
    this.active = 0,
    this.inactive = 0,
    this.permanent = 0,
    this.temporary = 0,
    this.newToday = 0,
    this.newThisMonth = 0,
  });

  factory DashboardStudentStats.fromJson(Map<String, dynamic> json) {
    return DashboardStudentStats(
      total: JsonRead.toInt(json['total']),
      active: JsonRead.toInt(json['active']),
      inactive: JsonRead.toInt(json['inactive']),
      permanent: JsonRead.toInt(json['permanent']),
      temporary: JsonRead.toInt(json['temporary']),
      newToday: JsonRead.toInt(json['new_today']),
      newThisMonth: JsonRead.toInt(json['new_this_month']),
    );
  }
}

/*
|--------------------------------------------------------------------------
| classes
|--------------------------------------------------------------------------
*/

class DashboardClassStats {
  final int teachers;
  final int activeClasses;
  final int activeEnrollments;
  final int todayTotal;

  /// Today's sessions that are not cancelled
  final int todayRunning;
  final int todayScheduled;
  final int todayOngoing;
  final int todayCompleted;
  final int todayCancelled;

  const DashboardClassStats({
    this.teachers = 0,
    this.activeClasses = 0,
    this.activeEnrollments = 0,
    this.todayTotal = 0,
    this.todayRunning = 0,
    this.todayScheduled = 0,
    this.todayOngoing = 0,
    this.todayCompleted = 0,
    this.todayCancelled = 0,
  });

  factory DashboardClassStats.fromJson(Map<String, dynamic> json) {
    return DashboardClassStats(
      teachers: JsonRead.toInt(json['teachers']),
      activeClasses: JsonRead.toInt(json['active_classes']),
      activeEnrollments: JsonRead.toInt(json['active_enrollments']),
      todayTotal: JsonRead.toInt(json['today_total']),
      todayRunning: JsonRead.toInt(json['today_running']),
      todayScheduled: JsonRead.toInt(json['today_scheduled']),
      todayOngoing: JsonRead.toInt(json['today_ongoing']),
      todayCompleted: JsonRead.toInt(json['today_completed']),
      todayCancelled: JsonRead.toInt(json['today_cancelled']),
    );
  }
}

/// One session in "today_classes"
class TodayClassModel {
  final int id;
  final int studentClassId;
  final String className;
  final String? teacherName;
  final String? hallName;
  final String? branchName;
  final String? startTime; // "08:00"
  final String? endTime;

  /// scheduled | ongoing | completed | cancelled
  final String status;
  final int enrolledCount;
  final int attendedCount;
  final String? cancelReason;

  const TodayClassModel({
    required this.id,
    required this.studentClassId,
    required this.className,
    this.teacherName,
    this.hallName,
    this.branchName,
    this.startTime,
    this.endTime,
    required this.status,
    required this.enrolledCount,
    required this.attendedCount,
    this.cancelReason,
  });

  bool get isCancelled => status == 'cancelled';
  bool get isOngoing => status == 'ongoing';
  bool get isCompleted => status == 'completed';

  String get timeRange {
    if (startTime == null) return '-';
    return endTime == null ? startTime! : '$startTime - $endTime';
  }

  /// 0.0 - 1.0 (attended / enrolled)
  double get attendanceRate {
    if (enrolledCount <= 0) return 0;
    final rate = attendedCount / enrolledCount;
    return rate > 1 ? 1 : rate;
  }

  factory TodayClassModel.fromJson(Map<String, dynamic> json) {
    return TodayClassModel(
      id: JsonRead.toInt(json['id']),
      studentClassId: JsonRead.toInt(json['student_class_id']),
      className: JsonRead.toStr(json['class_name']) ?? 'Class',
      teacherName: JsonRead.toStr(json['teacher_name']),
      hallName: JsonRead.toStr(json['hall_name']),
      branchName: JsonRead.toStr(json['branch_name']),
      startTime: JsonRead.toStr(json['start_time']),
      endTime: JsonRead.toStr(json['end_time']),
      status: (JsonRead.toStr(json['status']) ?? 'scheduled').toLowerCase(),
      enrolledCount: JsonRead.toInt(json['enrolled_count']),
      attendedCount: JsonRead.toInt(json['attended_count']),
      cancelReason: JsonRead.toStr(json['cancel_reason']),
    );
  }
}

/*
|--------------------------------------------------------------------------
| collection (money)
|--------------------------------------------------------------------------
*/

class PaymentMethodTotal {
  /// cash | card | bank_transfer | online | cheque | other
  final String method;
  final double amount;
  final int count;

  const PaymentMethodTotal({
    required this.method,
    required this.amount,
    required this.count,
  });

  /// "bank_transfer" -> "Bank Transfer"
  String get label => method
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  factory PaymentMethodTotal.fromJson(Map<String, dynamic> json) {
    return PaymentMethodTotal(
      method: JsonRead.toStr(json['method']) ?? 'other',
      amount: JsonRead.toDouble(json['amount']),
      count: JsonRead.toInt(json['count']),
    );
  }
}

class DashboardCollection {
  final double todayClassFees;
  final int todayClassFeeCount;
  final double todayAdmissions;
  final int todayAdmissionCount;
  final double todayTotal;
  final double todayDiscount;

  /// What the logged-in user collected today
  final double myToday;
  final int myTodayCount;

  final double monthClassFees;
  final double monthAdmissions;
  final double monthTotal;

  final List<PaymentMethodTotal> byMethod;

  const DashboardCollection({
    this.todayClassFees = 0,
    this.todayClassFeeCount = 0,
    this.todayAdmissions = 0,
    this.todayAdmissionCount = 0,
    this.todayTotal = 0,
    this.todayDiscount = 0,
    this.myToday = 0,
    this.myTodayCount = 0,
    this.monthClassFees = 0,
    this.monthAdmissions = 0,
    this.monthTotal = 0,
    this.byMethod = const [],
  });

  factory DashboardCollection.fromJson(Map<String, dynamic> json) {
    return DashboardCollection(
      todayClassFees: JsonRead.toDouble(json['today_class_fees']),
      todayClassFeeCount: JsonRead.toInt(json['today_class_fee_count']),
      todayAdmissions: JsonRead.toDouble(json['today_admissions']),
      todayAdmissionCount: JsonRead.toInt(json['today_admission_count']),
      todayTotal: JsonRead.toDouble(json['today_total']),
      todayDiscount: JsonRead.toDouble(json['today_discount']),
      myToday: JsonRead.toDouble(json['my_today']),
      myTodayCount: JsonRead.toInt(json['my_today_count']),
      monthClassFees: JsonRead.toDouble(json['month_class_fees']),
      monthAdmissions: JsonRead.toDouble(json['month_admissions']),
      monthTotal: JsonRead.toDouble(json['month_total']),
      byMethod: JsonRead.list(json['by_method'], PaymentMethodTotal.fromJson),
    );
  }
}

/// One row in "recent_payments"
class RecentPaymentModel {
  final int id;
  final String? receiptNumber;
  final int studentId;
  final String? studentCustomId;
  final String studentName;
  final String? className;
  final String? paymentMonth; // "2026-10"
  final double amount;
  final String paymentMethod;
  final DateTime? paidAt;
  final String? collectedBy;

  const RecentPaymentModel({
    required this.id,
    this.receiptNumber,
    required this.studentId,
    this.studentCustomId,
    required this.studentName,
    this.className,
    this.paymentMonth,
    required this.amount,
    required this.paymentMethod,
    this.paidAt,
    this.collectedBy,
  });

  /// "09:05"
  String get paidTime {
    final at = paidAt;
    if (at == null) return '-';
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  factory RecentPaymentModel.fromJson(Map<String, dynamic> json) {
    return RecentPaymentModel(
      id: JsonRead.toInt(json['id']),
      receiptNumber: JsonRead.toStr(json['receipt_number']),
      studentId: JsonRead.toInt(json['student_id']),
      studentCustomId: JsonRead.toStr(json['student_custom_id']),
      studentName: JsonRead.toStr(json['student_name']) ?? 'Student',
      className: JsonRead.toStr(json['class_name']),
      paymentMonth: JsonRead.toStr(json['payment_month']),
      amount: JsonRead.toDouble(json['amount']),
      paymentMethod: JsonRead.toStr(json['payment_method']) ?? 'cash',
      paidAt: DateTime.tryParse(json['paid_at']?.toString() ?? ''),
      collectedBy: JsonRead.toStr(json['collected_by']),
    );
  }
}

/// Income / expenses today (Admin & Branch Admin only, null for Cashier)
class DashboardFinance {
  final double studentCollection;
  final double extraIncome;
  final double totalIncome;
  final double expenses;
  final double teacherAdvances;
  final double totalOutgoing;
  final double net;

  const DashboardFinance({
    this.studentCollection = 0,
    this.extraIncome = 0,
    this.totalIncome = 0,
    this.expenses = 0,
    this.teacherAdvances = 0,
    this.totalOutgoing = 0,
    this.net = 0,
  });

  factory DashboardFinance.fromJson(Map<String, dynamic> json) {
    return DashboardFinance(
      studentCollection: JsonRead.toDouble(json['student_collection']),
      extraIncome: JsonRead.toDouble(json['extra_income']),
      totalIncome: JsonRead.toDouble(json['total_income']),
      expenses: JsonRead.toDouble(json['expenses']),
      teacherAdvances: JsonRead.toDouble(json['teacher_advances']),
      totalOutgoing: JsonRead.toDouble(json['total_outgoing']),
      net: JsonRead.toDouble(json['net']),
    );
  }
}

/*
|--------------------------------------------------------------------------
| cards / alerts
|--------------------------------------------------------------------------
*/

class DashboardCardStock {
  final int permanentAvailable;

  /// ok | low | critical
  final String permanentLevel;
  final int temporaryAvailable;
  final String temporaryLevel;

  const DashboardCardStock({
    this.permanentAvailable = 0,
    this.permanentLevel = 'ok',
    this.temporaryAvailable = 0,
    this.temporaryLevel = 'ok',
  });

  /// Old backend sends only available_id_card -> work the level out here
  factory DashboardCardStock.fromPermanentCount(int count) {
    final level = count <= 3 ? 'critical' : (count <= 10 ? 'low' : 'ok');
    return DashboardCardStock(
      permanentAvailable: count,
      permanentLevel: level,
    );
  }

  factory DashboardCardStock.fromJson(Map<String, dynamic> json) {
    return DashboardCardStock(
      permanentAvailable: JsonRead.toInt(json['permanent_available']),
      permanentLevel: JsonRead.toStr(json['permanent_level']) ?? 'ok',
      temporaryAvailable: JsonRead.toInt(json['temporary_available']),
      temporaryLevel: JsonRead.toStr(json['temporary_level']) ?? 'ok',
    );
  }
}

class DashboardAlert {
  /// permanent_cards | temporary_cards | cancelled_classes | pending_admissions | sms_balance
  final String type;

  /// danger | warning | info
  final String level;
  final String message;

  const DashboardAlert({
    required this.type,
    required this.level,
    required this.message,
  });

  factory DashboardAlert.fromJson(Map<String, dynamic> json) {
    return DashboardAlert(
      type: JsonRead.toStr(json['type']) ?? '',
      level: JsonRead.toStr(json['level']) ?? 'info',
      message: JsonRead.toStr(json['message']) ?? '',
    );
  }
}
