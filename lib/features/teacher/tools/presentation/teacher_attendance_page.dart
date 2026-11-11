import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_colors.dart';
import '../data/teacher_tools_api.dart';
import 'tools_widgets.dart';

/// Today's classes and courses of the teacher; tap one to mark attendance.
class TeacherAttendancePage extends StatefulWidget {
  const TeacherAttendancePage({super.key});

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  final _api = const TeacherToolsApi();
  late Future<List<TeacherDay>> _future = _api.todayClasses();

  Future<void> _reload() async {
    setState(() => _future = _api.todayClasses());
    await _future.catchError((_) => <TeacherDay>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mark Attendance')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<TeacherDay>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ToolsMessage(icon: Icons.error_outline_rounded, message: snap.error.toString(), onRetry: _reload);
            }

            final days = snap.data ?? const <TeacherDay>[];
            if (days.isEmpty) {
              return const ToolsMessage(icon: Icons.event_available_rounded, message: 'You have no classes today.');
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: days.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _dayCard(days[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _dayCard(TeacherDay day) {
    return ToolsCard(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherDayAttendancePage(day: day)));
        if (mounted) _reload();
      },
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: day.isCourse ? AppColors.violetLight : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              day.isCourse ? Icons.school_rounded : Icons.menu_book_rounded,
              color: day.isCourse ? AppColors.violet : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (day.category.isNotEmpty) day.category,
                    '${ToolsUi.time(day.startTime)} - ${ToolsUi.time(day.endTime)}',
                    if (day.hall.isNotEmpty) day.hall,
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${day.present}/${day.enrolled}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Text('present', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Students of one class day: tick and save, or scan QR.
class TeacherDayAttendancePage extends StatefulWidget {
  final TeacherDay day;

  const TeacherDayAttendancePage({super.key, required this.day});

  @override
  State<TeacherDayAttendancePage> createState() => _TeacherDayAttendancePageState();
}

class _TeacherDayAttendancePageState extends State<TeacherDayAttendancePage> {
  final _api = const TeacherToolsApi();
  final _search = TextEditingController();

  List<TeacherDayStudent>? _students;
  String? _error;
  final Set<int> _ticked = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await _api.dayStudents(widget.day);
      if (!mounted) return;
      setState(() {
        _students = list;
        _error = null;
        _ticked.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _save() async {
    if (_ticked.isEmpty) return;
    setState(() => _saving = true);

    try {
      final result = await _api.mark(widget.day, _ticked.toList());
      if (!mounted) return;
      final failed = result.failed.isEmpty ? '' : '\n${result.failed.join('\n')}';
      ToolsUi.toast(context, '${result.message}$failed', error: result.failed.isNotEmpty);
      await _load();
    } catch (e) {
      if (mounted) ToolsUi.toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _scan() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _TeacherScanPage(day: widget.day)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final students = _students;
    final query = _search.text.trim().toLowerCase();
    final shown = (students ?? const <TeacherDayStudent>[])
        .where((s) => query.isEmpty || s.name.toLowerCase().contains(query) || s.code.toLowerCase().contains(query))
        .toList();
    final present = students?.where((s) => s.present).length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.day.title),
        actions: [
          IconButton(tooltip: 'Scan QR', icon: const Icon(Icons.qr_code_scanner_rounded), onPressed: _scan),
        ],
      ),
      body: _error != null
          ? ToolsMessage(icon: Icons.error_outline_rounded, message: _error!, onRetry: _load)
          : students == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$present of ${students.length} present',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _scan,
                            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                            label: const Text('Scan QR'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search name or ID',
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: shown.isEmpty
                            ? const ToolsMessage(icon: Icons.groups_outlined, message: 'No students.')
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(8, 0, 8, 90),
                                itemCount: shown.length,
                                itemBuilder: (context, i) {
                                  final s = shown[i];
                                  if (s.present) {
                                    return ListTile(
                                      leading: const Icon(Icons.check_circle_rounded, color: AppColors.success),
                                      title: Text(s.name),
                                      subtitle: Text(s.code),
                                      trailing: ToolsChip('Present', color: AppColors.successText, background: AppColors.successLight),
                                    );
                                  }

                                  return CheckboxListTile(
                                    value: _ticked.contains(s.id),
                                    onChanged: (v) => setState(() => v == true ? _ticked.add(s.id) : _ticked.remove(s.id)),
                                    title: Text(s.name),
                                    subtitle: Text(s.code),
                                    controlAffinity: ListTileControlAffinity.leading,
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _ticked.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.done_all_rounded),
                  label: Text('Mark ${_ticked.length} present'),
                ),
              ),
            ),
    );
  }
}

/// Camera stays open: each scan is marked and shown at the bottom.
class _TeacherScanPage extends StatefulWidget {
  final TeacherDay day;

  const _TeacherScanPage({required this.day});

  @override
  State<_TeacherScanPage> createState() => _TeacherScanPageState();
}

class _TeacherScanPageState extends State<_TeacherScanPage> {
  final _api = const TeacherToolsApi();
  final MobileScannerController _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final _manual = TextEditingController();

  bool _busy = false;
  String? _lastCode;
  DateTime _lastAt = DateTime(2000);
  ScanResult? _result;
  int _count = 0;

  @override
  void dispose() {
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _handle(String raw) async {
    final code = raw.trim();
    if (code.isEmpty || _busy) return;

    // Same card again within 3 seconds: ignore
    if (code == _lastCode && DateTime.now().difference(_lastAt).inSeconds < 3) return;
    _lastCode = code;
    _lastAt = DateTime.now();

    setState(() => _busy = true);
    try {
      final result = await _api.scan(widget.day, code);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _result = result;
        if (result.ok && !result.already) _count++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = ScanResult(ok: false, already: false, message: e.toString(), studentName: ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final ok = result?.ok == true;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Scan · ${widget.day.title}'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(tooltip: 'Torch', icon: const Icon(Icons.flash_on_rounded), onPressed: () => _controller.toggleTorch()),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    if (capture.barcodes.isEmpty) return;
                    final value = capture.barcodes.first.rawValue;
                    if (value != null) _handle(value);
                  },
                ),
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                if (_busy) const CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
          if (result != null)
            Container(
              width: double.infinity,
              color: ok ? (result.already ? AppColors.warningLight : AppColors.successLight) : AppColors.dangerLight,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    ok ? (result.already ? Icons.info_rounded : Icons.check_circle_rounded) : Icons.cancel_rounded,
                    color: ok ? (result.already ? AppColors.warningText : AppColors.successText) : AppColors.dangerText,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      [if (result.studentName.isNotEmpty) result.studentName, result.message].join('\n'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
            child: Column(
              children: [
                Text('$_count marked now', style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manual,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (v) {
                          _handle(v);
                          _manual.clear();
                        },
                        decoration: InputDecoration(
                          hintText: 'Or type student ID',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        _handle(_manual.text);
                        _manual.clear();
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
