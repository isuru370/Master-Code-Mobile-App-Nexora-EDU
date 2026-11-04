import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/error_message.dart';
import '../../../../core/storage/session_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../data/income_report_api.dart';
import '../utils/income_report_pdf.dart';

/// Income Report (all staff): money in and out for a day or a date range,
/// to check the day's collection or a month. Download / share as PDF.
///
/// Income = class fees (hall fees are part of them) + course fees +
/// admission + extra income. Expenses = institute expenses + teacher
/// advances (salaries are not counted).
class IncomeReportPage extends StatefulWidget {
  const IncomeReportPage({super.key});

  @override
  State<IncomeReportPage> createState() => _IncomeReportPageState();
}

enum _Range { today, yesterday, thisMonth, lastMonth, custom }

class _IncomeReportPageState extends State<IncomeReportPage> {
  static final NumberFormat _money = NumberFormat('#,##0.00');
  static String rs(double v) => 'Rs. ${_money.format(v)}';

  final IncomeReportApi _api = const IncomeReportApi();

  _Range _range = _Range.thisMonth;
  late DateTime _from;
  late DateTime _to;
  int? _branchId;

  IncomeReport? _report;
  bool _loading = false;
  bool _sharing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setRange(_Range.thisMonth, load: false);
    SessionStorage.getSelectedBranchId().then((id) {
      _branchId = id;
      _load();
    });
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _setRange(_Range range, {bool load = true}) {
    final today = _dayOnly(DateTime.now());

    switch (range) {
      case _Range.today:
        _from = today;
        _to = today;
        break;
      case _Range.yesterday:
        _from = today.subtract(const Duration(days: 1));
        _to = _from;
        break;
      case _Range.thisMonth:
        _from = DateTime(today.year, today.month, 1);
        _to = today;
        break;
      case _Range.lastMonth:
        _from = DateTime(today.year, today.month - 1, 1);
        _to = DateTime(today.year, today.month, 0); // last day of last month
        break;
      case _Range.custom:
        break;
    }

    _range = range;
    if (load) _load();
  }

  Future<void> _pickCustom() async {
    final today = _dayOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
      initialDateRange: DateTimeRange(start: _from, end: _to.isAfter(today) ? today : _to),
      helpText: 'Select the date range',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _range = _Range.custom;
      _from = _dayOnly(picked.start);
      _to = _dayOnly(picked.end);
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final report = await _api.load(from: _from, to: _to, branchId: _branchId);
      if (!mounted) return;
      setState(() => _report = report);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _report = null;
        _error = friendlyError(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sharePdf() async {
    final report = _report;
    if (report == null || _sharing) return;

    setState(() => _sharing = true);
    try {
      await IncomeReportPdf.share(report);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not make the PDF: ${friendlyError(e)}'),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /* -------------------------------- UI ---------------------------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Income Report'),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            icon: _sharing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _report == null || _loading ? null : _sharePdf,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            _rangePicker(),
            const SizedBox(height: 12),
            if (_loading && _report == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _errorBox(_error!)
            else if (_report != null) ...[
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              _totals(_report!),
              const SizedBox(height: 12),
              _summaryCard(_report!),
              if (!_report!.isOneDay && _report!.days.isNotEmpty) ...[
                const SizedBox(height: 12),
                _daysCard(_report!),
              ],
              if (_report!.expenseItems.isNotEmpty || _report!.advanceItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                _itemsCard('Expenses and advances', [
                  ..._report!.expenseItems.map((e) => (e, 'Expense')),
                  ..._report!.advanceItems.map((e) => (e, 'Advance')),
                ]),
              ],
            ],
          ],
        ),
      ),
      floatingActionButton: _report == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _loading || _sharing ? null : _sharePdf,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download PDF'),
            ),
    );
  }

  Widget _rangePicker() {
    final label = _report != null ? IncomeReportPdf.rangeLabel(_report!) : _rangeText();

    Widget chip(String text, _Range range) => ChoiceChip(
          label: Text(text),
          selected: _range == range,
          onSelected: _loading
              ? null
              : (_) {
                  setState(() => _setRange(range, load: false));
                  _load();
                },
        );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                chip('Today', _Range.today),
                chip('Yesterday', _Range.yesterday),
                chip('This month', _Range.thisMonth),
                chip('Last month', _Range.lastMonth),
                ActionChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(_range == _Range.custom ? 'Custom' : 'Pick dates'),
                  onPressed: _loading ? null : _pickCustom,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (_report != null && _report!.branch.isNotEmpty)
                  Text(_report!.branch, style: const TextStyle(color: AppColors.secondary, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _rangeText() {
    final f = DateFormat('d MMM yyyy');
    return _from == _to ? f.format(_from) : '${f.format(_from)} - ${f.format(_to)}';
  }

  Widget _totals(IncomeReport r) {
    Widget box(String label, double value, Color color, Color background) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(_money.format(value),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
                ),
              ],
            ),
          ),
        );

    return Row(children: [
      box('Income', r.totalIncome, AppColors.successText, AppColors.successLight),
      const SizedBox(width: 8),
      box('Expenses', r.totalExpenses, AppColors.dangerText, AppColors.dangerLight),
      const SizedBox(width: 8),
      box('Net total', r.net, r.net < 0 ? AppColors.dangerText : AppColors.primaryDark, AppColors.primaryLight),
    ]);
  }

  Widget _summaryCard(IncomeReport r) {
    Widget line(String label, double amount, {bool bold = false, bool sub = false, Color? color}) => Padding(
          padding: EdgeInsets.fromLTRB(sub ? 16 : 0, 5, 0, 5),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      fontSize: sub ? 12 : 14,
                      color: sub ? AppColors.secondary : color,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                    )),
              ),
              Text(rs(amount),
                  style: TextStyle(
                    fontSize: sub ? 12 : 14,
                    color: sub ? AppColors.secondary : color,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  )),
            ],
          ),
        );

    Widget header(String text) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(text,
              style: const TextStyle(fontSize: 11, letterSpacing: .8, fontWeight: FontWeight.w800, color: AppColors.secondary)),
        );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header('INCOME'),
            line('Class fees (${r.classFees.count})', r.classFees.amount),
            if (r.hallFee > 0) line('of which hall fees (${r.hallFeeCount})', r.hallFee, sub: true),
            for (final m in r.classFeesByMethod.entries)
              if (r.classFeesByMethod.length > 1) line(_methodLabel(m.key), m.value, sub: true),
            if (r.courseFees != null) line('Course fees (${r.courseFees!.count})', r.courseFees!.amount),
            line('Admission fees (${r.admission.count})', r.admission.amount),
            line('Extra income (${r.extraIncome.count})', r.extraIncome.amount),
            line('Total income', r.totalIncome, bold: true, color: AppColors.successText),
            const Divider(height: 20),
            header('EXPENSES'),
            line('Institute expenses (${r.expenses.count})', r.expenses.amount),
            line('Teacher advances (${r.teacherAdvances.count})', r.teacherAdvances.amount),
            line('Total expenses', r.totalExpenses, bold: true, color: AppColors.dangerText),
            const Divider(height: 20),
            line('Net total', r.net, bold: true, color: r.net < 0 ? AppColors.dangerText : AppColors.primaryDark),
            const SizedBox(height: 4),
            const Text('Teacher salaries are not counted here.',
                style: TextStyle(fontSize: 11, color: AppColors.secondary)),
          ],
        ),
      ),
    );
  }

  Widget _daysCard(IncomeReport r) {
    final f = DateFormat('d MMM, EEE');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 4, 14, 4),
              child: Text('Day by day', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            for (final day in r.days)
              ListTile(
                dense: true,
                title: Text(DateTime.tryParse(day.date) == null ? day.date : f.format(DateTime.parse(day.date))),
                subtitle: Text('In ${_money.format(day.income)}   Out ${_money.format(day.out)}'),
                trailing: Text(_money.format(day.net),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: day.net < 0 ? AppColors.dangerText : AppColors.primaryDark,
                    )),
              ),
          ],
        ),
      ),
    );
  }

  Widget _itemsCard(String title, List<(IncomeItem, String)> items) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            for (final (item, kind) in items)
              ListTile(
                dense: true,
                title: Text(item.title.isEmpty ? kind : item.title),
                subtitle: Text([item.date, kind, if (item.note.isNotEmpty) item.note].join('  |  ')),
                trailing: Text(_money.format(item.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String message) => Card(
        elevation: 0,
        color: AppColors.dangerLight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.dangerText)),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );

  static String _methodLabel(String method) {
    if (method.isEmpty) return '-';
    final text = method.replaceAll('_', ' ');
    return text[0].toUpperCase() + text.substring(1);
  }
}
