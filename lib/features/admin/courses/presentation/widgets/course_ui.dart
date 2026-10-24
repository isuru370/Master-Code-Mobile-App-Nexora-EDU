import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';

/// Small shared pieces for the course screens.
class CourseUi {
  const CourseUi._();

  static final NumberFormat _money = NumberFormat('#,##0.00');

  static String money(double value) => 'Rs. ${_money.format(value)}';

  /// "08:00" -> "8:00 AM"
  static String time(String hhmm) {
    try {
      return DateFormat('h:mm a').format(DateFormat('HH:mm').parse(hhmm));
    } catch (_) {
      return hhmm;
    }
  }

  /// "2026-11-01" -> "Sun, 01 Nov 2026"
  static String date(String ymd) {
    try {
      return DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(ymd));
    } catch (_) {
      return ymd;
    }
  }

  static void snack(BuildContext context, String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
  }
}

/// scheduled / ongoing / completed / cancelled, paid / overdue ...
class CourseStatusChip extends StatelessWidget {
  final String status;

  const CourseStatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status) {
      'scheduled' => (AppColors.info, 'Scheduled'),
      'ongoing' => (AppColors.primary, 'Ongoing'),
      'completed' => (AppColors.secondary, 'Completed'),
      'cancelled' => (AppColors.danger, 'Cancelled'),
      'paid' => (AppColors.success, 'Paid'),
      'partly_paid' => (AppColors.warning, 'Part paid'),
      'overdue' => (AppColors.danger, 'Overdue'),
      'due' => (AppColors.secondary, 'Due'),
      _ => (AppColors.secondary, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

/// Empty / error state with an optional retry button.
class CourseMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  const CourseMessage({super.key, required this.icon, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
