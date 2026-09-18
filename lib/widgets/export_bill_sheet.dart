import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:soreconnect/utils/bill_calculator.dart';
import 'package:soreconnect/utils/bill_receipt_pdf.dart';

// ============================================================
// EXPORT BILL SHEET
//
// A small bottom sheet letting the user pick between saving the
// bill as a PDF or as a PNG image. Both formats are generated from
// the same PDF receipt (`buildBillReceiptPdf`) so the layout is
// defined once; the PNG is rasterized from the PDF's first page.
//
// Files are shared straight from in-memory bytes via
// `XFile.fromData` rather than written to a temp file first —
// `path_provider` has no filesystem to write to on Flutter Web, so
// writing a temp file breaks there. Sharing bytes directly works
// uniformly across web, Android, and iOS, and is how the user
// actually saves/downloads the bill.
// ============================================================

Future<void> showExportBillOptions(
  BuildContext context, {
  required Map<String, dynamic> bill,
  required BillBreakdown? breakdown,
  required String ticketNumber,
  bool includeDisconnectionNotice = false,
}) async {
  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Export Bill',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Save as PDF'),
                subtitle: const Text('Printable document, matches the official receipt'),
                onTap: () => _exportPdf(
                  sheetContext,
                  bill: bill,
                  breakdown: breakdown,
                  ticketNumber: ticketNumber,
                  includeDisconnectionNotice: includeDisconnectionNotice,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Save as Image (PNG)'),
                subtitle: const Text('Easy to view or share as a photo'),
                onTap: () => _exportPng(
                  sheetContext,
                  bill: bill,
                  breakdown: breakdown,
                  ticketNumber: ticketNumber,
                  includeDisconnectionNotice: includeDisconnectionNotice,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _exportPdf(
  BuildContext context, {
  required Map<String, dynamic> bill,
  required BillBreakdown? breakdown,
  required String ticketNumber,
  required bool includeDisconnectionNotice,
}) async {
  Navigator.of(context).pop();

  final messenger = ScaffoldMessenger.maybeOf(context);

  try {
    final bytes = await buildBillReceiptPdf(
      bill: bill,
      breakdown: breakdown,
      ticketNumber: ticketNumber,
      includeDisconnectionNotice: includeDisconnectionNotice,
    );

    final fileName = 'SORECO_Bill_$ticketNumber.pdf';

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name: fileName,
          ),
        ],
        fileNameOverrides: [fileName],
      ),
    );
  } catch (e) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Could not export PDF: $e')),
    );
  }
}

Future<void> _exportPng(
  BuildContext context, {
  required Map<String, dynamic> bill,
  required BillBreakdown? breakdown,
  required String ticketNumber,
  required bool includeDisconnectionNotice,
}) async {
  Navigator.of(context).pop();

  final messenger = ScaffoldMessenger.maybeOf(context);

  try {
    final pdfBytes = await buildBillReceiptPdf(
      bill: bill,
      breakdown: breakdown,
      ticketNumber: ticketNumber,
      includeDisconnectionNotice: includeDisconnectionNotice,
    );

    final pages = Printing.raster(pdfBytes, pages: [0], dpi: 203);
    final raster = await pages.first;
    final pngImage = await raster.toPng();

    final fileName = 'SORECO_Bill_$ticketNumber.png';

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            pngImage,
            mimeType: 'image/png',
            name: fileName,
          ),
        ],
        fileNameOverrides: [fileName],
      ),
    );
  } catch (e) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Could not export image: $e')),
    );
  }
}
