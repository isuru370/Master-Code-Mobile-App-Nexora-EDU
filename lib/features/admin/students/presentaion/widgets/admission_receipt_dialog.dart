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
  final payment = response.admissionPayment!;

  return showReceiptDialog(
    context: context,
    doneLabel: doneLabel,
    receipt: ReceiptDialogData(
      title: 'Admission Receipt',
      itemLabel: 'Admission',
      receiptNumber: payment.receiptNumber,
      studentName: response.student.initialName,
      studentId: response.student.customId ?? '-',
      itemName: payment.admissionName,
      amount: double.tryParse(payment.amount) ?? 0,
      paymentMethod: payment.paymentMethod,
      paidAt: payment.paidAt,
    ),
  );
}

/// What the receipt dialog shows and prints (admission, card fee ...)
class ReceiptDialogData {
  final String title;
  final String itemLabel;
  final String receiptNumber;
  final String studentName;
  final String studentId;
  final String itemName;
  final double amount;
  final String paymentMethod;
  final String paidAt;

  const ReceiptDialogData({
    required this.title,
    required this.itemLabel,
    required this.receiptNumber,
    required this.studentName,
    required this.studentId,
    required this.itemName,
    required this.amount,
    required this.paymentMethod,
    required this.paidAt,
  });
}

/// Receipt dialog that prints automatically (any admission-type payment)
Future<void> showReceiptDialog({
  required BuildContext context,
  required ReceiptDialogData receipt,
  String doneLabel = 'Done',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _AdmissionReceiptDialog(receipt: receipt, doneLabel: doneLabel),
  );
}

enum _PrintStatus { printing, printed, failed }

class _AdmissionReceiptDialog extends StatefulWidget {
  final ReceiptDialogData receipt;
  final String doneLabel;

  const _AdmissionReceiptDialog({
    required this.receipt,
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

  ReceiptDialogData get _receipt => widget.receipt;

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

      await AdmissionReceiptPrint.printReceipt(
        printerService: _printerService,
        instituteName: AdmissionReceiptPrint.defaultInstituteName,
        receiptNumber: _receipt.receiptNumber,
        studentName: _receipt.studentName,
        studentId: _receipt.studentId,
        admissionName: _receipt.itemName,
        amount: _receipt.amount,
        paymentMethod: _receipt.paymentMethod,
        paidAt: _receipt.paidAt,
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          const Icon(Icons.receipt_long_rounded, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(child: Text(_receipt.title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line('Receipt No', _receipt.receiptNumber),
          _line('Student', '${_receipt.studentName} (${_receipt.studentId})'),
          _line(_receipt.itemLabel, _receipt.itemName),
          _line('Amount', 'Rs. ${_receipt.amount.toStringAsFixed(2)}'),
          _line('Method', _receipt.paymentMethod),
          _line('Paid At', _receipt.paidAt),
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
        borderRadius: BorderRadius.circular(12),
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
