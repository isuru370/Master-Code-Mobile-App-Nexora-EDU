import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../../../../core/institute/institute_info.dart';
import '../../../data/models/today_payments/today_payment_item_model.dart';

/// A4 PDF of the payments shown on the Today Payments page (one date),
/// shared with the phone's share sheet (WhatsApp, email, Drive ...).
class TodayPaymentsPdf {
  const TodayPaymentsPdf._();

  static final NumberFormat _money = NumberFormat('#,##0.00');

  /// Builds the PDF, saves it in the app's temp folder and opens the share sheet.
  static Future<void> share({
    required DateTime date,
    required List<TodayPaymentItemModel> payments,
    String? search,
  }) async {
    final bytes = await build(date: date, payments: payments, search: search);

    final dir = await getTemporaryDirectory();
    final day = DateFormat('yyyy-MM-dd').format(date);
    final file = File('${dir.path}/payments_$day.pdf');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        text: '${InstituteInfo.name} - Payments ${DateFormat('d MMM yyyy').format(date)}',
      ),
    );
  }

  static Future<Uint8List> build({
    required DateTime date,
    required List<TodayPaymentItemModel> payments,
    String? search,
  }) async {
    final doc = pw.Document();

    final total = payments.fold<double>(0, (sum, p) => sum + p.amount);
    final discount = payments.fold<double>(0, (sum, p) => sum + p.discountAmount);

    // Class-wise totals
    final byClass = <String, _Group>{};
    for (final p in payments) {
      final name = p.studentClass.className.isEmpty ? '-' : p.studentClass.className;
      final group = byClass.putIfAbsent(name, () => _Group(name));
      group.count++;
      group.amount += p.amount;
    }
    final classRows = byClass.values.toList()..sort((a, b) => a.name.compareTo(b.name));

    // Payment method totals
    final byMethod = <String, double>{};
    for (final p in payments) {
      final method = _label(p.paymentMethod);
      byMethod[method] = (byMethod[method] ?? 0) + p.amount;
    }

    final printedAt = DateFormat('d MMM yyyy, h:mm a').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 34),
        header: (context) => context.pageNumber == 1 ? pw.SizedBox() : _smallHeader(date),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Printed $printedAt  |  Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          _header(date, search),
          pw.SizedBox(height: 14),
          _summary(payments.length, total, discount, byMethod),
          pw.SizedBox(height: 16),
          if (classRows.isNotEmpty) ...[
            _title('By class'),
            _classTable(classRows, total),
            pw.SizedBox(height: 16),
          ],
          _title('Payments (${payments.length})'),
          payments.isEmpty
              ? pw.Padding(
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Text('No payments on this day.'),
                )
              : _paymentsTable(payments, total),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _header(DateTime date, String? search) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue900,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  InstituteInfo.name,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Payments Report',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.blue100),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                DateFormat('EEEE').format(date),
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.blue100),
              ),
              pw.Text(
                DateFormat('d MMMM yyyy').format(date),
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              ),
              if (search != null && search.trim().isNotEmpty)
                pw.Text(
                  'Search: ${search.trim()}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue100),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _smallHeader(DateTime date) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        '${InstituteInfo.name}  |  Payments ${DateFormat('d MMM yyyy').format(date)}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    );
  }

  static pw.Widget _summary(int count, double total, double discount, Map<String, double> byMethod) {
    pw.Widget box(String label, String value, {PdfColor color = PdfColors.blue900}) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            margin: const pw.EdgeInsets.symmetric(horizontal: 3),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                pw.SizedBox(height: 3),
                pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
              ],
            ),
          ),
        );

    return pw.Column(
      children: [
        pw.Row(
          children: [
            box('Payments', '$count'),
            box('Total collected (LKR)', _money.format(total), color: PdfColors.green800),
            box('Discounts (LKR)', _money.format(discount), color: PdfColors.orange800),
          ],
        ),
        if (byMethod.length > 1) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            byMethod.entries.map((e) => '${e.key}: LKR ${_money.format(e.value)}').join('   |   '),
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
        ],
      ],
    );
  }

  static pw.Widget _title(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      );

  static const _headStyle = pw.TextStyle(fontSize: 8, color: PdfColors.white);
  static const _cellStyle = pw.TextStyle(fontSize: 8.5);

  static pw.Widget _classTable(List<_Group> rows, double total) {
    return pw.TableHelper.fromTextArray(
      headers: ['Class', 'Payments', 'Amount (LKR)'],
      data: [
        ...rows.map((g) => [g.name, '${g.count}', _money.format(g.amount)]),
        ['Total', '${rows.fold<int>(0, (s, g) => s + g.count)}', _money.format(total)],
      ],
      headerStyle: _headStyle,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: _cellStyle,
      cellAlignments: {1: pw.Alignment.center, 2: pw.Alignment.centerRight},
      columnWidths: {0: const pw.FlexColumnWidth(4), 1: const pw.FlexColumnWidth(1.2), 2: const pw.FlexColumnWidth(1.8)},
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    );
  }

  static pw.Widget _paymentsTable(List<TodayPaymentItemModel> payments, double total) {
    final sorted = [...payments]..sort((a, b) => a.paidAt.compareTo(b.paidAt));

    return pw.TableHelper.fromTextArray(
      headers: ['#', 'Time', 'Receipt', 'Student', 'Class', 'Month', 'Method', 'Amount'],
      data: [
        for (var i = 0; i < sorted.length; i++)
          [
            '${i + 1}',
            _time(sorted[i].paidAt),
            sorted[i].receiptNumber,
            '${sorted[i].student.qrCode}\n${sorted[i].student.initialName}',
            sorted[i].studentClass.className,
            _month(sorted[i].paymentMonth),
            _label(sorted[i].paymentMethod),
            _money.format(sorted[i].amount) +
                (sorted[i].discountAmount > 0 ? '\n(disc. ${_money.format(sorted[i].discountAmount)})' : ''),
          ],
        ['', '', '', 'Total', '', '', '', _money.format(total)],
      ],
      headerStyle: _headStyle,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellStyle: _cellStyle,
      cellAlignments: {0: pw.Alignment.center, 7: pw.Alignment.centerRight},
      columnWidths: {
        0: const pw.FixedColumnWidth(18),
        1: const pw.FixedColumnWidth(38),
        2: const pw.FixedColumnWidth(58),
        3: const pw.FlexColumnWidth(2.4),
        4: const pw.FlexColumnWidth(2.4),
        5: const pw.FixedColumnWidth(46),
        6: const pw.FixedColumnWidth(38),
        7: const pw.FixedColumnWidth(58),
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    );
  }

  static String _time(String paidAt) {
    final value = DateTime.tryParse(paidAt.replaceFirst(' ', 'T'));
    return value == null ? '' : DateFormat('h:mm a').format(value);
  }

  static String _month(String paymentMonth) {
    if (paymentMonth.length < 7) return paymentMonth;
    final value = DateTime.tryParse('${paymentMonth.substring(0, 7)}-01');
    return value == null ? paymentMonth : DateFormat('MMM yyyy').format(value);
  }

  static String _label(String method) {
    if (method.isEmpty) return '-';
    final text = method.replaceAll('_', ' ');
    return text[0].toUpperCase() + text.substring(1);
  }
}

class _Group {
  _Group(this.name);

  final String name;
  int count = 0;
  double amount = 0;
}
