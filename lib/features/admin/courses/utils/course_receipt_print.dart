import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../../../../core/utils/printer_service.dart';
import '../data/course_models.dart';

/// 58mm course payment receipt (same printer as class payment receipts).
class CourseReceiptPrint {
  const CourseReceiptPrint._();

  static Future<void> printReceipt({
    required PrinterService printerService,
    required CourseReceipt receipt,
    PaperSize paperSize = PaperSize.mm58,
  }) async {
    final bytes = await build(receipt: receipt, paperSize: paperSize);
    await printerService.printData(bytes);
  }

  static Future<List<int>> build({
    required CourseReceipt receipt,
    PaperSize paperSize = PaperSize.mm58,
  }) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(paperSize, profile);
    final bytes = <int>[];

    String money(double value) => 'LKR ${value.toStringAsFixed(2)}';

    List<int> pair(String label, String value, {bool bold = false}) => g.row([
          PosColumn(text: label, width: 5, styles: PosStyles(bold: bold)),
          PosColumn(
            text: value,
            width: 7,
            styles: PosStyles(align: PosAlign.right, bold: bold),
          ),
        ]);

    bytes.addAll(g.reset());

    bytes.addAll(g.text(
      receipt.instituteName.toUpperCase(),
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
    ));
    if (receipt.branch != null) {
      bytes.addAll(g.text(receipt.branch!, styles: const PosStyles(align: PosAlign.center)));
    }
    bytes.addAll(g.text(receipt.title, styles: const PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(g.hr());

    if (receipt.status == 'cancelled') {
      bytes.addAll(g.text('*** CANCELLED ***', styles: const PosStyles(align: PosAlign.center, bold: true)));
      bytes.addAll(g.hr(ch: '-'));
    }

    bytes.addAll(g.text('Receipt: ${receipt.receiptNumber}'));
    bytes.addAll(g.text('Date   : ${receipt.paidAt}'));
    bytes.addAll(g.text('Method : ${receipt.paymentMethod.replaceAll('_', ' ').toUpperCase()}'));
    bytes.addAll(g.hr());

    bytes.addAll(g.text('STUDENT', styles: const PosStyles(bold: true)));
    bytes.addAll(g.text('Name : ${receipt.studentName}'));
    bytes.addAll(g.text('ID   : ${receipt.studentId}'));
    bytes.addAll(g.hr());

    bytes.addAll(g.text(receipt.courseName, styles: const PosStyles(bold: true)));
    if (receipt.courseCode.isNotEmpty) {
      bytes.addAll(g.text('Code : ${receipt.courseCode}'));
    }
    bytes.addAll(pair('PAID', money(receipt.amount), bold: true));
    bytes.addAll(g.hr(ch: '-'));

    bytes.addAll(pair(receipt.specialFeeReason != null ? 'Special fee' : 'Course fee', money(receipt.courseFee)));
    if (receipt.specialFeeReason != null) {
      bytes.addAll(g.text('(${receipt.specialFeeReason})'));
    }
    bytes.addAll(pair('Total paid', money(receipt.totalPaid)));
    bytes.addAll(pair('Balance', money(receipt.balance), bold: true));
    if (receipt.nextDueDate != null && receipt.balance > 0) {
      bytes.addAll(g.text('Next due: ${receipt.nextDueDate}'
          '${receipt.nextDueAmount != null ? ' (${money(receipt.nextDueAmount!)})' : ''}'));
    }

    bytes.addAll(g.hr());
    if (receipt.takenBy != null) {
      bytes.addAll(g.text('By ${receipt.takenBy}', styles: const PosStyles(align: PosAlign.center)));
    }
    bytes.addAll(g.text('Thank You', styles: const PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(g.text('Please keep this receipt', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.feed(1));
    bytes.addAll(g.cut());

    return bytes;
  }
}
