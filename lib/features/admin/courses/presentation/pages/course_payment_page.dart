import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/errors/error_message.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/printer_service.dart';
import '../../data/course_api.dart';
import '../../data/course_models.dart';
import '../../utils/course_receipt_print.dart';
import '../widgets/course_ui.dart';
import 'course_scan_page.dart';

/// Course Payment button: scan a student, take a course payment (receipt is
/// printed), or enroll them in a course.
class CoursePaymentPage extends StatefulWidget {
  const CoursePaymentPage({super.key});

  @override
  State<CoursePaymentPage> createState() => _CoursePaymentPageState();
}

class _CoursePaymentPageState extends State<CoursePaymentPage> {
  final CourseApi _api = const CourseApi();
  final PrinterService _printer = PrinterService();

  String? _code;
  bool _scanned = true;
  CourseStudentResult? _data;
  CourseReceipt? _lastReceipt;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    final result = await Navigator.push<CourseScanResult>(
      context,
      MaterialPageRoute(builder: (_) => const CourseScanPage(title: 'Course payment')),
    );

    if (result == null || !mounted) return;

    _code = result.code;
    _scanned = result.scanned;
    _lastReceipt = null;
    await _load();
  }

  Future<void> _load() async {
    final code = _code;
    if (code == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.student(code);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _data = null;
        _error = friendlyError(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /* ------------------------------- Pay ---------------------------------- */

  Future<void> _pay(CourseEnrollmentItem enrollment) async {
    final input = await showModalBottomSheet<_PayInput>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PaySheet(
        enrollment: enrollment,
        methods: _data?.paymentMethods ?? const ['cash'],
      ),
    );

    if (input == null || !mounted) return;

    setState(() => _loading = true);

    try {
      final receipt = await _api.pay(
        enrollmentId: enrollment.id,
        amount: input.amount,
        paymentMethod: input.method,
        scanned: _scanned,
      );

      if (!mounted) return;
      setState(() => _lastReceipt = receipt);
      CourseUi.snack(context, 'Payment saved. Receipt ${receipt.receiptNumber}.');

      await _printReceipt(receipt);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      CourseUi.snack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _printReceipt(CourseReceipt receipt) async {
    if (!_printer.isConnected) {
      final reconnected = await _printer.autoReconnect();

      if (!reconnected) {
        if (!mounted) return;
        final connect = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Printer not connected'),
            content: Text('Receipt ${receipt.receiptNumber} is saved. Connect the printer to print it now?'),
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
      await CourseReceiptPrint.printReceipt(printerService: _printer, receipt: receipt);
    } catch (e) {
      if (mounted) CourseUi.snack(context, 'Print failed: ${friendlyError(e)}', error: true);
    }
  }

  /* ------------------------------ Enroll -------------------------------- */

  Future<void> _enroll(CourseItem course) async {
    final input = await showModalBottomSheet<_EnrollInput>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EnrollSheet(course: course),
    );

    final code = _code;
    if (input == null || code == null || !mounted) return;

    setState(() => _loading = true);

    try {
      await _api.enroll(
        courseId: course.id,
        code: code,
        paymentPlan: input.plan,
        specialFee: input.specialFee,
        specialFeeReason: input.reason,
      );

      if (!mounted) return;
      CourseUi.snack(context, 'Enrolled in ${course.name}.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      CourseUi.snack(context, friendlyError(e), error: true);
    }
  }

  /* -------------------------------- UI ---------------------------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Course Payment')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _scan,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: Text(_data == null ? 'Scan student' : 'Next student'),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = _data;

    if (data == null) {
      return CourseMessage(
        icon: _error == null ? Icons.qr_code_2_rounded : Icons.error_outline_rounded,
        message: _error ?? 'Scan the student\'s QR code to start.',
        onRetry: _error == null || _code == null ? null : _load,
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              _StudentCard(student: data.student),
              const SizedBox(height: 16),
              if (_lastReceipt != null) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: AppColors.success),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_lastReceipt!.receiptNumber} · ${CourseUi.money(_lastReceipt!.amount)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _printReceipt(_lastReceipt!),
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('Reprint'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (data.enrollments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Not in any course yet.', style: TextStyle(color: AppColors.textSecondary)),
                ),
              for (final enrollment in data.enrollments) ...[
                _EnrollmentCard(enrollment: enrollment, onPay: () => _pay(enrollment)),
                const SizedBox(height: 12),
              ],
              if (data.availableCourses.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Join a course', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                for (final course in data.availableCourses) ...[
                  _AvailableCourseCard(course: course, onEnroll: () => _enroll(course)),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        ),
        if (_loading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

/* ============================== Widgets ================================== */

class _StudentCard extends StatelessWidget {
  final CourseStudent student;

  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white,
            child: Text(
              student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  '${student.customId}${student.guardianMobile != null ? ' · ${student.guardianMobile}' : ''}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnrollmentCard extends StatelessWidget {
  final CourseEnrollmentItem enrollment;
  final VoidCallback onPay;

  const _EnrollmentCard({required this.enrollment, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final fees = enrollment.fees;
    final next = fees.next;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(enrollment.courseName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(
            '${enrollment.courseCode} · ${enrollment.paymentPlan == 'full' ? 'Pays at once' : 'Installments'}'
            '${fees.specialFee ? ' · Special fee (${fees.feeReason ?? ''})' : ''}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _amount('Fee', fees.totalFee),
              _amount('Paid', fees.paid, color: AppColors.success),
              _amount('Balance', fees.balance, color: fees.balance > 0 ? AppColors.danger : AppColors.success),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Installment ${next.number}: ${CourseUi.money(next.remaining)} · due ${next.dueDate}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                CourseStatusChip(next.status),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: fees.balance > 0
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                    onPressed: onPay,
                    icon: const Icon(Icons.payments_rounded),
                    label: const Text('Take payment'),
                  )
                : const Center(
                    child: Text('Fully paid', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _amount(String label, double value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text(CourseUi.money(value), style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _AvailableCourseCard extends StatelessWidget {
  final CourseItem course;
  final VoidCallback onEnroll;

  const _AvailableCourseCard({required this.course, required this.onEnroll});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(course.schedule, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '${course.installmentCount} × ${CourseUi.money(course.installmentAmount)} or ${CourseUi.money(course.oneTimeFee)} at once',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onEnroll, child: const Text('Enroll')),
        ],
      ),
    );
  }
}

/* ============================== Pay sheet ================================ */

class _PayInput {
  final double amount;
  final String method;

  const _PayInput(this.amount, this.method);
}

class _PaySheet extends StatefulWidget {
  final CourseEnrollmentItem enrollment;
  final List<String> methods;

  const _PaySheet({required this.enrollment, required this.methods});

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  late final TextEditingController _amount;
  late String _method = widget.methods.contains('cash') ? 'cash' : widget.methods.first;
  String? _error;

  CourseFees get _fees => widget.enrollment.fees;

  @override
  void initState() {
    super.initState();
    final suggested = _fees.next?.remaining ?? _fees.balance;
    _amount = TextEditingController(text: suggested.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_amount.text.trim());

    if (value == null || value <= 0) {
      setState(() => _error = 'Enter the amount.');
      return;
    }

    if (value > _fees.balance) {
      setState(() => _error = 'More than the balance (${CourseUi.money(_fees.balance)}).');
      return;
    }

    Navigator.pop(context, _PayInput(value, _method));
  }

  @override
  Widget build(BuildContext context) {
    final next = _fees.next;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.enrollment.courseName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('Balance ${CourseUi.money(_fees.balance)}', style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                labelText: 'Amount (Rs.)',
                errorText: _error,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (next != null)
                  ActionChip(
                    label: Text('Installment ${next.number}: ${CourseUi.money(next.remaining)}'),
                    onPressed: () => _amount.text = next.remaining.toStringAsFixed(2),
                  ),
                ActionChip(
                  label: Text('Full balance: ${CourseUi.money(_fees.balance)}'),
                  onPressed: () => _amount.text = _fees.balance.toStringAsFixed(2),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: InputDecoration(
                labelText: 'Method',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                for (final m in widget.methods)
                  DropdownMenuItem(value: m, child: Text(m.replaceAll('_', ' ').toUpperCase())),
              ],
              onChanged: (value) => setState(() => _method = value ?? _method),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _submit,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save & print receipt'),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================= Enroll sheet ============================== */

class _EnrollInput {
  final String plan;
  final double? specialFee;
  final String? reason;

  const _EnrollInput(this.plan, this.specialFee, this.reason);
}

class _EnrollSheet extends StatefulWidget {
  final CourseItem course;

  const _EnrollSheet({required this.course});

  @override
  State<_EnrollSheet> createState() => _EnrollSheetState();
}

class _EnrollSheetState extends State<_EnrollSheet> {
  String _plan = 'installment';
  bool _special = false;
  final TextEditingController _fee = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  String? _feeError;
  String? _reasonError;

  @override
  void dispose() {
    _fee.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_special) {
      Navigator.pop(context, _EnrollInput(_plan, null, null));
      return;
    }

    final fee = double.tryParse(_fee.text.trim());
    setState(() {
      _feeError = fee == null || fee < 0 ? 'Enter the fee (0 = free).' : null;
      _reasonError = _reason.text.trim().isEmpty ? 'Give a reason.' : null;
    });

    if (_feeError != null || _reasonError != null) return;

    Navigator.pop(context, _EnrollInput(_plan, fee, _reason.text.trim()));
  }

  Widget _planTile({required String value, required String title, required String subtitle}) {
    final selected = _plan == value;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => setState(() => _plan = value),
      leading: Icon(
        selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
        color: selected ? AppColors.primary : AppColors.textMuted,
      ),
      title: Text(title, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
      subtitle: Text(subtitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.course;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Enroll in ${c.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(c.schedule, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 12),
              _planTile(
                value: 'installment',
                title: '${c.installmentCount} installments',
                subtitle: '${CourseUi.money(c.installmentAmount)} a month · total ${CourseUi.money(c.fullFee)}',
              ),
              _planTile(
                value: 'full',
                title: 'Pay at once',
                subtitle: CourseUi.money(c.oneTimeFee),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _special,
                onChanged: (value) => setState(() => _special = value),
                title: const Text('Special fee'),
                subtitle: const Text('A different fee for this student'),
              ),
              if (_special) ...[
                TextField(
                  controller: _fee,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: InputDecoration(
                    labelText: 'Fee for this student (Rs.)',
                    helperText: _plan == 'installment' ? 'Split over ${c.installmentCount} months' : 'Paid at once',
                    errorText: _feeError,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _reason,
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    hintText: 'Staff child, scholarship ...',
                    errorText: _reasonError,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _submit,
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Enroll'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
