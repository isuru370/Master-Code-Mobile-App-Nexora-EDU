import '../../../../auth/data/models/branch_model.dart';
import 'dashboard_section_models.dart';
import 'sms_balance_model.dart';

export 'dashboard_section_models.dart';

class MobileDashboardResponseModel {
  final bool success;
  final String message;
  final MobileDashboardData data;

  MobileDashboardResponseModel({
    required this.success,
    required this.message,
    required this.data,
  });

  factory MobileDashboardResponseModel.fromJson(Map<String, dynamic> json) {
    return MobileDashboardResponseModel(
      success: json['success'] == true,
      message: JsonRead.toStr(json['message']) ?? '',
      data: MobileDashboardData.fromJson(JsonRead.map(json['data'])),
    );
  }
}

class MobileDashboardData {
  /// null for Branch Admin / Cashier (only Admin sees the SMS balance)
  final SmsBalanceModel? smsBalance;

  /*
   * Flat values (old keys - kept so older screens keep working)
   */
  final int totalStudent;
  final int totalTeacher;
  final int totalClasses;
  final int todayClassCount;
  final int todayCancelledClassCount;
  final double todayPaymentCollection;
  final int todayPaymentCount;
  final double todayAdmissionCollection;
  final double todayTotalCollection;
  final double myTodayCollection;
  final int currentMonthAdmissionCount;
  final int temporaryStudentCount;
  final int permanentStudentCount;
  final int availableIdCard;
  final List<CurrentMonthAdmissionModel> currentMonthAdmissions;

  /*
   * Grouped sections
   */
  final DashboardStudentStats students;
  final DashboardClassStats classes;
  final List<TodayClassModel> todayClasses;
  final int todayAttendanceCount;
  final DashboardCollection collection;
  final List<RecentPaymentModel> recentPayments;
  final int pendingAdmissionCount;
  final int tutesIssuedToday;
  final DashboardCardStock cards;

  /// null for Cashier
  final DashboardFinance? finance;
  final List<DashboardAlert> alerts;

  /*
   * Role / branch
   */
  final String role;
  final bool allBranches;

  /// Branch the numbers are for (null = all branches)
  final BranchModel? branch;
  final List<BranchModel> branches;

  /// Menu items this role can use (register_student, payment, class_schedule ...)
  final List<String> features;

  /// How this institute gives ID cards: "permanent" / "temporary"
  /// (null = old backend)
  final String? cardMode;

  /// Server date "2026-10-16"
  final String? date;

  MobileDashboardData({
    required this.smsBalance,
    required this.totalStudent,
    required this.totalTeacher,
    required this.totalClasses,
    required this.todayClassCount,
    required this.todayCancelledClassCount,
    required this.todayPaymentCollection,
    required this.todayPaymentCount,
    required this.todayAdmissionCollection,
    required this.todayTotalCollection,
    required this.myTodayCollection,
    required this.currentMonthAdmissionCount,
    required this.temporaryStudentCount,
    required this.permanentStudentCount,
    required this.availableIdCard,
    required this.currentMonthAdmissions,
    required this.students,
    required this.classes,
    required this.todayClasses,
    required this.todayAttendanceCount,
    required this.collection,
    required this.recentPayments,
    required this.pendingAdmissionCount,
    required this.tutesIssuedToday,
    required this.cards,
    required this.finance,
    required this.alerts,
    required this.role,
    required this.allBranches,
    required this.branch,
    required this.branches,
    required this.features,
    this.cardMode,
    required this.date,
  });

  /// true if this role can use the feature.
  /// Old backend (no "features" sent) -> show everything like before.
  bool can(String feature) => features.isEmpty || features.contains(feature);

  bool get isAdmin => role == 'SUPER_ADMIN' || role == 'ADMIN';

  bool get isBranchAdmin => role == 'BRANCH_ADMIN';

  bool get isCashier => role == 'USER';

  factory MobileDashboardData.fromJson(Map<String, dynamic> json) {
    final payments = JsonRead.toDouble(json['today_payment_collection']);
    final admissions = JsonRead.toDouble(json['today_admission_collection']);
    final availableIdCard = JsonRead.toInt(json['available_id_card']);

    final collectionJson = JsonRead.map(json['collection']);
    final cardsJson = JsonRead.map(json['cards']);

    return MobileDashboardData(
      smsBalance: json['sms_balance'] is Map
          ? SmsBalanceModel.fromJson(JsonRead.map(json['sms_balance']))
          : null,

      // Flat values
      totalStudent: JsonRead.toInt(json['total_student']),
      totalTeacher: JsonRead.toInt(json['total_teacher']),
      totalClasses: JsonRead.toInt(json['total_classes']),
      todayClassCount: JsonRead.toInt(json['today_class_count']),
      todayCancelledClassCount: JsonRead.toInt(
        json['today_cancelled_class_count'],
      ),
      todayPaymentCollection: payments,
      todayPaymentCount: JsonRead.toInt(json['today_payment_count']),
      todayAdmissionCollection: admissions,
      todayTotalCollection: json['today_total_collection'] == null
          ? payments + admissions
          : JsonRead.toDouble(json['today_total_collection']),
      myTodayCollection: JsonRead.toDouble(json['my_today_collection']),
      currentMonthAdmissionCount: JsonRead.toInt(
        json['current_month_admission_count'],
      ),
      temporaryStudentCount: JsonRead.toInt(json['temporary_student_count']),
      permanentStudentCount: JsonRead.toInt(json['permanent_student_count']),
      availableIdCard: availableIdCard,
      currentMonthAdmissions: JsonRead.list(
        json['current_month_admissions'],
        CurrentMonthAdmissionModel.fromJson,
      ),

      // Sections (old backend -> filled from the flat values)
      students: json['students'] is Map
          ? DashboardStudentStats.fromJson(JsonRead.map(json['students']))
          : DashboardStudentStats(
              total: JsonRead.toInt(json['total_student']),
              permanent: JsonRead.toInt(json['permanent_student_count']),
              temporary: JsonRead.toInt(json['temporary_student_count']),
              newThisMonth: JsonRead.toInt(
                json['current_month_admission_count'],
              ),
            ),
      classes: json['classes'] is Map
          ? DashboardClassStats.fromJson(JsonRead.map(json['classes']))
          : DashboardClassStats(
              teachers: JsonRead.toInt(json['total_teacher']),
              activeClasses: JsonRead.toInt(json['total_classes']),
              todayRunning: JsonRead.toInt(json['today_class_count']),
            ),
      todayClasses: JsonRead.list(
        json['today_classes'],
        TodayClassModel.fromJson,
      ),
      todayAttendanceCount: JsonRead.toInt(
        JsonRead.map(json['attendance'])['today_count'],
      ),
      collection: collectionJson.isEmpty
          ? DashboardCollection(
              todayClassFees: payments,
              todayAdmissions: admissions,
              todayTotal: payments + admissions,
            )
          : DashboardCollection.fromJson(collectionJson),
      recentPayments: JsonRead.list(
        json['recent_payments'],
        RecentPaymentModel.fromJson,
      ),
      pendingAdmissionCount: JsonRead.toInt(
        JsonRead.map(json['admissions'])['pending_count'],
      ),
      tutesIssuedToday: JsonRead.toInt(
        JsonRead.map(json['tutes'])['issued_today'],
      ),
      cards: cardsJson.isEmpty
          ? DashboardCardStock.fromPermanentCount(availableIdCard)
          : DashboardCardStock.fromJson(cardsJson),
      finance: json['finance'] is Map
          ? DashboardFinance.fromJson(JsonRead.map(json['finance']))
          : null,
      alerts: JsonRead.list(json['alerts'], DashboardAlert.fromJson),

      // Role / branch
      role: (JsonRead.toStr(json['role']) ?? '').toUpperCase(),
      allBranches: json['all_branches'] == true,
      branch: json['branch'] is Map
          ? BranchModel.fromJson(JsonRead.map(json['branch']))
          : null,
      branches: BranchModel.listFromJson(json['branches']),
      features: (json['features'] is List ? json['features'] as List : const [])
          .map((e) => e.toString())
          .toList(),
      cardMode: JsonRead.toStr(json['card_mode']),
      date: JsonRead.toStr(json['date']),
    );
  }
}

class CurrentMonthAdmissionModel {
  final int id;
  final String customId;
  final String? temporaryQrCode;
  final String initialName;
  final String gender;
  final String guardianMobile;

  CurrentMonthAdmissionModel({
    required this.id,
    required this.customId,
    required this.temporaryQrCode,
    required this.initialName,
    required this.gender,
    required this.guardianMobile,
  });

  factory CurrentMonthAdmissionModel.fromJson(Map<String, dynamic> json) {
    return CurrentMonthAdmissionModel(
      id: JsonRead.toInt(json['id']),
      customId: JsonRead.toStr(json['custom_id']) ?? '',
      temporaryQrCode: JsonRead.toStr(json['temporary_qr_code']),
      initialName: JsonRead.toStr(json['initial_name']) ?? '',
      gender: JsonRead.toStr(json['gender']) ?? '',
      guardianMobile: JsonRead.toStr(json['guardian_mobile']) ?? '',
    );
  }
}
