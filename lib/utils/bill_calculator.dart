import 'package:soreconnect/models/rate_model.dart';

// ============================================================
// BILL LINE ITEM
//
// One row of the itemized bill. `rate` is null for manually
// entered amounts (e.g. Interest) that aren't rate × consumption.
// ============================================================

class BillLineItem {
  final String key;
  final String label;
  final double? rate;
  final double amount;
  final bool isFlat;

  const BillLineItem({
    required this.key,
    required this.label,
    required this.rate,
    required this.amount,
    this.isFlat = false,
  });

  Map<String, dynamic> toMap() => {
        'key': key,
        'label': label,
        'rate': rate,
        'amount': amount,
        'isFlat': isFlat,
      };

  factory BillLineItem.fromMap(Map<String, dynamic> map) {
    return BillLineItem(
      key: map['key'] ?? '',
      label: map['label'] ?? '',
      rate: (map['rate'] as num?)?.toDouble(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      isFlat: map['isFlat'] ?? false,
    );
  }
}

// ============================================================
// BILL SECTION
//
// A titled group of line items ("VALUE ADDED TAX:", etc). `title`
// is null for the main, untitled charges block.
// ============================================================

class BillSection {
  final String? title;
  final List<BillLineItem> items;

  const BillSection({required this.title, required this.items});

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.amount);

  Map<String, dynamic> toMap() => {
        'title': title,
        'items': items.map((item) => item.toMap()).toList(),
      };

  factory BillSection.fromMap(Map<String, dynamic> map) {
    return BillSection(
      title: map['title'],
      items: (map['items'] as List? ?? [])
          .map((item) => BillLineItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

// ============================================================
// BILL BREAKDOWN
//
// The full itemized bill, frozen at the moment it's computed so
// later rate changes never alter a bill that's already been
// generated.
// ============================================================

class BillBreakdown {
  final List<BillSection> sections;
  final double currentBill;
  final double insurance;
  final double adjustments;
  final double interest;
  final double totalAmount;

  const BillBreakdown({
    required this.sections,
    required this.currentBill,
    required this.insurance,
    required this.adjustments,
    required this.interest,
    required this.totalAmount,
  });

  Map<String, dynamic> toMap() => {
        'sections': sections.map((section) => section.toMap()).toList(),
        'currentBill': currentBill,
        'insurance': insurance,
        'adjustments': adjustments,
        'interest': interest,
        'totalAmount': totalAmount,
      };

  factory BillBreakdown.fromMap(Map<String, dynamic> map) {
    return BillBreakdown(
      sections: (map['sections'] as List? ?? [])
          .map((section) =>
              BillSection.fromMap(Map<String, dynamic>.from(section)))
          .toList(),
      currentBill: (map['currentBill'] as num?)?.toDouble() ?? 0,
      insurance: (map['insurance'] as num?)?.toDouble() ?? 0,
      adjustments: (map['adjustments'] as num?)?.toDouble() ?? 0,
      interest: (map['interest'] as num?)?.toDouble() ?? 0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

String _sectionTitle(RateSection section) {
  switch (section) {
    case RateSection.vat:
      return 'VALUE ADDED TAX';
    case RateSection.universal:
      return 'UNIVERSAL CHARGES';
    case RateSection.other:
      return 'OTHER CHARGES';
    case RateSection.charges:
    case RateSection.footer:
      return '';
  }
}

// ============================================================
// COMPUTE BILL BREAKDOWN
//
// consumption = currentReading - previousReading. Every rate line
// (except the flat fees marked `isFlat`) is rate × consumption,
// matching the real SORECO bill's computation style. Interest and
// Adjustments are manual, one-off amounts entered at billing time
// rather than standing rates.
// ============================================================

BillBreakdown computeBillBreakdown({
  required RateModel rate,
  required double consumption,
  double interest = 0,
  double adjustments = 0,
}) {
  final Map<RateSection, List<BillLineItem>> grouped = {
    RateSection.charges: [],
    RateSection.vat: [],
    RateSection.universal: [],
    RateSection.other: [],
  };

  for (final def in RateModel.lineItems) {
    if (def.section == RateSection.footer) continue;

    final rateValue = rate.valueFor(def.key);
    final amount = def.isFlat ? rateValue : rateValue * consumption;

    grouped[def.section]!.add(BillLineItem(
      key: def.key,
      label: def.label,
      rate: rateValue,
      amount: amount,
      isFlat: def.isFlat,
    ));
  }

  // Interest is a manual, non-rate amount but is shown inside the
  // "Other Charges" section on the real bill.
  grouped[RateSection.other]!.add(BillLineItem(
    key: 'interest',
    label: 'Interest',
    rate: null,
    amount: interest,
    isFlat: true,
  ));

  final sections = [
    BillSection(title: null, items: grouped[RateSection.charges]!),
    BillSection(
        title: _sectionTitle(RateSection.vat), items: grouped[RateSection.vat]!),
    BillSection(
        title: _sectionTitle(RateSection.universal),
        items: grouped[RateSection.universal]!),
    BillSection(
        title: _sectionTitle(RateSection.other), items: grouped[RateSection.other]!),
  ];

  final currentBill =
      sections.fold(0.0, (sum, section) => sum + section.subtotal);

  final insurance = rate.insurance;
  final totalAmount = currentBill + insurance + adjustments;

  return BillBreakdown(
    sections: sections,
    currentBill: currentBill,
    insurance: insurance,
    adjustments: adjustments,
    interest: interest,
    totalAmount: totalAmount,
  );
}
