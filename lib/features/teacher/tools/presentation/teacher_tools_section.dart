import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../data/teacher_tools_api.dart';
import 'teacher_attendance_page.dart';
import 'teacher_payments_page.dart';
import 'teacher_schedule_page.dart';

/// "Teacher Tools" on the teacher home: only the tools the institute turned
/// on (web: Settings > Teacher App). Shows nothing when none are on.
class TeacherToolsSection extends StatefulWidget {
  const TeacherToolsSection({super.key});

  @override
  State<TeacherToolsSection> createState() => _TeacherToolsSectionState();
}

class _TeacherToolsSectionState extends State<TeacherToolsSection> {
  TeacherToolsFeatures _features = const TeacherToolsFeatures();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final features = await const TeacherToolsApi().features();
      if (mounted) setState(() => _features = features);
    } catch (_) {
      // Offline: keep the tools hidden
    }
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final f = _features;
    if (!f.any) return const SizedBox.shrink();

    final tiles = <Widget>[
      if (f.attendance)
        _tile(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Mark Attendance',
          subtitle: 'Today\'s classes · QR or list',
          color: AppColors.success,
          background: AppColors.successLight,
          onTap: () => _open(const TeacherAttendancePage()),
        ),
      if (f.schedule)
        _tile(
          icon: Icons.edit_calendar_rounded,
          title: 'My Class Days',
          subtitle: f.scheduleAuto ? 'Change, add or cancel' : 'Change, add or cancel (admin approves)',
          color: AppColors.primary,
          background: AppColors.primaryLight,
          onTap: () => _open(const TeacherSchedulePage()),
        ),
      if (f.payments)
        _tile(
          icon: Icons.account_balance_wallet_rounded,
          title: 'My Payments',
          subtitle: 'Salary, deductions, who paid',
          color: AppColors.violet,
          background: AppColors.violetLight,
          onTap: () => _open(TeacherPaymentsPage(courses: f.courses)),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Teacher Tools',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 14),
          for (final tile in tiles) Padding(padding: const EdgeInsets.only(bottom: 10), child: tile),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color background,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppColors.radiusLarge,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppColors.radiusLarge,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppColors.radiusLarge,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
