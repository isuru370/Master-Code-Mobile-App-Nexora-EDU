import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/errors/error_message.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../data/course_api.dart';
import '../../data/course_models.dart';
import '../widgets/course_ui.dart';
import 'course_session_page.dart';

/// Course Attendance button: the day's course class days.
class CourseAttendancePage extends StatefulWidget {
  const CourseAttendancePage({super.key});

  @override
  State<CourseAttendancePage> createState() => _CourseAttendancePageState();
}

class _CourseAttendancePageState extends State<CourseAttendancePage> {
  final CourseApi _api = const CourseApi();

  DateTime _date = DateTime.now();
  List<CourseSessionItem> _sessions = const [];
  bool _loading = true;
  String? _error;

  String get _ymd => DateFormat('yyyy-MM-dd').format(_date);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sessions = await _api.sessions(date: _ymd);
      if (!mounted) return;
      setState(() => _sessions = sessions);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) return;
    setState(() => _date = picked);
    await _load();
  }

  Future<void> _open(CourseSessionItem session) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CourseSessionPage(session: session)),
    );
    await _load(); // counts / status may have changed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Course Attendance'),
        actions: [
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(DateFormat('dd MMM').format(_date)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(children: [
        const SizedBox(height: 80),
        CourseMessage(icon: Icons.error_outline_rounded, message: _error!, onRetry: _load),
      ]);
    }

    if (_sessions.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 80),
        CourseMessage(
          icon: Icons.event_busy_rounded,
          message: 'No course classes on ${CourseUi.date(_ymd)}.',
        ),
      ]);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _SessionCard(session: _sessions[i], onTap: () => _open(_sessions[i])),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final CourseSessionItem session;
  final VoidCallback onTap;

  const _SessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: AppColors.radiusLarge,
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.courseName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  CourseStatusChip(session.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${session.courseCode}'
                '${session.isExtra ? ' · Extra class' : ''}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('${CourseUi.time(session.startTime)} - ${CourseUi.time(session.endTime)}'),
                  if (session.hall != null) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.meeting_room_rounded, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Flexible(child: Text(session.hall!, overflow: TextOverflow.ellipsis)),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '${session.presentCount} / ${session.studentsCount} present',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Icon(
                    session.canMark ? Icons.qr_code_scanner_rounded : Icons.chevron_right_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    session.canMark ? 'Mark attendance' : 'View report',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
