import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:soreconnect/utils/bill_calculator.dart';
import 'package:soreconnect/widgets/bill_breakdown_view.dart'
    show disconnectionGracePeriod;

// ============================================================
// BILL RECEIPT PDF
//
// Builds a narrow, thermal-receipt-style PDF mirroring the real
// SORECO "Notice of Billing" slip: cooperative letterhead, account
// block, reading table, itemized charge breakdown, and payment
// reminder. Only renders fields the app actually tracks — no
// fabricated multiplier, "Type", or multi-month arrears data.
//
// This PDF is also the single source of truth for the PNG export
// (the caller rasterizes the first page via `Printing.raster`),
// so the layout only needs to be defined once.
// ============================================================

const double _receiptWidthMm = 80;
const double _receiptHeightMm = 320;

String _peso(double value) =>
    value < 0 ? '-P${(-value).toStringAsFixed(2)}' : 'P${value.toStringAsFixed(2)}';

DateTime? _asDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String _formatDate(DateTime? date, {String pattern = 'MMM d, yyyy'}) {
  if (date == null) return '-';
  return DateFormat(pattern).format(date);
}

Future<Uint8List> buildBillReceiptPdf({
  required Map<String, dynamic> bill,
  required BillBreakdown? breakdown,
  required String ticketNumber,
  bool includeDisconnectionNotice = false,
}) async {
  final doc = pw.Document();

  // Built-in core PDF fonts (embedded, no network fetch) — Courier
  // gives the receipt its typewriter/thermal-printer feel.
  final font = pw.Font.courier();
  final fontBold = pw.Font.courierBold();

  final consumerName = (bill['consumerName'] ?? '-').toString();
  final accountNumber = (bill['accountNumber'] ?? '-').toString();
  final meterNumber = (bill['meterNumber'] ?? '-').toString();
  final billingPeriod = (bill['billingPeriod'] ?? '-').toString();
  final municipality = (bill['municipality'] ?? '').toString();

  final addressParts = [
    (bill['barangay'] ?? '').toString(),
    municipality,
    (bill['province'] ?? '').toString(),
  ].where((part) => part.trim().isNotEmpty).toList();

  final address = (bill['address'] ?? '').toString().trim().isNotEmpty
      ? (bill['address'] as String).trim()
      : addressParts.join(', ');

  final previousReading =
      ((bill['previousReading'] as num?) ?? 0).toDouble();
  final currentReading = ((bill['currentReading'] as num?) ?? 0).toDouble();
  final consumption = ((bill['consumption'] as num?) ?? 0).toDouble();
  final ratePerKwh = ((bill['ratePerKwh'] as num?) ?? 0).toDouble();
  final totalAmount = ((bill['totalAmount'] as num?) ?? 0).toDouble();

  final paymentStartDate = _asDate(bill['paymentStartDate']);
  final dueDate = _asDate(bill['dueDate']);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat(
        _receiptWidthMm * PdfPageFormat.mm,
        _receiptHeightMm * PdfPageFormat.mm,
        marginAll: 4 * PdfPageFormat.mm,
      ),
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      build: (context) => [
        pw.Center(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'SORSOGON II ELECTRIC COOPERATIVE, INC.',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Gulang-Gulang, Irosin, Sorsogon',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 7),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'NOTICE OF BILLING',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Bill Month: $billingPeriod',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        _dashedDivider(),
        pw.SizedBox(height: 4),

        // ACCOUNT BLOCK
        _kv('Acct #', accountNumber),
        _kv('Meter #', meterNumber),
        _kv('Name', consumerName),
        if (address.isNotEmpty) _kv('Address', address),

        pw.SizedBox(height: 6),
        _dashedDivider(),
        pw.SizedBox(height: 4),

        // READING BLOCK
        _kvAmount('Previous Reading', '${previousReading.toStringAsFixed(1)} kWh'),
        _kvAmount('Current Reading', '${currentReading.toStringAsFixed(1)} kWh'),
        _kvAmount('KWH Used', consumption.toStringAsFixed(1)),

        pw.SizedBox(height: 6),
        _dashedDivider(),
        pw.SizedBox(height: 4),

        if (breakdown != null) ...[
          for (final section in breakdown.sections) ...[
            if (section.title != null && section.title!.isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                '${section.title}:',
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
            ],
            for (final item in section.items) _lineItemRow(item),
          ],
          pw.SizedBox(height: 4),
          _dashedDivider(),
          pw.SizedBox(height: 4),
          _kvAmount('Current Bill', _peso(breakdown.currentBill)),
          if (breakdown.adjustments != 0)
            _kvAmount('Adjustments', _peso(breakdown.adjustments)),
          for (final item in breakdown.footerItems)
            _kvAmount(item.label, _peso(item.amount)),
          pw.SizedBox(height: 4),
          _dashedDivider(),
          pw.SizedBox(height: 4),
          _kvAmount(
            'TOTAL AMOUNT DUE',
            _peso(breakdown.totalAmount),
            bold: true,
            fontSize: 9,
          ),
        ] else ...[
          // Legacy bill without a stored breakdown.
          _kvAmount('Rate per kWh', _peso(ratePerKwh)),
          pw.SizedBox(height: 4),
          _dashedDivider(),
          pw.SizedBox(height: 4),
          _kvAmount('TOTAL AMOUNT DUE', _peso(totalAmount), bold: true, fontSize: 9),
        ],

        pw.SizedBox(height: 8),
        _dashedDivider(),
        pw.SizedBox(height: 4),

        // PAYMENT REMINDER
        pw.Text(
          'PAYMENT REMINDER:',
          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        if (municipality.isNotEmpty) _kv('Payment Center', municipality),
        _kv('Payment Start', _formatDate(paymentStartDate)),
        _kv('Due Date', _formatDate(dueDate)),

        if (includeDisconnectionNotice && dueDate != null) ...[
          pw.SizedBox(height: 10),
          _dashedDivider(),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text(
              'NOTICE OF DISCONNECTION',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Disconnection of Electric Service will be effective on '
            '${_formatDate(dueDate.add(disconnectionGracePeriod), pattern: 'MMMM d, yyyy (EEEE)')} '
            'if amount due is not paid.',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7.5),
          ),
        ],

        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text(
            'Ticket #$ticketNumber',
            style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
          ),
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _dashedDivider() {
  return pw.Container(
    height: 0.6,
    color: PdfColors.grey500,
  );
}

pw.Widget _kv(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Text(
      '$label: $value',
      style: const pw.TextStyle(fontSize: 7.5),
    ),
  );
}

pw.Widget _kvAmount(
  String label,
  String value, {
  bool bold = false,
  double fontSize = 7.5,
}) {
  final style = pw.TextStyle(
    fontSize: fontSize,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );

  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(value, style: style),
      ],
    ),
  );
}

pw.Widget _lineItemRow(BillLineItem item) {
  final rateLabel = item.rate == null
      ? ''
      : item.isFlat
          ? 'flat'
          : item.rate!.toStringAsFixed(4);

  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 1.5),
    child: pw.Row(
      children: [
        pw.Expanded(
          flex: 5,
          child: pw.Text(item.label, style: const pw.TextStyle(fontSize: 7)),
        ),
        pw.Expanded(
          flex: 3,
          child: pw.Text(
            rateLabel,
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
          ),
        ),
        pw.Expanded(
          flex: 3,
          child: pw.Text(
            _peso(item.amount),
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 7),
          ),
        ),
      ],
    ),
  );
}
