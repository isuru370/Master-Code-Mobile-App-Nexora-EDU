import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../data/model/scan_attendance_new/attendance_class_choice_model.dart';

/// "Which class?" - shown when the student has more than one class open now
/// (e.g. A 4:30-6:00 PM and B 6:00-8:00 PM at 5:30 PM). Nothing has been
/// marked yet. Returns the picked schedule id, or null when cancelled.
Future<int?> showAttendanceClassChoiceSheet(
  BuildContext context, {
  required String message,
  required String studentName,
  required List<AttendanceClassChoiceModel> classes,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose the class',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              studentName.isEmpty ? message : '$studentName - $message',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: classes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final item = classes[index];
                  return _ClassChoiceTile(
                    item: item,
                    onTap: () => Navigator.pop(sheetContext, item.scheduleId),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ClassChoiceTile extends StatelessWidget {
  final AttendanceClassChoiceModel item;
  final VoidCallback onTap;

  const _ClassChoiceTile({required this.item, required this.onTap});

  /// "16:30:00" -> "4:30 PM"
  static String _time(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) return value;
    final hour = int.parse(match.group(1)!);
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:${match.group(2)} ${hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = item.alreadyMarked
        ? ('Already marked', AppColors.warning, AppColors.warningLight)
        : item.isStarted
            ? ('In progress', AppColors.success, AppColors.successLight)
            : ('Starts ${_time(item.startTime)}', AppColors.info, AppColors.infoLight);

    final details = [
      '${_time(item.startTime)} - ${_time(item.endTime)}',
      if (item.hall.isNotEmpty) item.hall,
      if (item.teacher.isNotEmpty) item.teacher,
    ].join('  ·  ');

    return Material(
      color: AppColors.background,
      borderRadius: AppColors.radiusMedium,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppColors.radiusMedium,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppColors.radiusMedium,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.category.isEmpty ? item.className : '${item.className} (${item.category})',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(details, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
                child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
