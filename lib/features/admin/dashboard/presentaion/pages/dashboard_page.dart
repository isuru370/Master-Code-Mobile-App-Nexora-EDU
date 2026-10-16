import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:nexorait_education_app/core/enums/scan_type.dart';

import '../../../../../core/enums/scan_student_card.dart';
import '../../../../../core/navigation/role_router.dart';
import '../../../../../core/storage/session_storage.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/printer_service.dart';
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                color: color.withOpacity(.12),
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
      return 'Good Morning 👋';
    }

    if (hour < 17) {
      return 'Good Afternoon ☀️';
    }

    return 'Good Evening 🌙';
  }

  void _showPrinterSuggestionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.print_rounded,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Printer Not Connected',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No printer is currently connected.\n\n'
                  'Connect your Bluetooth printer now to print payment receipts and reports instantly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'You can continue using the app without a printer.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          await Navigator.pushNamed(
                            context,
                            '/print_test_screen',
                          );

                          await _checkPrinterStatus();
                        },
                        child: const Text('Connect'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/print_test_screen');
                        },
                        icon: const Icon(Icons.bluetooth_rounded),
                        label: const Text(
                          'Connect',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
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
        backgroundColor: AppColors.primary,
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/qr-scan',
            arguments: {'type': ScanType.student},
          );
        },
        icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
        label: const Text(
          'Search Student',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        title: InkWell(
          onTap: _hasManyBranches ? _showBranchPicker : null,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (_branchLabel.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.store_mall_directory_rounded,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _branchLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_hasManyBranches)
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: Colors.white70,
                      ),
                  ],
                ),
            ],
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
            onPressed: () {
              Navigator.pushNamed(context, '/print_test_screen');
            },
            icon: Icon(Icons.print_rounded),
          ),
          IconButton(
            onPressed: () {},
            icon: Stack(
              children: [
                const Icon(Icons.notifications_rounded),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                top: 60,
                left: 20,
                right: 20,
                bottom: 24,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, Color(0xff1D4ED8)],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        if (_roleLabel.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _branchLabel.isEmpty
                                  ? _roleLabel
                                  : '$_roleLabel • $_branchLabel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 8),
                  _sectionHeader('STUDENT MANAGEMENT', Icons.people_rounded),
                  if (_can('register_student'))
                    _drawerTile(
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'Register Student',
                    onTap: () {
                      Navigator.pop(context); // close the drawer
                      _openRegisterChooser();
                    },
                  ),
                  if (_can('reassign_card'))
                    _drawerTile(
                    icon: Icons.person_add_alt_1_rounded,
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
                    icon: Icons.image_outlined,
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
                    onTap: () {
                      Navigator.pushNamed(context, '/students');
                    },
                  ),
                  if (_can('student_images'))
                    _drawerTile(
                    icon: Icons.school_rounded,
                    title: 'Student Images',
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/qr-scan-student-card',
                        arguments: {'type': ScanStudentCard.studentImage},
                      );
                    },
                  ),
                  const Divider(height: 24, thickness: 1),
                  _sectionHeader('CLASS & ATTENDANCE', Icons.class_rounded),
                  if (_can('today_classes'))
                    _drawerTile(
                    icon: Icons.payments_rounded,
                    title: 'Today Classes',
                    onTap: () {
                      Navigator.pushNamed(context, '/today-class');
                    },
                  ),
                  if (_can('add_class'))
                    _drawerTile(
                    icon: Icons.payments_rounded,
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
                    icon: Icons.class_outlined,
                    title: 'Class Schedule',
                    onTap: () {
                      Navigator.pushNamed(context, '/class_ongoing');
                    },
                  ),
                  if (_can('attendance'))
                    _drawerTile(
                    icon: Icons.fact_check_rounded,
                    title: 'Attendance',
                    onTap: () {
                      Navigator.pushNamed(context, '/attendance-scan');
                    },
                  ),
                  const Divider(height: 24, thickness: 1),
                  _sectionHeader('FINANCIAL', Icons.attach_money_rounded),
                  if (_can('payment'))
                    _drawerTile(
                    icon: Icons.payments_rounded,
                    title: 'Payment',
                    onTap: () {
                      Navigator.pushNamed(context, '/payment-scan');
                    },
                  ),
                  if (_can('today_payments'))
                    _drawerTile(
                    icon: Icons.monetization_on_outlined,
                    title: 'Today Payments',
                    onTap: () {
                      Navigator.pushNamed(context, '/today-payment');
                    },
                  ),
                  if (_can('admission'))
                    _drawerTile(
                    icon: Icons.monetization_on_outlined,
                    title: 'Admission',
                    onTap: () {
                      Navigator.pushNamed(context, '/admission-payment');
                    },
                  ),
                  const Divider(height: 24, thickness: 1),
                  _sectionHeader('OTHER', Icons.more_horiz_rounded),
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
                  const SizedBox(height: 16),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _drawerTile(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  color: AppColors.danger,
                  onTap: _logout,
                ),
              ),
            ),
          ],
        ),
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
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: AppColors.softShadow,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 70,
                                color: AppColors.danger,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                state.message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _refreshDashboard,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Try Again'),
                              ),
                              if (_hasManyBranches)
                                TextButton(
                                  onPressed: _showBranchPicker,
                                  child: const Text('Change Branch'),
                                ),
                            ],
                          ),
                        ),
                      ),
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
          color: AppColors.primary,
          onTap: () => Navigator.pushNamed(context, '/attendance-scan'),
        ),
      if (_can('payment'))
        _QuickActionCard(
          icon: Icons.payments_rounded,
          label: 'Payment',
          color: AppColors.success,
          onTap: () => Navigator.pushNamed(context, '/payment-scan'),
        ),
      if (_can('add_class'))
        _QuickActionCard(
          icon: Icons.class_rounded,
          label: 'Add Class',
          color: AppColors.secondary,
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
          color: AppColors.info,
          onTap: () => Navigator.pushNamed(
            context,
            '/qr-scan',
            arguments: {'type': ScanType.tute},
          ),
        ),
      if (_can('admission'))
        _QuickActionCard(
          icon: Icons.how_to_reg_rounded,
          label: 'Admission',
          color: AppColors.warning,
          onTap: () => Navigator.pushNamed(context, '/admission-payment'),
        ),
      if (_can('register_student'))
        _QuickActionCard(
          icon: Icons.person_add_alt_1_rounded,
          label: 'Register',
          color: AppColors.primaryDark,
          onTap: _openRegisterChooser,
        ),
    ];

    final overview = [
      (
        'Students',
        dashboard.students.total.toString(),
        Icons.people_alt_rounded,
        AppColors.primary,
      ),
      (
        'Teachers',
        dashboard.classes.teachers.toString(),
        Icons.school_rounded,
        AppColors.info,
      ),
      (
        'Classes',
        dashboard.classes.activeClasses.toString(),
        Icons.class_rounded,
        AppColors.success,
      ),
      (
        'Enrollments',
        dashboard.classes.activeEnrollments.toString(),
        Icons.group_add_rounded,
        AppColors.primaryDark,
      ),
      (
        'Permanent',
        dashboard.students.permanent.toString(),
        Icons.verified_rounded,
        AppColors.secondary,
      ),
      (
        'Temporary',
        dashboard.students.temporary.toString(),
        Icons.qr_code_2_rounded,
        AppColors.danger,
      ),
      (
        'New This Month',
        dashboard.students.newThisMonth.toString(),
        Icons.fiber_new_rounded,
        AppColors.warning,
      ),
      (
        'Tutes Today',
        dashboard.tutesIssuedToday.toString(),
        Icons.menu_book_rounded,
        AppColors.info,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        // Printer
        if (_showPrinterBanner) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.print_disabled_rounded, color: Colors.orange),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Printer not connected. Connect now to print receipts instantly.',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/print_test_screen');
                    await _checkPrinterStatus();
                  },
                  child: const Text('Connect'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
        const SizedBox(height: 20),

        // Today classes / attendance
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _can('today_classes')
                    ? () => Navigator.pushNamed(context, '/today-class')
                    : null,
                child: _miniStat(
                  title: 'Today Classes',
                  value: dashboard.classes.todayRunning.toString(),
                  icon: Icons.today_rounded,
                  color: AppColors.warning,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _can('attendance')
                    ? () => Navigator.pushNamed(context, '/attendance-scan')
                    : null,
                child: _miniStat(
                  title: 'Attendance Today',
                  value: dashboard.todayAttendanceCount.toString(),
                  icon: Icons.fact_check_rounded,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

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
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: width > 600 ? 6 : 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.95,
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
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) {
            final item = overview[index];

            return _StatCard(
              title: item.$1,
              value: item.$2,
              icon: item.$3,
              color: item.$4,
            );
          },
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard({
    required String userName,
    required String userEmail,
    required String? smsBalance,
    required bool tokenActive,
    String roleLabel = '',
    String branchLabel = '',
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff2563EB), Color(0xff1D4ED8), Color(0xff1E40AF)],
        ),
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff2563EB).withOpacity(.25),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getGreeting(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(userEmail, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _heroBadge(
                icon: Icons.verified_user_rounded,
                text: tokenActive ? 'Session Active' : 'No Session',
              ),
              if (roleLabel.isNotEmpty)
                _heroBadge(icon: Icons.badge_rounded, text: roleLabel),
              if (branchLabel.isNotEmpty)
                _heroBadge(
                  icon: Icons.store_mall_directory_rounded,
                  text: branchLabel,
                ),
              if (smsBalance != null)
                _heroBadge(
                  icon: Icons.sms_rounded,
                  text: 'SMS Balance: $smsBalance',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroBadge({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          // Big amounts shrink instead of wrapping to a second line
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = AppColors.secondary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(.12), color.withOpacity(.03)],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: color.withOpacity(.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 30),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
