import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/errors/error_message.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../data/course_api.dart';
import '../../data/course_models.dart';
import '../widgets/course_ui.dart';
import 'course_scan_page.dart';

/// One course class day: scan students, see who came / who did not,
/// and send the report to the teacher on WhatsApp.
class CourseSessionPage extends StatefulWidget {
  final CourseSessionItem session;

  const CourseSessionPage({super.key, required this.session});

  @override
  State<CourseSessionPage> createState() => _CourseSessionPageState();
}

class _CourseSessionPageState extends State<CourseSessionPage> {
  final CourseApi _api = const CourseApi();

  late CourseSessionItem _session = widget.session;
  CourseSessionReport? _report;
  bool _loading = true;
  bool _marking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = _report == null;
      _error = null;
    });

    try {
      final report = await _api.report(_session.id);
      if (!mounted) return;
      setState(() {
        _report = report;
        _session = report.session;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Scan -> mark -> show the result -> scan the next one (until closed).
  Future<void> _scan() async {
    while (mounted) {
      final result = await Navigator.push<CourseScanResult>(
        context,
        MaterialPageRoute(builder: (_) => CourseScanPage(title: _session.courseName)),
      );

      if (result == null || !mounted) break;

      setState(() => _marking = true);

      CourseAttendanceResult? marked;
      String? error;

      try {
        marked = await _api.markAttendance(
          sessionId: _session.id,
          code: result.code,
          scanned: result.scanned,
        );
      } catch (e) {
        error = friendlyError(e);
      }

      if (!mounted) return;
      setState(() => _marking = false);

      final next = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _MarkResultSheet(result: marked, error: error),
      );

      await _loadReport();

      if (next != true) break;
    }
  }

  Future<void> _share() async {
    final text = _report?.shareText ?? '';
    if (text.isEmpty) return;

    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _sendToTeacher() async {
    final teachers = _report?.teachers ?? const <CourseReportTeacher>[];

    if (teachers.isEmpty) {
      await _share();
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Send report on WhatsApp', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            for (final teacher in teachers)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDCFCE7),
                  child: Icon(Icons.chat_rounded, color: Color(0xFF16A34A)),
                ),
                title: Text(teacher.name),
                subtitle: Text(teacher.mobile ?? 'No mobile number'),
                enabled: teacher.whatsappUrl != null,
                onTap: () async {
                  Navigator.pop(sheet);
                  await _openWhatsApp(teacher.whatsappUrl!);
                },
              ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.share_rounded)),
              title: const Text('Share with another app'),
              onTap: () {
                Navigator.pop(sheet);
                _share();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

    if (!ok && mounted) {
      CourseUi.snack(context, 'Could not open WhatsApp. Use "Share" instead.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_session.courseName),
          actions: [
            IconButton(
              tooltip: 'Send to teacher',
              icon: const Icon(Icons.send_rounded),
              onPressed: report == null ? null : _sendToTeacher,
            ),
          ],
          bottom: report == null
              ? null
              : TabBar(
                  tabs: [
                    Tab(text: 'Absent (${report.absent})'),
                    Tab(text: 'Present (${report.present})'),
                  ],
                ),
        ),
        floatingActionButton: _session.canMark
            ? FloatingActionButton.extended(
                onPressed: _marking ? null : _scan,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                icon: _marking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan student'),
              )
            : null,
        body: _body(report),
      ),
    );
  }

  Widget _body(CourseSessionReport? report) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (report == null) {
      return CourseMessage(
        icon: Icons.error_outline_rounded,
        message: _error ?? 'Could not load the class day.',
        onRetry: _loadReport,
      );
    }

    return Column(
      children: [
        _Header(session: _session, report: report),
        Expanded(
          child: TabBarView(
            children: [
              _StudentList(students: report.absentList, present: false, onRefresh: _loadReport),
              _StudentList(students: report.presentList, present: true, onRefresh: _loadReport),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final CourseSessionItem session;
  final CourseSessionReport report;

  const _Header({required this.session, required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  CourseUi.date(session.date),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: CourseStatusChip(session.status),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${CourseUi.time(session.startTime)} - ${CourseUi.time(session.endTime)}'
            '${session.hall != null ? ' · ${session.hall}' : ''}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('Present', '${report.present}'),
              _stat('Absent', '${report.absent}'),
              _stat('Students', '${report.students}'),
              _stat('Rate', '${report.percentage}%'),
            ],
          ),
          if (!session.canMark) ...[
            const SizedBox(height: 10),
            Text(
              session.status == 'cancelled'
                  ? 'This class day is cancelled.'
                  : session.status == 'completed'
                      ? 'This class day is over.'
                      : 'Attendance opens on the class day.',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StudentList extends StatelessWidget {
  final List<CourseReportStudent> students;
  final bool present;
  final Future<void> Function() onRefresh;

  const _StudentList({required this.students, required this.present, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: students.isEmpty
          ? ListView(children: [
              const SizedBox(height: 60),
              CourseMessage(
                icon: present ? Icons.person_off_rounded : Icons.celebration_rounded,
                message: present ? 'Nobody marked yet.' : 'Everyone is here.',
              ),
            ])
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: students.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final s = students[i];

                return Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: (present ? AppColors.success : AppColors.danger).withValues(alpha: 0.12),
                      child: Icon(
                        present ? Icons.check_rounded : Icons.close_rounded,
                        color: present ? AppColors.success : AppColors.danger,
                      ),
                    ),
                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(s.customId),
                    trailing: present && s.attendedAt != null ? Text(s.attendedAt!) : null,
                  ),
                );
              },
            ),
    );
  }
}

/// Shown after each scan. Pops true for "Scan next".
class _MarkResultSheet extends StatelessWidget {
  final CourseAttendanceResult? result;
  final String? error;

  const _MarkResultSheet({required this.result, required this.error});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final color = r == null ? AppColors.danger : (r.alreadyMarked ? AppColors.warning : AppColors.success);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              r == null ? Icons.error_rounded : (r.alreadyMarked ? Icons.info_rounded : Icons.check_circle_rounded),
              size: 56,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              r != null ? r.student.name : 'Not marked',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              r != null ? '${r.student.customId} · ${r.message}' : (error ?? ''),
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            if (r != null) ...[
              const SizedBox(height: 12),
              Text(
                'Attendance ${r.attended} / ${r.held} (${r.percentage}%)',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (r.fees.overdue > 0 || r.fees.balance > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: r.fees.overdue > 0 ? AppColors.dangerLight : AppColors.warningLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    r.fees.overdue > 0
                        ? 'Fee overdue: ${CourseUi.money(r.fees.overdue)} (balance ${CourseUi.money(r.fees.balance)})'
                        : 'Course fee balance: ${CourseUi.money(r.fees.balance)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: r.fees.overdue > 0 ? AppColors.danger : const Color(0xFF92400E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Done'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
