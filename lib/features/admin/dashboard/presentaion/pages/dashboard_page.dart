import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:nexorait_education_app/core/enums/scan_type.dart';

import '../../../../../core/enums/scan_student_card.dart';
import '../../../../../core/features/app_features.dart';
import '../../../../../core/navigation/role_router.dart';
import '../../../../../core/storage/session_storage.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/printer_service.dart';
import '../../../../../core/widgets/nx_ui.dart';
import '../../../../auth/data/datasources/auth_remote_data_source.dart';
import '../../../../auth/data/models/branch_model.dart';
import '../../../../auth/data/models/user_model.dart';
import '../../data/models/mobile_dashboard_response_model.dart';
import '../bloc/mobile_dashboard/mobile_dashboard_bloc.dart';
import '../widgets/dashboard_sections.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? _token;
  UserModel? _user;
  bool _showPrinterBanner = false;
  bool _loadingSession = true;

  // Role / branch (from the session, then refreshed by the dashboard API)
  String _role = '';
  List<BranchModel> _branches = const [];
  int? _selectedBranchId;
  List<String> _features = const [];

  /// Institute has the Courses section (GET /api/features)
  bool _hasCourses = AppFeatures.courses;
  bool _loggingOut = false;

  /// Can this role use the feature? (empty list = old backend -> show all)
  bool _can(String feature) =>
      _features.isEmpty || _features.contains(feature);

  bool get _hasManyBranches => _branches.length > 1;

  String get _branchLabel {
    if (_selectedBranchId == null) {
      return _hasManyBranches ? 'All Branches' : '';
    }
    for (final b in _branches) {
      if (b.id == _selectedBranchId) return b.name;
    }
    return '';
  }

  String get _roleLabel {
    switch (_role) {
      case 'SUPER_ADMIN':
        return 'Super Admin';
      case 'ADMIN':
        return 'Admin';
      case 'BRANCH_ADMIN':
        return 'Branch Admin';
      case 'USER':
        return 'Cashier';
      default:
        return _role;
    }
  }

  @override
  void initState() {
    super.initState();

    _loadSession();
    _loadAppFeatures();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      context.read<MobileDashboardBloc>().add(GetMobileDashboardEvent());

      await _checkPrinterStatus();
    });
  }

  Future<void> _checkPrinterStatus() async {
    final printerService = PrinterService();

    if (printerService.isConnected) {
      if (mounted) {
        setState(() {
          _showPrinterBanner = false;
        });
      }
      return;
    }

    final connected = await printerService.autoReconnect();

    if (!mounted) return;

    setState(() {
      _showPrinterBanner = !connected;
    });

    if (!connected) {
      _showPrinterSuggestionDialog();
    }
  }

  Future<void> _loadAppFeatures() async {
    await AppFeatures.loadSaved();
    if (mounted) setState(() => _hasCourses = AppFeatures.courses);

    await AppFeatures.refresh();
    if (mounted) setState(() => _hasCourses = AppFeatures.courses);
  }

  Future<void> _loadSession() async {
    final token = await SessionStorage.getToken();
    final user = await SessionStorage.getUser();
    final role = await SessionStorage.getRole();
    final branches = await SessionStorage.getBranches();
    final selectedBranchId = await SessionStorage.getSelectedBranchId();

    if (!mounted) return;

    setState(() {
      _token = token;
      _user = user;
      _role = role;
      _branches = branches;
      _selectedBranchId = selectedBranchId;
      _loadingSession = false;
    });
  }

  Future<void> _refreshDashboard() async {
    context.read<MobileDashboardBloc>().add(GetMobileDashboardEvent());

    await _loadSession();
  }

  /// Dashboard API answered: use the latest role / branches / menu.
  void _onDashboardLoaded(MobileDashboardLoaded state) {
    final data = state.dashboard.data;

    setState(() {
      if (data.role.isNotEmpty) _role = data.role;
      if (data.branches.isNotEmpty) _branches = data.branches;
      _features = data.features;
    });
  }

  /// null = all branches
  Future<void> _selectBranch(int? branchId) async {
    await SessionStorage.setSelectedBranchId(branchId);

    if (!mounted) return;

    setState(() => _selectedBranchId = branchId);

    context.read<MobileDashboardBloc>().add(GetMobileDashboardEvent());
  }

  Future<void> _showBranchPicker() async {
    if (!_hasManyBranches) return;

    final picked = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        Widget option({
          required int value,
          required String title,
          String? subtitle,
          required IconData icon,
        }) {
          final selected = (_selectedBranchId ?? 0) == value;

          return ListTile(
            leading: Icon(
              icon,
              color: selected ? AppColors.primary : Colors.grey.shade600,
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            subtitle: subtitle == null ? null : Text(subtitle),
            trailing: selected
                ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                : null,
            onTap: () => Navigator.pop(sheetContext, value),
          );
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Select Branch',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
              ),
              // 0 = all branches (bottom sheet cannot return null as a choice)
              option(
                value: 0,
                title: 'All Branches',
                icon: Icons.account_tree_rounded,
              ),
              const Divider(height: 1),
              for (final branch in _branches)
                option(
                  value: branch.id,
                  title: branch.name,
                  subtitle: branch.code,
                  icon: Icons.store_mall_directory_rounded,
                ),
            ],
          ),
        );
      },
    );

    if (picked == null) return; // closed without choosing

    final branchId = picked == 0 ? null : picked;
    if (branchId == _selectedBranchId) return;

    await _selectBranch(branchId);
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Do you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loggingOut = true);

    // Deletes the token on the server, then clears the saved session
    await AuthRemoteDataSource().logout();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      RoleRouter.signIn,
      (route) => false,
    );
  }

  /// Register Student -> choose the card type.
  ///   Temporary card (TMP001...)  -> /create_student  (type the TMP number)
  ///   Permanent card (QR)         -> scan the card -> /register-student
  Future<void> _openRegisterChooser() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        Widget option({
          required String value,
          required IconData icon,
          required Color color,
          required String title,
          required String subtitle,
        }) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 6,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.pop(sheetContext, value),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Register Student',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
              ),
              option(
                value: 'temporary',
                icon: Icons.qr_code_2_rounded,
                color: AppColors.warning,
                title: 'Temporary Card',
                subtitle: 'Register with a TMP number (TMP001...)',
              ),
              option(
                value: 'card',
                icon: Icons.credit_card_rounded,
                color: AppColors.primary,
                title: 'Permanent Card',
                subtitle: 'Scan the student card QR',
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (!mounted || choice == null) return;

    if (choice == 'temporary') {
      await Navigator.pushNamed(context, '/create_student');
    } else {
      await Navigator.pushNamed(
        context,
        '/qr-scan-student-card',
        arguments: {'type': ScanStudentCard.studentCard},
      );
    }

    // New student -> refresh the numbers
    if (mounted) {
      context.read<MobileDashboardBloc>().add(GetMobileDashboardEvent());
    }
  }

  /// Token is no longer valid (401) -> back to sign in.
  Future<void> _goToSignIn(String message) async {
    await SessionStorage.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

    Navigator.pushNamedAndRemoveUntil(
      context,
      RoleRouter.signIn,
      (route) => false,
    );
  }

  static final NumberFormat _moneyFormat = NumberFormat('#,##0.00');

  String _money(dynamic value) {
    if (value == null) return '-';

    final number = value is num ? value : num.tryParse(value.toString());

    if (number == null) {
      final text = value.toString().trim();
      return text.isEmpty ? '-' : text;
    }

    return _moneyFormat.format(number);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good Morning';
    }

    if (hour < 17) {
      return 'Good Afternoon';
    }

    return 'Good Evening';
  }

  void _showPrinterSuggestionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NxIconBox(icon: Icons.print_rounded, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Printer Not Connected',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connect your Bluetooth printer to print payment receipts and reports.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                const NxAlert(
                  tone: NxTone.amber,
                  icon: Icons.info_outline_rounded,
                  message: 'You can continue using the app without a printer.',
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Later'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await Navigator.pushNamed(
                            this.context,
                            '/print_test_screen',
                          );
                          await _checkPrinterStatus();
                        },
                        icon: const Icon(Icons.bluetooth_rounded, size: 18),
                        label: const Text('Connect'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = _user?.name ?? 'Guest User';
    final userEmail = _user?.email ?? 'No Email';
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: !_can('search_student')
          ? null
          : FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/qr-scan',
            arguments: {'type': ScanType.student},
          );
        },
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Search Student'),
      ),
      appBar: AppBar(
        titleSpacing: 0,
        title: NxPageTitle(
          'Dashboard',
          subtitle: _branchLabel,
          subtitleIcon: Icons.store_mall_directory_rounded,
          onTap: _hasManyBranches ? _showBranchPicker : null,
        ),
        actions: [
          if (_hasManyBranches)
            IconButton(
              tooltip: 'Change branch',
              onPressed: _showBranchPicker,
              icon: const Icon(Icons.swap_horiz_rounded),
            ),
          IconButton(
            onPressed: _refreshDashboard,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Printer',
            onPressed: () {
              Navigator.pushNamed(context, '/print_test_screen');
            },
            icon: const Icon(Icons.print_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: NxDrawer(
        header: NxDrawerHeader(
          userName: userName,
          userDetail: _branchLabel.isEmpty ? userEmail : _branchLabel,
          roleLabel: _roleLabel,
        ),
        footer: _drawerTile(
          icon: Icons.logout_rounded,
          title: _loggingOut ? 'Logging out...' : 'Logout',
          danger: true,
          onTap: _logout,
        ),
        children: [
          NxDrawerItem(
            icon: Icons.grid_view_rounded,
            title: 'Dashboard',
            active: true,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
          _sectionHeader('Student Management'),
          if (_can('register_student'))
            _drawerTile(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Register Student',
              onTap: _openRegisterChooser,
            ),
          if (_can('reassign_card'))
            _drawerTile(
              icon: Icons.badge_rounded,
              title: 'Re Assign Student',
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/qr-scan-student-card',
                  arguments: {'type': ScanStudentCard.assignStudentCard},
                );
              },
            ),
          if (_can('capture_image'))
            _drawerTile(
              icon: Icons.photo_camera_rounded,
              title: 'Capture Image',
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/image_capture',
                  arguments: {'registered': false},
                );
              },
            ),
          if (_can('students'))
            _drawerTile(
              icon: Icons.people_alt_rounded,
              title: 'Students',
              onTap: () => Navigator.pushNamed(context, '/students'),
            ),
          if (_can('student_images'))
            _drawerTile(
              icon: Icons.image_rounded,
              title: 'Student Images',
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/qr-scan-student-card',
                  arguments: {'type': ScanStudentCard.studentImage},
                );
              },
            ),
          _sectionHeader('Class & Attendance'),
          if (_can('today_classes'))
            _drawerTile(
              icon: Icons.today_rounded,
              title: 'Today Classes',
              onTap: () => Navigator.pushNamed(context, '/today-class'),
            ),
          if (_can('add_class'))
            _drawerTile(
              icon: Icons.playlist_add_rounded,
              title: 'Add Class',
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/qr-scan',
                  arguments: {'type': ScanType.classes},
                );
              },
            ),
          if (_can('class_schedule'))
            _drawerTile(
              icon: Icons.calendar_month_rounded,
              title: 'Class Schedule',
              onTap: () => Navigator.pushNamed(context, '/class_ongoing'),
            ),
          if (_can('attendance'))
            _drawerTile(
              icon: Icons.fact_check_rounded,
              title: 'Attendance',
              onTap: () => Navigator.pushNamed(context, '/attendance-scan'),
            ),
          _sectionHeader('Financial'),
          if (_can('payment'))
            _drawerTile(
              icon: Icons.payments_rounded,
              title: 'Payment',
              onTap: () => Navigator.pushNamed(context, '/payment-scan'),
            ),
          if (_can('today_payments'))
            _drawerTile(
              icon: Icons.receipt_long_rounded,
              title: 'Today Payments',
              onTap: () => Navigator.pushNamed(context, '/today-payment'),
            ),
          if (_can('admission'))
            _drawerTile(
              icon: Icons.how_to_reg_rounded,
              title: 'Admission',
              onTap: () => Navigator.pushNamed(context, '/admission-payment'),
            ),
          if (_hasCourses) ...[
            _sectionHeader('Courses'),
            _drawerTile(
              icon: Icons.school_rounded,
              title: 'Course Attendance',
              onTap: () => Navigator.pushNamed(context, '/course-attendance'),
            ),
            _drawerTile(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Course Payment',
              onTap: () => Navigator.pushNamed(context, '/course-payment'),
            ),
          ],
          _sectionHeader('Other'),
          if (_can('student_tute'))
            _drawerTile(
              icon: Icons.menu_book_rounded,
              title: 'Student Tute',
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/qr-scan',
                  arguments: {'type': ScanType.tute},
                );
              },
            ),
          _drawerTile(
            icon: Icons.print_rounded,
            title: 'Printer',
            onTap: () => Navigator.pushNamed(context, '/print_test_screen'),
          ),
        ],
      ),
      body: _loadingSession
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator.adaptive(
              onRefresh: _refreshDashboard,
              child: BlocConsumer<MobileDashboardBloc, MobileDashboardState>(
                listener: (context, state) {
                  if (state is MobileDashboardLoaded) {
                    _onDashboardLoaded(state);
                  } else if (state is MobileDashboardSessionExpired) {
                    _goToSignIn(state.message);
                  }
                },
                builder: (context, state) {
                  if (state is MobileDashboardLoading ||
                      state is MobileDashboardSessionExpired) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is MobileDashboardError) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const SizedBox(height: 40),
                        NxCard(
                          child: Column(
                            children: [
                              NxEmpty(
                                icon: Icons.error_outline_rounded,
                                tone: NxTone.red,
                                message: state.message,
                                onRetry: _refreshDashboard,
                              ),
                              if (_hasManyBranches)
                                TextButton(
                                  onPressed: _showBranchPicker,
                                  child: const Text('Change Branch'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  if (state is! MobileDashboardLoaded) {
                    return const Center(child: Text('No dashboard data'));
                  }

                  return _buildDashboard(
                    state.dashboard.data,
                    userName: userName,
                    userEmail: userEmail,
                    width: width,
                  );
                },
              ),
            ),
    );
  }

  /*
  |--------------------------------------------------------------------------
  | Dashboard body
  |--------------------------------------------------------------------------
  */

  Widget _buildDashboard(
    MobileDashboardData dashboard, {
    required String userName,
    required String userEmail,
    required double width,
  }) {
    final columns = width > 900
        ? 4
        : width > 600
        ? 3
        : 2;

    // Looking at several branches -> show the branch name on class rows
    final showBranch =
        dashboard.branch == null && dashboard.branches.length > 1;

    final quickActions = <Widget>[
      if (_can('attendance'))
        _QuickActionCard(
          icon: Icons.assignment_turned_in_sharp,
          label: 'Attendance',
          tone: NxTone.blue,
          onTap: () => Navigator.pushNamed(context, '/attendance-scan'),
        ),
      if (_can('payment'))
        _QuickActionCard(
          icon: Icons.payments_rounded,
          label: 'Payment',
          tone: NxTone.green,
          onTap: () => Navigator.pushNamed(context, '/payment-scan'),
        ),
      if (_can('add_class'))
        _QuickActionCard(
          icon: Icons.class_rounded,
          label: 'Add Class',
          tone: NxTone.violet,
          onTap: () => Navigator.pushNamed(
            context,
            '/qr-scan',
            arguments: {'type': ScanType.classes},
          ),
        ),
      if (_can('student_tute'))
        _QuickActionCard(
          icon: Icons.menu_book_rounded,
          label: 'Student Tute',
          tone: NxTone.info,
          onTap: () => Navigator.pushNamed(
            context,
            '/qr-scan',
            arguments: {'type': ScanType.tute},
          ),
        ),
      if (_hasCourses) ...[
        _QuickActionCard(
          icon: Icons.school_rounded,
          label: 'Course Attendance',
          tone: NxTone.blue,
          onTap: () => Navigator.pushNamed(context, '/course-attendance'),
        ),
        _QuickActionCard(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Course Payment',
          tone: NxTone.green,
          onTap: () => Navigator.pushNamed(context, '/course-payment'),
        ),
      ],
      if (_can('admission'))
        _QuickActionCard(
          icon: Icons.how_to_reg_rounded,
          label: 'Admission',
          tone: NxTone.amber,
          onTap: () => Navigator.pushNamed(context, '/admission-payment'),
        ),
      if (_can('register_student'))
        _QuickActionCard(
          icon: Icons.person_add_alt_1_rounded,
          label: 'Register Student',
          tone: NxTone.violet,
          onTap: _openRegisterChooser,
        ),
    ];

    final overview = [
      ('Students', dashboard.students.total.toString(), Icons.people_alt_rounded, NxTone.blue),
      ('Teachers', dashboard.classes.teachers.toString(), Icons.school_rounded, NxTone.info),
      ('Classes', dashboard.classes.activeClasses.toString(), Icons.class_rounded, NxTone.green),
      ('Enrollments', dashboard.classes.activeEnrollments.toString(), Icons.group_add_rounded, NxTone.violet),
      ('Permanent', dashboard.students.permanent.toString(), Icons.verified_rounded, NxTone.gray),
      ('Temporary', dashboard.students.temporary.toString(), Icons.qr_code_2_rounded, NxTone.red),
      ('New This Month', dashboard.students.newThisMonth.toString(), Icons.fiber_new_rounded, NxTone.amber),
      ('Tutes Today', dashboard.tutesIssuedToday.toString(), Icons.menu_book_rounded, NxTone.info),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Printer
        if (_showPrinterBanner) ...[
          NxAlert(
            tone: NxTone.amber,
            icon: Icons.print_disabled_rounded,
            message: 'Printer not connected. Connect it to print receipts.',
            action: TextButton(
              onPressed: () async {
                await Navigator.pushNamed(context, '/print_test_screen');
                await _checkPrinterStatus();
              },
              child: const Text('Connect'),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Alerts from the server (low cards, cancelled classes ...)
        DashboardAlertsList(alerts: dashboard.alerts),

        // Hero
        _heroCard(
          userName: userName,
          userEmail: userEmail,
          // Only Admin gets the SMS balance from the server
          smsBalance: dashboard.smsBalance == null
              ? null
              : dashboard.smsBalance!.success
              ? _money(dashboard.smsBalance!.data.currentBalance)
              : 'N/A',
          tokenActive: _token != null,
          roleLabel: _roleLabel,
          branchLabel: dashboard.branch?.name ?? _branchLabel,
        ),
        const SizedBox(height: 16),

        // Today classes / attendance
        Row(
          children: [
            Expanded(
              child: NxStatCard(
                onTap: _can('today_classes')
                    ? () => Navigator.pushNamed(context, '/today-class')
                    : null,
                label: 'Today Classes',
                value: dashboard.classes.todayRunning.toString(),
                icon: Icons.today_rounded,
                tone: NxTone.amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NxStatCard(
                onTap: _can('attendance')
                    ? () => Navigator.pushNamed(context, '/attendance-scan')
                    : null,
                label: 'Attendance',
                value: dashboard.todayAttendanceCount.toString(),
                note: 'Marked today',
                icon: Icons.fact_check_rounded,
                tone: NxTone.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Money
        CollectionSummaryCard(
          collection: dashboard.collection,
          highlightMine: dashboard.isCashier,
          onTap: _can('today_payments')
              ? () => Navigator.pushNamed(context, '/today-payment')
              : null,
        ),
        const SizedBox(height: 24),

        // Quick actions
        if (quickActions.isNotEmpty) ...[
          const DashboardSectionTitle(title: 'Quick Actions'),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: width > 600 ? 3 : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 64,
            ),
            children: quickActions,
          ),
          const SizedBox(height: 24),
        ],

        // Finance (Admin / Branch Admin only - null for Cashier)
        if (dashboard.finance != null) ...[
          const DashboardSectionTitle(title: "Today's Finance"),
          FinanceSummaryCard(finance: dashboard.finance!),
          const SizedBox(height: 24),
        ],

        // Today's classes
        DashboardSectionTitle(
          title: "Today's Classes",
          actionText: 'See all',
          onAction: _can('today_classes')
              ? () => Navigator.pushNamed(context, '/today-class')
              : null,
        ),
        TodayClassesList(
          classes: dashboard.todayClasses,
          showBranch: showBranch,
        ),
        const SizedBox(height: 24),

        // Recent payments
        DashboardSectionTitle(
          title: 'Recent Payments',
          actionText: 'See all',
          onAction: _can('today_payments')
              ? () => Navigator.pushNamed(context, '/today-payment')
              : null,
        ),
        RecentPaymentsList(payments: dashboard.recentPayments),
        const SizedBox(height: 24),

        // ID cards
        const DashboardSectionTitle(title: 'ID Card Stock'),
        CardStockCard(cards: dashboard.cards),
        const SizedBox(height: 24),

        // Overview
        const DashboardSectionTitle(title: 'Overview'),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: overview.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 76,
          ),
          itemBuilder: (context, index) {
            final item = overview[index];

            return NxStatCard(
              label: item.$1,
              value: item.$2,
              icon: item.$3,
              tone: item.$4,
            );
          },
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) => NxDrawerSection(title);

  Widget _heroCard({
    required String userName,
    required String userEmail,
    required String? smsBalance,
    required bool tokenActive,
    String roleLabel = '',
    String branchLabel = '',
  }) {
    return NxHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getGreeting().toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: .75),
              fontSize: 11,
              letterSpacing: .8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            userName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            userEmail,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              NxHeroChip(
                icon: Icons.calendar_today_rounded,
                text: DateFormat('EEE, dd MMM yyyy').format(DateTime.now()),
              ),
              if (roleLabel.isNotEmpty)
                NxHeroChip(icon: Icons.badge_rounded, text: roleLabel),
              if (branchLabel.isNotEmpty)
                NxHeroChip(
                  icon: Icons.store_mall_directory_rounded,
                  text: branchLabel,
                ),
              if (smsBalance != null)
                NxHeroChip(icon: Icons.sms_rounded, text: 'SMS: $smsBalance'),
              if (!tokenActive)
                const NxHeroChip(
                  icon: Icons.warning_amber_rounded,
                  text: 'No session',
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Sidebar item: closes the drawer, then opens the page.
  Widget _drawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return NxDrawerItem(
      icon: icon,
      title: title,
      danger: danger,
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final NxTone tone;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NxQuickAction(icon: icon, title: label, tone: tone, onTap: onTap);
  }
}
