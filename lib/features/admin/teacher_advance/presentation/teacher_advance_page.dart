import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/error_message.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/printer_service.dart';
import '../data/teacher_advance_api.dart';
import '../utils/advance_slip_print.dart';

/// Teacher Advance (Admin / Branch Admin): pick a teacher, give an advance
/// up to this month's available amount, print a slip to sign (can be
/// switched off). Only paying; changes are done on the web.
class TeacherAdvancePage extends StatefulWidget {
  const TeacherAdvancePage({super.key});

  @override
  State<TeacherAdvancePage> createState() => _TeacherAdvancePageState();
}

class _TeacherAdvancePageState extends State<TeacherAdvancePage> {
  static final NumberFormat _money = NumberFormat('#,##0.00');
  static String money(double value) => 'LKR ${_money.format(value)}';

  final TeacherAdvanceApi _api = const TeacherAdvanceApi();
  final PrinterService _printer = PrinterService();
  final TextEditingController _search = TextEditingController();

  int? _branchId;
  List<TeacherAdvanceBranch> _branchChoices = const [];
  TeacherAdvanceList? _list;
  TeacherAdvanceSlip? _lastSlip;
  bool _printSlip = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AdvanceSlipPrint.isOn().then((on) {
      if (mounted) setState(() => _printSlip = on);
    });
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _api.teachers(branchId: _branchId);
      if (!mounted) return;
      setState(() {
        _list = list;
        _branchId = list.branch.id;
      });
    } on TeacherAdvanceBranchChoice catch (choice) {
      if (!mounted) return;
      setState(() {
        _list = null;
        _branchChoices = choice.branches;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _list = null;
        _error = friendlyError(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _chooseBranch(TeacherAdvanceBranch branch) {
    setState(() {
      _branchId = branch.id;
      _lastSlip = null;
    });
    _load();
  }

  /* ------------------------------- Pay ---------------------------------- */

  Future<void> _pay(TeacherAdvanceTeacher teacher) async {
    final branchId = _branchId;
    if (branchId == null) return;

    final input = await showModalBottomSheet<_AdvanceInput>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) => _AdvanceSheet(teacher: teacher, month: _list?.month ?? ''),
    );

    if (input == null || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Give advance?'),
        content: Text('${money(input.amount)} advance to ${teacher.name}.\n'
            'It is taken from the ${_list?.month ?? 'this month\'s'} salary.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Pay')),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => _loading = true);

    try {
      final slip = await _api.pay(
        teacherId: teacher.id,
        branchId: branchId,
        amount: input.amount,
        reason: input.reason,
        note: input.note,
      );

      if (!mounted) return;
      setState(() => _lastSlip = slip);
      _snack('Advance paid: ${money(slip.amount)} to ${slip.teacherName}.');

      if (_printSlip) await _print(slip);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(friendlyError(e), error: true);
    }
  }

  Future<void> _print(TeacherAdvanceSlip slip) async {
    if (!_printer.isConnected) {
      final reconnected = await _printer.autoReconnect();

      if (!reconnected) {
        if (!mounted) return;
        final connect = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Printer not connected'),
            content: Text('The advance ${slip.reference} is saved. Connect the printer to print the slip now?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Skip')),
              FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Connect printer')),
            ],
          ),
        );

        if (connect != true || !mounted) return;
        await Navigator.pushNamed(context, '/print_test_screen');
        if (!_printer.isConnected) return;
      }
    }

    try {
      await AdvanceSlipPrint.printSlip(printerService: _printer, slip: slip);
    } catch (e) {
      if (mounted) _snack('Print failed: ${friendlyError(e)}', error: true);
    }
  }

  Future<void> _setPrint(bool value) async {
    await AdvanceSlipPrint.setOn(value);
    if (mounted) setState(() => _printSlip = value);
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
  }

  /* -------------------------------- UI ---------------------------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Teacher Advance'),
        actions: [
          IconButton(
            tooltip: _printSlip ? 'Slip printing: on' : 'Slip printing: off',
            icon: Icon(_printSlip ? Icons.print_rounded : Icons.print_disabled_rounded),
            onPressed: () => _showPrintSetting(),
          ),
        ],
      ),
      body: _body(),
    );
  }

  Future<void> _showPrintSetting() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Advance slip', style: Theme.of(context).textTheme.titleMedium),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Print a slip after each advance'),
                  subtitle: const Text('Teacher name, amount, date, who gave it and a line to sign. For this phone.'),
                  value: _printSlip,
                  onChanged: (value) async {
                    await _setPrint(value);
                    setSheet(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _list == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_list == null && _branchChoices.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Select a branch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final b in _branchChoices)
            Card(
              child: ListTile(
                leading: const Icon(Icons.store_rounded),
                title: Text(b.name),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _chooseBranch(b),
              ),
            ),
        ],
      );
    }

    final list = _list;
    if (list == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(_error ?? 'Could not load the teachers.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final q = _search.text.trim().toLowerCase();
    final teachers = list.teachers
        .where((t) => q.isEmpty || t.name.toLowerCase().contains(q) || t.customId.toLowerCase().contains(q))
        .toList();

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${list.branch.name} · ${list.month}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (_branchChoices.length > 1)
                    TextButton.icon(
                      onPressed: () => setState(() => _list = null),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Branch'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'The advance is taken from this month\'s salary. To change or remove one, use the web.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (_lastSlip != null) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_lastSlip!.reference} · ${_lastSlip!.teacherName} · ${money(_lastSlip!.amount)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _print(_lastSlip!),
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('Print'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search teacher',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              if (teachers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No teachers.', textAlign: TextAlign.center),
                ),
              for (final t in teachers) _TeacherTile(teacher: t, money: money, onPay: () => _pay(t)),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
      ],
    );
  }
}

class _TeacherTile extends StatelessWidget {
  final TeacherAdvanceTeacher teacher;
  final String Function(double) money;
  final VoidCallback onPay;

  const _TeacherTile({required this.teacher, required this.money, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final canPay = !teacher.salaryPaid && teacher.available > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(teacher.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (teacher.customId.isNotEmpty)
                    Text(teacher.customId, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text('Earned ${money(teacher.gross)} · Advances ${money(teacher.advance)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    teacher.salaryPaid ? 'Salary already paid this month' : 'Available ${money(teacher.available)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: canPay ? AppColors.successText : AppColors.dangerText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: canPay ? onPay : null, child: const Text('Pay')),
          ],
        ),
      ),
    );
  }
}

class _AdvanceInput {
  final double amount;
  final String? reason;
  final String? note;

  const _AdvanceInput(this.amount, this.reason, this.note);
}

class _AdvanceSheet extends StatefulWidget {
  final TeacherAdvanceTeacher teacher;
  final String month;

  const _AdvanceSheet({required this.teacher, required this.month});

  @override
  State<_AdvanceSheet> createState() => _AdvanceSheetState();
}

class _AdvanceSheetState extends State<_AdvanceSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.teacher.available;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.teacher.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Available for ${widget.month}: ${_TeacherAdvancePageState.money(available)}',
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              decoration: const InputDecoration(labelText: 'Amount (LKR)', border: OutlineInputBorder()),
              validator: (value) {
                final amount = double.tryParse(value ?? '') ?? 0;
                if (amount <= 0) return 'Enter the amount.';
                if (amount > available + 0.001) {
                  return 'Not more than ${_TeacherAdvancePageState.money(available)}.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reason,
              maxLength: 150,
              decoration: const InputDecoration(labelText: 'Reason (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _note,
              maxLength: 400,
              decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.payments_rounded),
              label: const Text('Continue'),
              onPressed: () {
                if (!(_form.currentState?.validate() ?? false)) return;
                Navigator.pop(
                  context,
                  _AdvanceInput(double.parse(_amount.text), _reason.text, _note.text),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
