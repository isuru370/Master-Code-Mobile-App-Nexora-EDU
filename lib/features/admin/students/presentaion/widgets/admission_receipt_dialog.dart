import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/printer_service.dart';
import '../../data/models/create_student/create_student_response_model.dart';
import 'admission_receipt_print.dart';

/// Shown after a student is registered WITH an admission payment.
///
/// - Prints the receipt automatically as soon as it opens
///   (reconnects to the saved printer first if needed).
/// - If printing fails: shows why, with "Print Again" and "Connect Printer".
/// - Closes with the button [doneLabel]; the caller continues after `await`.
Future<void> showAdmissionReceiptDialog({
  required BuildContext context,
  required CreateStudentResponseModel response,
  String doneLabel = 'Done',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _AdmissionReceiptDialog(response: response, doneLabel: doneLabel),
  );
}

enum _PrintStatus { printing, printed, failed }

class _AdmissionReceiptDialog extends StatefulWidget {
  final CreateStudentResponseModel response;
  final String doneLabel;

  const _AdmissionReceiptDialog({
    required this.response,
    required this.doneLabel,
  });

  @override
  State<_AdmissionReceiptDialog> createState() =>
      _AdmissionReceiptDialogState();
}

class _AdmissionReceiptDialogState extends State<_AdmissionReceiptDialog> {
  final PrinterService _printerService = PrinterService();

  _PrintStatus _status = _PrintStatus.printing;
  String? _error;

  AdmissionPaymentPrintModel get _payment => widget.response.admissionPayment!;

  @override
  void initState() {
    super.initState();
    // Print automatically once the dialog is on screen
    WidgetsBinding.instance.addPostFrameCallback((_) => _print());
  }

  Future<void> _print() async {
    setState(() {
      _status = _PrintStatus.printing;
      _error = null;
    });

    try {
      if (!_printerService.isConnected) {
        final connected = await _printerService.autoReconnect();
        if (!connected) {
          throw Exception('Printer not connected');
        }
      }

      final student = widget.response.student;

      await AdmissionReceiptPrint.printReceipt(
        printerService: _printerService,
        instituteName: AdmissionReceiptPrint.defaultInstituteName,
        receiptNumber: _payment.receiptNumber,
        studentName: student.initialName,
        studentId: student.customId ?? '-',
        admissionName: _payment.admissionName,
        amount: double.tryParse(_payment.amount) ?? 0,
        paymentMethod: _payment.paymentMethod,
        paidAt: _payment.paidAt,
      );

      if (!mounted) return;
      setState(() => _status = _PrintStatus.printed);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _PrintStatus.failed;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _connectPrinter() async {
    await Navigator.pushNamed(context, '/print_test_screen');
    if (!mounted) return;

    if (_printerService.isConnected) {
      await _print();
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.response.student;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(Icons.receipt_long_rounded, color: AppColors.success),
          const SizedBox(width: 10),
          const Expanded(child: Text('Admission Receipt')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line('Receipt No', _payment.receiptNumber),
          _line('Student', '${student.initialName} (${student.customId ?? '-'})'),
          _line('Admission', _payment.admissionName),
          _line('Amount', 'Rs. ${_payment.amount}'),
          _line('Method', _payment.paymentMethod),
          _line('Paid At', _payment.paidAt),
          const SizedBox(height: 14),
          _statusBox(),
        ],
      ),
      actions: [
        if (_status == _PrintStatus.failed)
          TextButton.icon(
            onPressed: _connectPrinter,
            icon: const Icon(Icons.bluetooth_rounded),
            label: const Text('Connect Printer'),
          ),
        if (_status != _PrintStatus.printing)
          TextButton.icon(
            onPressed: _print,
            icon: const Icon(Icons.print_rounded),
            label: Text(
              _status == _PrintStatus.printed ? 'Print Again' : 'Print',
            ),
          ),
        ElevatedButton(
          onPressed: _status == _PrintStatus.printing
              ? null
              : () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.doneLabel),
        ),
      ],
    );
  }

  Widget _statusBox() {
    final (Color bg, Color fg, Widget icon, String text) = switch (_status) {
      _PrintStatus.printing => (
        AppColors.infoLight,
        const Color(0xFF0369A1),
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        'Printing receipt...',
      ),
      _PrintStatus.printed => (
        AppColors.successLight,
        AppColors.success,
        const Icon(Icons.check_circle_rounded, color: AppColors.success),
        'Receipt printed',
      ),
      _PrintStatus.failed => (
        AppColors.dangerLight,
        AppColors.danger,
        const Icon(Icons.print_disabled_rounded, color: AppColors.danger),
        'Not printed: ${_error ?? 'Unknown error'}',
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
