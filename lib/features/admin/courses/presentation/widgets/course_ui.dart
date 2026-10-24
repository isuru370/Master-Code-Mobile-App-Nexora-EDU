import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/nx_ui.dart';

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
/// (web .nx-badge)
class CourseStatusChip extends StatelessWidget {
  final String status;

  const CourseStatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (NxTone tone, String label) = switch (status) {
      'scheduled' => (NxTone.info, 'Scheduled'),
      'ongoing' => (NxTone.blue, 'Ongoing'),
      'completed' => (NxTone.gray, 'Completed'),
      'cancelled' => (NxTone.red, 'Cancelled'),
      'paid' => (NxTone.green, 'Paid'),
      'partly_paid' => (NxTone.amber, 'Part paid'),
      'overdue' => (NxTone.red, 'Overdue'),
      'due' => (NxTone.gray, 'Due'),
      _ => (NxTone.gray, status),
    };

    return NxBadge(label, tone: tone);
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
      child: NxEmpty(icon: icon, message: message, onRetry: onRetry),
    );
  }
}
