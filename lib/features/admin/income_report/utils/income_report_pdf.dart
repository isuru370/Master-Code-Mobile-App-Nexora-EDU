import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../../core/institute/institute_info.dart';
import '../data/income_report_api.dart';

/// A4 PDF of the Income Report (one day or a range), shared with the
/// phone's share sheet (WhatsApp, email, Drive, save to files ...).
class IncomeReportPdf {
  const IncomeReportPdf._();

  static final NumberFormat _money = NumberFormat('#,##0.00');
  static final DateFormat _file = DateFormat('yyyy-MM-dd');

  static String rangeLabel(IncomeReport r) {
    final day = DateFormat('d MMM yyyy');
    return r.isOneDay ? day.format(r.from) : '${day.format(r.from)} - ${day.format(r.to)}';
  }

  static Future<void> share(IncomeReport report) async {
    final bytes = await build(report);

    final dir = await getTemporaryDirectory();
    final name = report.isOneDay
        ? 'income_${_file.format(report.from)}.pdf'
        : 'income_${_file.format(report.from)}_to_${_file.format(report.to)}.pdf';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        text: '${InstituteInfo.name} - Income Report ${rangeLabel(report)}',
      ),
    );
  }

  static Future<Uint8List> build(IncomeReport r) async {
    final doc = pw.Document();
    final printedAt = DateFormat('d MMM yyyy, h:mm a').format(DateTime.now());
    final hasCourses = r.courseFees != null;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 34),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text('${InstituteInfo.name}  |  Income Report ${rangeLabel(r)}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text('Printed $printedAt  |  Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ),
        build: (context) => [
          _header(r),
          pw.SizedBox(height: 14),
          _netBoxes(r),
          pw.SizedBox(height: 14),
          _title('Summary'),
          _summary(r),
          if (r.classFeesByMethod.length > 1) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Class fees by payment method:  ' +
                  r.classFeesByMethod.entries.map((e) => '${_label(e.key)} Rs. ${_money.format(e.value)}').join('   |   '),
              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
            ),
          ],
          if (!r.isOneDay && r.days.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _title('Day by day'),
            _daysTable(r, hasCourses),
          ],
          if (r.expenseItems.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _title('Expenses (${r.expenseItems.length})'),
            _itemsTable('Reason', r.expenseItems),
          ],
          if (r.advanceItems.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _title('Teacher advances (${r.advanceItems.length})'),
            _itemsTable('Teacher', r.advanceItems),
          ],
          if (r.extraItems.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _title('Extra income (${r.extraItems.length})'),
            _itemsTable('Reason', r.extraItems),
          ],
          pw.SizedBox(height: 36),
          _signatures(),
        ],
      ),
    );

    return doc.save();
  }

  /* ------------------------------------------------------------------ */

  static pw.Widget _header(IncomeReport r) => pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(color: PdfColors.blue900, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(InstituteInfo.name,
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.SizedBox(height: 4),
                  pw.Text('Income Report', style: const pw.TextStyle(fontSize: 12, color: PdfColors.blue100)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(r.isOneDay ? DateFormat('EEEE').format(r.from) : 'Date range',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.blue100)),
                pw.Text(rangeLabel(r),
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.Text(r.branch.isEmpty ? 'All branches' : 'Branch: ${r.branch}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue100)),
              ],
            ),
          ],
        ),
      );

  static pw.Widget _netBoxes(IncomeReport r) {
    pw.Widget box(String label, double value, PdfColor color) => pw.Expanded(
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
                pw.Text('Rs. ${_money.format(value)}',
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
              ],
            ),
          ),
        );

    return pw.Row(children: [
      box('Total income', r.totalIncome, PdfColors.green800),
      box('Total expenses', r.totalExpenses, PdfColors.red800),
      box('Net total', r.net, r.net < 0 ? PdfColors.red800 : PdfColors.blue900),
    ]);
  }

  static pw.Widget _title(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _summary(IncomeReport r) {
    final bold = pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold);
    const normal = pw.TextStyle(fontSize: 9.5);
    const sub = pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700);

    pw.TableRow row(String label, String amount, {pw.TextStyle? style, PdfColor? background}) =>
        pw.TableRow(
          decoration: background == null ? null : pw.BoxDecoration(color: background),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: pw.Text(label, style: style ?? normal)),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: pw.Text(amount, style: style ?? normal, textAlign: pw.TextAlign.right),
            ),
          ],
        );

    String rs(double v) => 'Rs. ${_money.format(v)}';

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1.4)},
      children: [
        row('INCOME', '', style: bold, background: PdfColors.grey200),
        row('Class fees (${r.classFees.count} payments)', rs(r.classFees.amount)),
        if (r.hallFee > 0) row('    of which hall fees (${r.hallFeeCount} payments)', rs(r.hallFee), style: sub),
        if (r.courseFees != null) row('Course fees (${r.courseFees!.count} payments)', rs(r.courseFees!.amount)),
        row('Admission fees (${r.admission.count})', rs(r.admission.amount)),
        row('Extra income (${r.extraIncome.count})', rs(r.extraIncome.amount)),
        row('Total income', rs(r.totalIncome), style: bold),
        row('EXPENSES', '', style: bold, background: PdfColors.grey200),
        row('Institute expenses (${r.expenses.count})', rs(r.expenses.amount)),
        row('Teacher advances (${r.teacherAdvances.count})', rs(r.teacherAdvances.amount)),
        row('Total expenses', rs(r.totalExpenses), style: bold),
        row('NET TOTAL (income - expenses)', rs(r.net),
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold), background: PdfColors.blue50),
      ],
    );
  }

  static pw.Widget _daysTable(IncomeReport r, bool hasCourses) {
    String m(double v) => v == 0 ? '-' : _money.format(v);
    final d = DateFormat('d MMM, EEE');

    final headers = ['Date', 'Class fees', if (hasCourses) 'Courses', 'Admission', 'Extra', 'Expenses', 'Advances', 'Net'];

    double sum(double Function(IncomeDay) f) => r.days.fold<double>(0, (s, x) => s + f(x));

    final data = <List<String>>[
      for (final day in r.days)
        [
          DateTime.tryParse(day.date) == null ? day.date : d.format(DateTime.parse(day.date)),
          m(day.classFees),
          if (hasCourses) m(day.courseFees),
          m(day.admission),
          m(day.extraIncome),
          m(day.expenses),
          m(day.teacherAdvances),
          _money.format(day.net),
        ],
      [
        'Total',
        _money.format(sum((x) => x.classFees)),
        if (hasCourses) _money.format(sum((x) => x.courseFees)),
        _money.format(sum((x) => x.admission)),
        _money.format(sum((x) => x.extraIncome)),
        _money.format(sum((x) => x.expenses)),
        _money.format(sum((x) => x.teacherAdvances)),
        _money.format(sum((x) => x.net)),
      ],
    ];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignments: {for (var i = 1; i < headers.length; i++) i: pw.Alignment.centerRight},
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    );
  }

  static pw.Widget _itemsTable(String titleHeader, List<IncomeItem> items) {
    final total = items.fold<double>(0, (s, x) => s + x.amount);

    return pw.TableHelper.fromTextArray(
      headers: ['Date', titleHeader, 'Note', 'Amount (Rs.)'],
      data: [
        for (final item in items) [item.date, item.title, item.note, _money.format(item.amount)],
        ['', 'Total', '', _money.format(total)],
      ],
      headerStyle: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      cellAlignments: {3: pw.Alignment.centerRight},
      columnWidths: {
        0: const pw.FixedColumnWidth(62),
        1: const pw.FlexColumnWidth(2.2),
        2: const pw.FlexColumnWidth(2.2),
        3: const pw.FixedColumnWidth(72),
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    );
  }

  static pw.Widget _signatures() {
    pw.Widget line(String label) => pw.Expanded(
          child: pw.Column(children: [
            pw.Container(height: 0.6, color: PdfColors.grey600, margin: const pw.EdgeInsets.symmetric(horizontal: 16)),
            pw.SizedBox(height: 3),
            pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
          ]),
        );

    return pw.Row(children: [line('Prepared by'), line('Checked by')]);
  }

  static String _label(String method) {
    if (method.isEmpty) return '-';
    final text = method.replaceAll('_', ' ');
    return text[0].toUpperCase() + text.substring(1);
  }
}
