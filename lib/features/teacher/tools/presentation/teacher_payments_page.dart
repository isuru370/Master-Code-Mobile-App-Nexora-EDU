import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../data/teacher_tools_api.dart';
import 'tools_widgets.dart';

/// The teacher's own money: salary of a month (earnings by class, advances,
/// deductions, welfare), salary history, which students paid, and courses.
class TeacherPaymentsPage extends StatefulWidget {
  final bool courses;

  const TeacherPaymentsPage({super.key, this.courses = false});

  @override
  State<TeacherPaymentsPage> createState() => _TeacherPaymentsPageState();
}

class _TeacherPaymentsPageState extends State<TeacherPaymentsPage> {
  final _api = const TeacherToolsApi();

  List<IdName> _branches = const [];
  int? _branchId;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  // Bumped to reload every tab
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final list = await _api.paymentBranches();
      if (!mounted) return;
      setState(() {
        _branches = list;
        _branchId = list.isNotEmpty ? list.first.id : null;
        _version++;
      });
    } catch (_) {
      // The tabs show the error themselves
    }
  }

  void _moveMonth(int by) {
    final next = DateTime(_month.year, _month.month + by);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() {
      _month = next;
      _version++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const Tab(text: 'Salary'),
      const Tab(text: 'Students'),
      const Tab(text: 'Deductions'),
      const Tab(text: 'History'),
      if (widget.courses) const Tab(text: 'Courses'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('My Payments'),
          bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: tabs),
        ),
        body: Column(
          children: [
            _filterBar(),
            Expanded(
              child: TabBarView(
                children: [
                  _Loader(
                    key: ValueKey('salary$_version'),
                    load: () => _api.paymentMonth(branchId: _branchId, year: _month.year, month: _month.month),
                    builder: _salary,
                  ),
                  _StudentsTab(key: ValueKey('students$_version'), branchId: _branchId, month: _month),
                  _Loader(
                    key: ValueKey('deductions$_version'),
                    load: () => _api.paymentDeductions(branchId: _branchId, year: _month.year, month: _month.month),
                    builder: _deductions,
                  ),
                  _Loader(
                    key: ValueKey('history$_version'),
                    load: () => _api.paymentHistory(branchId: _branchId),
                    builder: _history,
                  ),
                  if (widget.courses)
                    _Loader(key: ValueKey('courses$_version'), load: _api.paymentCourses, builder: _courses),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterBar() {
    final now = DateTime.now();
    final isThisMonth = _month.year == now.year && _month.month == now.month;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: [
          IconButton(onPressed: () => _moveMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy').format(_month),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          IconButton(
            onPressed: isThisMonth ? null : () => _moveMonth(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          if (_branches.length > 1)
            DropdownButton<int>(
              value: _branchId,
              underline: const SizedBox.shrink(),
              items: _branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
              onChanged: (v) => setState(() {
                _branchId = v;
                _version++;
              }),
            ),
        ],
      ),
    );
  }

  /* ------------------------------- Salary ------------------------------- */

  Widget _salary(Map<String, dynamic> d) {
    final status = jStr(d['salary_status'], 'pending');
    final earnings = jList(d['earnings']);
    final deductions = jList(d['deductions']);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: AppColors.radiusXLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      status == 'paid' ? 'Salary paid' : 'Salary so far',
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                  ),
                  ToolsChip.status(status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                ToolsUi.money(jDouble(d['net_payable'])),
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
              ),
              if (jStr(d['paid_at']).isNotEmpty)
                Text(
                  'Paid on ${DateFormat('d MMM yyyy').format(DateTime.parse(jStr(d['paid_at'])).toLocal())}',
                  style: const TextStyle(color: Colors.white70),
                ),
              if (jStr(d['branch']).isNotEmpty) Text(jStr(d['branch']), style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ToolsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Earnings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 6),
              if (earnings.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('No fees collected yet this month.', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ...earnings.map((e) {
                final classTotal = jDouble(e['class_total']);
                final pct = jDouble(e['teacher_percentage']);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ToolsRow(jStr(e['description']).replaceAll(' Teacher Salary', ''), ToolsUi.money(jDouble(e['amount']))),
                      if (classTotal > 0)
                        Text(
                          'Fees ${ToolsUi.money(classTotal)} · your share ${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1)}%',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                        ),
                    ],
                  ),
                );
              }),
              const Divider(),
              ToolsRow('Total earnings', ToolsUi.money(jDouble(d['teacher_earnings']) + jDouble(d['carried'])), bold: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ToolsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Deductions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 6),
              if (deductions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('No deductions.', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ...deductions.map((e) => ToolsRow(jStr(e['description']), '- ${ToolsUi.money(jDouble(e['amount']))}', color: AppColors.dangerText)),
              const Divider(),
              ToolsRow('Total deductions', '- ${ToolsUi.money(jDouble(d['total_deductions']))}', bold: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ToolsCard(
          child: Column(
            children: [
              ToolsRow('Fees collected for your classes', ToolsUi.money(jDouble(d['class_income']))),
              if (jDouble(d['paid_after_salary']) > 0)
                ToolsRow('Paid after the salary (next salary)', ToolsUi.money(jDouble(d['paid_after_salary']))),
              const Divider(),
              ToolsRow('Net salary', ToolsUi.money(jDouble(d['net_payable'])), bold: true, color: AppColors.primary),
            ],
          ),
        ),
      ],
    );
  }

  /* ----------------------------- Deductions ----------------------------- */

  Widget _deductions(Map<String, dynamic> d) {
    final totals = jMap(d['totals']);
    final payments = jList(d['payments']);
    final welfare = jList(d['welfare']);
    const labels = {'advance': 'Advance', 'deduction': 'Deduction', 'other': 'Other'};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ToolsCard(
          child: Column(
            children: [
              ToolsRow('Advance', ToolsUi.money(jDouble(totals['advance']))),
              ToolsRow('Deduction', ToolsUi.money(jDouble(totals['deduction']))),
              ToolsRow('Other', ToolsUi.money(jDouble(totals['other']))),
              if (jBool(d['welfare_enabled'])) ToolsRow('Welfare', ToolsUi.money(jDouble(totals['welfare']))),
              const Divider(),
              ToolsRow('Total', ToolsUi.money(jDouble(totals['all'])), bold: true),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (payments.isEmpty && welfare.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: Center(child: Text('Nothing taken this month.', style: TextStyle(color: AppColors.textSecondary))),
          ),
        ...payments.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ToolsCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(labels[jStr(p['type'])] ?? jStr(p['type']), style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            [ToolsUi.date(jStr(p['date'])), if (jStr(p['reason']).isNotEmpty) jStr(p['reason'])].join(' · '),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    Text(ToolsUi.money(jDouble(p['amount'])), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            )),
        ...welfare.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ToolsCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Welfare', style: TextStyle(fontWeight: FontWeight.w700)),
                          if (jStr(w['note']).isNotEmpty)
                            Text(jStr(w['note']), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Text(ToolsUi.money(jDouble(w['amount'])), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  /* ------------------------------- History ------------------------------ */

  Widget _history(Map<String, dynamic> d) {
    final months = jList(d['months']);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: months.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final m = months[i];
        final hasRecord = m['net'] != null;

        return ToolsCard(
          onTap: () => setState(() {
            _month = DateTime(jInt(m['year']), jInt(m['month']));
            _version++;
            DefaultTabController.of(context).animateTo(0);
          }),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(jStr(m['month_name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (hasRecord)
                      Text(
                        'Earned ${ToolsUi.money(jDouble(m['gross']))} · less ${ToolsUi.money(jDouble(m['deductions']))}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasRecord) Text(ToolsUi.money(jDouble(m['net'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  ToolsChip.status(jStr(m['status'], 'pending')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /* ------------------------------- Courses ------------------------------ */

  Widget _courses(Map<String, dynamic> d) {
    final courses = jList(d['courses']);
    final payouts = jList(d['payouts']);
    final totals = jMap(d['totals']);

    if (courses.isEmpty) {
      return const ToolsMessage(icon: Icons.school_outlined, message: 'You are not in any course.');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ToolsCard(
          child: Column(
            children: [
              ToolsRow('Earned', ToolsUi.money(jDouble(totals['earned']))),
              ToolsRow('Paid to you', ToolsUi.money(jDouble(totals['paid']))),
              const Divider(),
              ToolsRow('Balance', ToolsUi.money(jDouble(totals['balance'])), bold: true, color: AppColors.primary),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...courses.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ToolsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(jStr(c['name']), style: const TextStyle(fontWeight: FontWeight.w700))),
                        if (c['percentage'] != null) ToolsChip('${jDouble(c['percentage']).toStringAsFixed(0)}%'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ToolsRow('Earned', ToolsUi.money(jDouble(c['earned']))),
                    ToolsRow('Paid', ToolsUi.money(jDouble(c['paid']))),
                    ToolsRow('Balance', ToolsUi.money(jDouble(c['balance'])), bold: true),
                  ],
                ),
              ),
            )),
        if (payouts.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Payments to you', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          ...payouts.map((p) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(jStr(p['course'])),
                subtitle: Text(ToolsUi.date(jStr(p['paid_on']))),
                trailing: Text(ToolsUi.money(jDouble(p['amount'])), style: const TextStyle(fontWeight: FontWeight.w700)),
              )),
        ],
      ],
    );
  }
}

/// Paid / unpaid students of the teacher's classes for the month.
class _StudentsTab extends StatefulWidget {
  final int? branchId;
  final DateTime month;

  const _StudentsTab({super.key, required this.branchId, required this.month});

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  final _api = const TeacherToolsApi();
  String _basis = 'fee-month';
  String _show = 'unpaid';

  @override
  Widget build(BuildContext context) {
    return _Loader(
      key: ValueKey(_basis),
      load: () => _api.paymentStudents(branchId: widget.branchId, year: widget.month.year, month: widget.month.month, basis: _basis),
      builder: (d) {
        final summary = jMap(d['summary']);
        final classes = jList(d['classes']);
        const groups = {'unpaid': 'Not paid', 'paid': 'Paid', 'freecard': 'Free card', 'noattend': 'No attendance'};

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'fee-month', label: Text('Fee of month')),
                ButtonSegment(value: 'paid-date', label: Text('Paid in month')),
              ],
              selected: {_basis},
              onSelectionChanged: (v) => setState(() => _basis = v.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _stat('Paid', jInt(summary['paid_students']), AppColors.successText),
                _stat('Not paid', jInt(summary['unpaid_students']), AppColors.dangerText),
                _stat('Free', jInt(summary['freecard_students']), AppColors.infoText),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Collected ${ToolsUi.money(jDouble(summary['total_collected']))}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: groups.entries
                  .map((g) => ChoiceChip(
                        label: Text(g.value),
                        selected: _show == g.key,
                        onSelected: (_) => setState(() => _show = g.key),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            if (classes.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 30),
                child: Center(child: Text('No classes.', style: TextStyle(color: AppColors.textSecondary))),
              ),
            for (final c in classes)
              for (final cat in jList(c['categories']))
                _categoryCard(jStr(c['class_name']), cat),
          ],
        );
      },
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _categoryCard(String className, Map<String, dynamic> cat) {
    final students = jList(jMap(cat['students'])[_show]);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ToolsCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$className · ${jStr(cat['category_name'])}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Paid ${jInt(cat['paid_count'])} · Not paid ${jInt(cat['unpaid_count'])} · Free ${jInt(cat['freecard_count'])}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            if (students.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('None', style: TextStyle(color: AppColors.textMuted)),
              ),
            ...students.map((s) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(jStr(s['initial_name'])),
                  subtitle: Text(jStr(s['student_code'])),
                  trailing: Text(
                    _show == 'paid'
                        ? ToolsUi.money(jDouble(s['paid_amount']))
                        : _show == 'unpaid'
                            ? ToolsUi.money(jDouble(s['balance']))
                            : '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

/// Loads a map once and builds from it (pull to refresh).
class _Loader extends StatefulWidget {
  final Future<Map<String, dynamic>> Function() load;
  final Widget Function(Map<String, dynamic>) builder;

  const _Loader({super.key, required this.load, required this.builder});

  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  late Future<Map<String, dynamic>> _future = widget.load();

  Future<void> _reload() async {
    setState(() => _future = widget.load());
    await _future.catchError((_) => <String, dynamic>{});
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ToolsMessage(icon: Icons.error_outline_rounded, message: snap.error.toString(), onRetry: _reload);
          }
          return widget.builder(snap.data ?? const <String, dynamic>{});
        },
      ),
    );
  }
}
