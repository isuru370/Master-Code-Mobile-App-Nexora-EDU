import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../data/models/attendance_report/summary_data.dart';

class AttendanceSummaryCard extends StatelessWidget {
  final SummaryData summary;

  const AttendanceSummaryCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.summarize,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSummaryItem(
                icon: Icons.people,
                label: 'Total',
                value: summary.totalStudents.toString(),
                color: AppColors.primary,
              ),
              _buildSummaryItem(
                icon: Icons.check_circle,
                label: 'Present',
                value: summary.presentStudents.toString(),
                color: AppColors.success,
              ),
              _buildSummaryItem(
                icon: Icons.cancel,
                label: 'Absent',
                value: summary.absentStudents.toString(),
                color: AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.divider),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSummaryItem(
                icon: Icons.payment,
                label: 'Paid',
                value: summary.paidStudents.toString(),
                color: AppColors.primary,
              ),
              _buildSummaryItem(
                icon: Icons.money_off,
                label: 'Unpaid',
                value: summary.unpaidStudents.toString(),
                color: AppColors.warning,
              ),
              _buildSummaryItem(
                icon: Icons.percent,
                label: 'Attendance',
                value: '${summary.attendancePercentage}%',
                color: summary.attendancePercentage >= 80
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkLight,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}