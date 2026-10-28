import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/institute/institute_info.dart';
import '../../../../core/utils/printer_service.dart';
import '../data/teacher_advance_api.dart';

/// 58mm teacher advance slip (same printer as the payment receipts), with a
/// line for the teacher to sign. Printing can be switched off per phone.
class AdvanceSlipPrint {
  const AdvanceSlipPrint._();

  static const String _kPrint = 'teacher_advance_print_slip';

  /// Print a slip after paying (default on).
  static Future<bool> isOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPrint) ?? true;
  }

  static Future<void> setOn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrint, value);
  }

  static Future<void> printSlip({
    required PrinterService printerService,
    required TeacherAdvanceSlip slip,
    PaperSize paperSize = PaperSize.mm58,
  }) async {
    final bytes = await build(slip: slip, paperSize: paperSize);
    await printerService.printData(bytes);
  }

  static Future<List<int>> build({
    required TeacherAdvanceSlip slip,
    PaperSize paperSize = PaperSize.mm58,
  }) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(paperSize, profile);
    final bytes = <int>[];

    String money(double value) => 'LKR ${value.toStringAsFixed(2)}';

    List<int> pair(String label, String value, {bool bold = false}) => g.row([
          PosColumn(text: label, width: 5, styles: PosStyles(bold: bold)),
          PosColumn(text: value, width: 7, styles: PosStyles(align: PosAlign.right, bold: bold)),
        ]);

    bytes.addAll(g.reset());

    bytes.addAll(g.text(
      InstituteInfo.name.toUpperCase(),
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
    ));
    if (slip.branchName.isNotEmpty) {
      bytes.addAll(g.text(slip.branchName, styles: const PosStyles(align: PosAlign.center)));
    }
    bytes.addAll(g.text('TEACHER ADVANCE', styles: const PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(g.hr());

    bytes.addAll(g.text('Ref  : ${slip.reference}'));
    bytes.addAll(g.text('Date : ${slip.date}  ${slip.time}'));
    bytes.addAll(g.hr());

    bytes.addAll(g.text('TEACHER', styles: const PosStyles(bold: true)));
    bytes.addAll(g.text('Name : ${slip.teacherName}'));
    if (slip.teacherCustomId.isNotEmpty) {
      bytes.addAll(g.text('ID   : ${slip.teacherCustomId}'));
    }
    bytes.addAll(g.hr());

    bytes.addAll(pair('ADVANCE', money(slip.amount), bold: true));
    if (slip.reason != null) {
      bytes.addAll(g.text('Reason: ${slip.reason}'));
    }
    if (slip.note != null) {
      bytes.addAll(g.text('Note  : ${slip.note}'));
    }
    bytes.addAll(g.hr(ch: '-'));
    bytes.addAll(g.text(slip.month, styles: const PosStyles(bold: true)));
    bytes.addAll(pair('Advances', money(slip.monthAdvanceTotal)));
    bytes.addAll(pair('Still available', money(slip.availableAfter)));
    bytes.addAll(g.hr());

    if (slip.paidBy != null) {
      bytes.addAll(g.text('Given by: ${slip.paidBy}'));
    }
    bytes.addAll(g.feed(2));
    bytes.addAll(g.text('................................', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.text('Teacher signature', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.feed(1));
    bytes.addAll(g.text('Deducted from the ${slip.month} salary.',
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.feed(1));
    bytes.addAll(g.cut());

    return bytes;
  }
}
