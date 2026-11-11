import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';

/// Small shared pieces for the teacher tools pages.
class ToolsUi {
  ToolsUi._();

  static final NumberFormat _money = NumberFormat('#,##0.00');

  static String money(num value) => 'Rs. ${_money.format(value)}';

  /// "2026-10-14" -> "Wed, 14 Oct 2026"
  static String date(String ymd) {
    final d = DateTime.tryParse(ymd);
    return d == null ? ymd : DateFormat('EEE, d MMM yyyy').format(d);
  }

  /// "15:00" -> "3:00 PM"
  static String time(String hm) {
    final parts = hm.split(':');
    if (parts.length < 2) return hm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return DateFormat('h:mm a').format(DateTime(2000, 1, 1, h, m));
  }

  static String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static String hm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay? parseTime(String hm) {
    final parts = hm.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
  }

  static void toast(BuildContext context, String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.dark,
        behavior: SnackBarBehavior.floating,
      ));
  }
}

class ToolsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const ToolsCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppColors.radiusLarge,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppColors.radiusLarge,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: AppColors.radiusLarge,
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

class ToolsMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  const ToolsMessage({super.key, required this.icon, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
      children: [
        Icon(icon, size: 48, color: AppColors.textMuted),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        ],
      ],
    );
  }
}

class ToolsChip extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const ToolsChip(this.text, {super.key, this.color = AppColors.primary, this.background = AppColors.primaryLight});

  factory ToolsChip.status(String status) {
    return switch (status) {
      'approved' || 'completed' || 'paid' => ToolsChip(_label(status), color: AppColors.successText, background: AppColors.successLight),
      'pending' || 'scheduled' => ToolsChip(_label(status), color: AppColors.warningText, background: AppColors.warningLight),
      'ongoing' => ToolsChip(_label(status), color: AppColors.infoText, background: AppColors.infoLight),
      'rejected' || 'failed' || 'cancelled' || 'unpaid' => ToolsChip(_label(status), color: AppColors.dangerText, background: AppColors.dangerLight),
      _ => ToolsChip(_label(status), color: AppColors.textSecondary, background: AppColors.surfaceSecondary),
    };
  }

  static String _label(String s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

/// Label on the left, amount on the right.
class ToolsRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const ToolsRow(this.label, this.value, {super.key, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 15 : 13.5,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: color ?? AppColors.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style.copyWith(color: color ?? AppColors.textSecondary))),
          const SizedBox(width: 8),
          Text(value, style: style),
        ],
      ),
    );
  }
}
