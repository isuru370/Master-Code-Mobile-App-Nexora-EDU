import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../data/teacher_tools_api.dart';
import 'tools_widgets.dart';

/// The teacher's class days for the next 60 days: change, cancel or add an
/// extra day. Depending on the institute it is done at once or an admin
/// approves it first.
class TeacherSchedulePage extends StatefulWidget {
  const TeacherSchedulePage({super.key});

  @override
  State<TeacherSchedulePage> createState() => _TeacherSchedulePageState();
}

class _TeacherSchedulePageState extends State<TeacherSchedulePage> {
  final _api = const TeacherToolsApi();

  ScheduleOverview? _data;
  ScheduleOptions? _options;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_api.schedule(), _api.scheduleOptions()]);
      if (!mounted) return;
      setState(() {
        _data = results[0] as ScheduleOverview;
        _options = results[1] as ScheduleOptions;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _done(RequestResult result) {
    ToolsUi.toast(context, result.message);
    _load();
  }

  Future<void> _change(TeacherDay day) async {
    final result = await showModalBottomSheet<RequestResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DayForm(day: day, halls: _options?.hallsFor(day) ?? const []),
    );
    if (result != null && mounted) _done(result);
  }

  Future<void> _cancel(TeacherDay day) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this class day?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${day.title}\n${ToolsUi.date(day.date)} · ${ToolsUi.time(day.startTime)}'),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Reason (parents see this)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              if (reason.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('Cancel class'),
          ),
        ],
      ),
    );

    final text = reason.text.trim();
    if (ok != true || !mounted) return;

    try {
      final result = await _api.requestChange(kind: day.type, action: 'cancel', id: day.id, reason: text);
      if (mounted) _done(result);
    } catch (e) {
      if (mounted) ToolsUi.toast(context, e.toString(), error: true);
    }
  }

  Future<void> _extraDay() async {
    final options = _options;
    if (options == null || (options.classes.isEmpty && options.courses.isEmpty)) {
      ToolsUi.toast(context, 'You have no classes to add a day to.', error: true);
      return;
    }

    final result = await showModalBottomSheet<RequestResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DayForm(options: options),
    );
    if (result != null && mounted) _done(result);
  }

  Future<void> _withdraw(ScheduleRequest request) async {
    try {
      await _api.withdraw(request.id);
      if (!mounted) return;
      ToolsUi.toast(context, 'Request withdrawn.');
      _load();
    } catch (e) {
      if (mounted) ToolsUi.toast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('My Class Days'),
          bottom: const TabBar(tabs: [Tab(text: 'Class days'), Tab(text: 'My requests')]),
        ),
        floatingActionButton: data == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _extraDay,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Extra day'),
              ),
        body: _error != null
            ? ToolsMessage(icon: Icons.error_outline_rounded, message: _error!, onRetry: _load)
            : data == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      RefreshIndicator(onRefresh: _load, child: _days(data)),
                      RefreshIndicator(onRefresh: _load, child: _requests(data)),
                    ],
                  ),
      ),
    );
  }

  Widget _days(ScheduleOverview data) {
    final banner = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: data.autoApply ? AppColors.successLight : AppColors.warningLight,
        borderRadius: AppColors.radiusMedium,
      ),
      child: Text(
        data.autoApply
            ? 'Changes are done at once and parents are told.'
            : 'Changes are sent to the admin. They are done (and parents told) after approval.',
        style: TextStyle(color: data.autoApply ? AppColors.successText : AppColors.warningText, fontWeight: FontWeight.w600),
      ),
    );

    if (data.days.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          banner,
          const SizedBox(height: 40),
          const Center(child: Text('No class days in the next 60 days.', style: TextStyle(color: AppColors.textSecondary))),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: data.days.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return banner;
        final day = data.days[i - 1];
        final cancelled = day.status == 'cancelled';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ToolsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        day.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          decoration: cancelled ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (day.isCourse) const Padding(padding: EdgeInsets.only(right: 6), child: ToolsChip('Course', color: AppColors.violet, background: AppColors.violetLight)),
                    ToolsChip.status(day.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    ToolsUi.date(day.date),
                    '${ToolsUi.time(day.startTime)} - ${ToolsUi.time(day.endTime)}',
                    if (day.hall.isNotEmpty) day.hall,
                    if (!day.isCourse && day.category.isNotEmpty) day.category,
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
                if (cancelled && day.cancelReason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Reason: ${day.cancelReason}', style: const TextStyle(color: AppColors.dangerText, fontSize: 12)),
                  ),
                if (day.pendingRequest)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: ToolsChip('Waiting for admin', color: AppColors.warningText, background: AppColors.warningLight),
                  )
                else if (day.canChange || day.canCancel)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (day.canCancel)
                          TextButton.icon(
                            onPressed: () => _cancel(day),
                            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                            icon: const Icon(Icons.event_busy_rounded, size: 18),
                            label: const Text('Cancel'),
                          ),
                        if (day.canChange)
                          FilledButton.tonalIcon(
                            onPressed: () => _change(day),
                            icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                            label: const Text('Change'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _requests(ScheduleOverview data) {
    if (data.requests.isEmpty) {
      return const ToolsMessage(icon: Icons.inbox_outlined, message: 'No requests in the last 30 days.');
    }

    const actions = {'create': 'Extra day', 'update': 'Change', 'cancel': 'Cancel'};

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.requests.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final r = data.requests[i];
        final d = r.details;
        final when = r.action == 'cancel'
            ? 'Reason: ${jStr(d['reason'])}'
            : '${ToolsUi.date(jStr(d['date']))} · ${ToolsUi.time(jStr(d['start_time']))} - ${ToolsUi.time(jStr(d['end_time']))}';

        return ToolsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                  ToolsChip.status(r.status),
                ],
              ),
              const SizedBox(height: 4),
              Text('${actions[r.action] ?? r.action}: $when', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
              if (r.error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(r.error, style: const TextStyle(color: AppColors.dangerText, fontSize: 12)),
                ),
              if (r.reviewNote.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Admin: ${r.reviewNote}', style: const TextStyle(fontSize: 12)),
                ),
              if (r.status == 'pending')
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => _withdraw(r), child: const Text('Withdraw')),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Change one day ([day] given) or add an extra day ([options] given).
class _DayForm extends StatefulWidget {
  final TeacherDay? day;
  final List<IdName> halls;
  final ScheduleOptions? options;

  const _DayForm({this.day, this.halls = const [], this.options});

  @override
  State<_DayForm> createState() => _DayFormState();
}

class _DayFormState extends State<_DayForm> {
  final _api = const TeacherToolsApi();
  final _note = TextEditingController();

  OptionClass? _class;
  int? _categoryFeeId;
  int? _hallId;
  DateTime? _date;
  TimeOfDay? _start;
  TimeOfDay? _end;
  bool _saving = false;

  bool get _isNew => widget.day == null;

  List<OptionClass> get _all => [...?widget.options?.classes, ...?widget.options?.courses];

  List<IdName> get _halls => _isNew ? (_class?.halls ?? const []) : widget.halls;

  @override
  void initState() {
    super.initState();
    final day = widget.day;

    if (day != null) {
      _date = DateTime.tryParse(day.date);
      _start = ToolsUi.parseTime(day.startTime);
      _end = ToolsUi.parseTime(day.endTime);
      _hallId = day.hallId;
    } else if (_all.length == 1) {
      _pickClass(_all.first);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _pickClass(OptionClass? c) {
    _class = c;
    _categoryFeeId = (c != null && c.categories.length == 1) ? c.categories.first.id : null;
    _hallId = null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date != null && !_date!.isBefore(DateTime(now.year, now.month, now.day)) ? _date! : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (start ? _start : _end) ?? const TimeOfDay(hour: 15, minute: 0),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_date == null || _start == null || _end == null) {
      ToolsUi.toast(context, 'Choose the date, start and end time.', error: true);
      return;
    }
    if (_isNew && _class == null) {
      ToolsUi.toast(context, 'Choose the class.', error: true);
      return;
    }
    if (_isNew && _class!.isCourse == false && _categoryFeeId == null) {
      ToolsUi.toast(context, 'Choose the category.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final day = widget.day;
      final result = await _api.requestChange(
        kind: day != null ? day.type : (_class!.isCourse ? 'course' : 'class'),
        action: day != null ? 'update' : 'create',
        id: day != null ? day.id : _class!.id,
        categoryFeeId: day == null ? _categoryFeeId : null,
        date: ToolsUi.ymd(_date!),
        startTime: ToolsUi.hm(_start!),
        endTime: ToolsUi.hm(_end!),
        hallId: _hallId,
        note: _note.text,
      );
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) ToolsUi.toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final halls = _halls;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              day == null ? 'Add an extra day' : 'Change ${day.title}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (day != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Now: ${ToolsUi.date(day.date)} · ${ToolsUi.time(day.startTime)} - ${ToolsUi.time(day.endTime)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            const SizedBox(height: 16),
            if (_isNew) ...[
              DropdownButtonFormField<OptionClass>(
                initialValue: _class,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Class / course', border: OutlineInputBorder()),
                items: _all
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.isCourse ? '${c.name} (course)' : c.name, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (c) => setState(() => _pickClass(c)),
              ),
              if (_class != null && !_class!.isCourse && _class!.categories.length > 1) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: ValueKey('category${_class!.id}'),
                  initialValue: _categoryFeeId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: _class!.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (v) => setState(() => _categoryFeeId = v),
                ),
              ],
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_rounded),
              label: Text(_date == null ? 'Choose date' : ToolsUi.date(ToolsUi.ymd(_date!))),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(true),
                    child: Text(_start == null ? 'Start time' : 'Start ${ToolsUi.time(ToolsUi.hm(_start!))}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(false),
                    child: Text(_end == null ? 'End time' : 'End ${ToolsUi.time(ToolsUi.hm(_end!))}'),
                  ),
                ),
              ],
            ),
            if (halls.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                key: ValueKey('hall${_class?.id}'),
                initialValue: halls.any((h) => h.id == _hallId) ? _hallId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Hall', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Same / no hall')),
                  ...halls.map((h) => DropdownMenuItem<int?>(value: h.id, child: Text(h.name))),
                ],
                onChanged: (v) => setState(() => _hallId = v),
              ),
            ],
            if (!(_class?.isCourse ?? day?.isCourse ?? false)) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
