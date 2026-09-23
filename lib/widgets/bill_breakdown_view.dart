import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:soreconnect/utils/bill_calculator.dart';

// ============================================================
// BILL BREAKDOWN VIEW
//
// Renders an itemized bill in the same style as the real SORECO
// "Notice of Billing" receipt: a Charges block, then VALUE ADDED
// TAX / UNIVERSAL CHARGES / OTHER CHARGES sections, each row
// showing its Rate/kWh and Amount, followed by Current Bill,
// Insurance, Adjustments and the Total Amount Due. When a due date
// is supplied, a Notice of Disconnection is rendered below it.
//
// Shared across the meter reading preview, the consumer bill view,
// the teller verification screen, and the director monitoring
// screen so every surface renders the same breakdown consistently.
// ============================================================

// Disconnection is posted 2 days after the due date, matching the
// real SORECO Notice of Disconnection (e.g. due Wed → disconnection
// effective the following Friday).
const Duration disconnectionGracePeriod = Duration(days: 2);

class BillBreakdownView extends StatelessWidget {
  const BillBreakdownView({
    super.key,
    required this.breakdown,
    required this.previousReading,
    required this.currentReading,
    required this.consumption,
    this.municipality,
    this.dueDate,
    this.initiallyExpanded = false,
  });

  final BillBreakdown breakdown;
  final double previousReading;
  final double currentReading;
  final double consumption;

  // Payment Center shown on the bill — the consumer's municipality.
  final String? municipality;

  // Used to compute and display the Notice of Disconnection date.
  final DateTime? dueDate;

  final bool initiallyExpanded;

  String _peso(double value) => value < 0
      ? '-₱${(-value).toStringAsFixed(2)}'
      : '₱${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (municipality != null && municipality!.isNotEmpty)
                      _readingRow('Payment Center', municipality!),
                    _readingRow('Previous Reading', '${previousReading.toStringAsFixed(1)} kWh'),
                    _readingRow('Current Reading', '${currentReading.toStringAsFixed(1)} kWh'),
                    _readingRow('KWH Used', consumption.toStringAsFixed(1)),
                  ],
                ),
              ),
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  initiallyExpanded: initiallyExpanded,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  title: const Text(
                    'Itemized Breakdown',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  children: [
                    _lineItemHeaderRow(),
                    const SizedBox(height: 4),
                    for (final section in breakdown.sections) ...[
                      if (section.title != null && section.title!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${section.title}:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      for (final item in section.items) _lineItemRow(item),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.05),
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Column(
                  children: [
                    _totalRow('Current Bill', breakdown.currentBill),
                    if (breakdown.adjustments != 0)
                      _totalRow('Adjustments', breakdown.adjustments),
                    for (final item in breakdown.footerItems)
                      _totalRow(item.label, item.amount),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL AMOUNT DUE',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          _peso(breakdown.totalAmount),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (dueDate != null) ...[
          const SizedBox(height: 12),
          DisconnectionNoticeCard(dueDate: dueDate!),
        ],
      ],
    );
  }

  Widget _readingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _lineItemHeaderRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              'Charges',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Rate/kWh',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Amount',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineItemRow(BillLineItem item) {
    final rateLabel = item.rate == null
        ? ''
        : item.isFlat
            ? 'flat'
            : item.rate!.toStringAsFixed(4);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              item.label,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              rateLabel,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _peso(item.amount),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          Text(_peso(amount),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ============================================================
// DISCONNECTION NOTICE CARD
//
// Standalone so it can also be shown alongside the legacy flat
// bill display (bills generated before itemized breakdowns).
// ============================================================

class DisconnectionNoticeCard extends StatelessWidget {
  const DisconnectionNoticeCard({super.key, required this.dueDate});

  final DateTime dueDate;

  @override
  Widget build(BuildContext context) {
    final disconnectionDate = dueDate.add(disconnectionGracePeriod);
    final formatted =
        DateFormat('MMMM d, yyyy (EEEE)').format(disconnectionDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.power_off, color: Colors.red.shade700, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOTICE OF DISCONNECTION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.red.shade800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Disconnection of Electric Service will be effective '
                  'on $formatted if amount due is not paid.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.red.shade900,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
