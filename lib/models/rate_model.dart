import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// RATE LINE ITEM DEFINITION
//
// Describes one editable rate field: its Firestore key, its
// display label (matching the real SORECO bill wording), which
// section of the bill it belongs to, and whether it is a flat
// peso fee (charged once per bill) instead of a per-kWh rate.
// ============================================================

enum RateSection { charges, vat, universal, other, footer }

class RateLineItemDef {
  final String key;
  final String label;
  final RateSection section;
  final bool isFlat;

  const RateLineItemDef({
    required this.key,
    required this.label,
    required this.section,
    this.isFlat = false,
  });
}

class RateModel {
  // ----------------------------------------------------------
  // CHARGES (₱ per kWh, except meteringRetailCustMo which is flat)
  // ----------------------------------------------------------
  final double generationSystem;
  final double transmissionSystem;
  final double transmissionAncillary;
  final double systemLossCharge;
  final double distributionSystem;
  final double supplyRetailSystem;
  final double meteringRetailSystem;
  final double meteringRetailCustMo;
  final double lifelineSubs;
  final double rfsc;

  // ----------------------------------------------------------
  // VALUE ADDED TAX (₱ per kWh)
  // ----------------------------------------------------------
  final double generationVat;
  final double transmissionVat;
  final double transAncillaryVat;
  final double systemLossVat;
  final double distributionVat;
  final double otherVat;

  // ----------------------------------------------------------
  // UNIVERSAL CHARGES (₱ per kWh)
  // ----------------------------------------------------------
  final double environmentalCharge;
  final double missionaryElectrification;
  final double npcStrandedDebts;
  final double fitAllRenewable;

  // ----------------------------------------------------------
  // OTHER CHARGES (₱ per kWh)
  // ----------------------------------------------------------
  final double rec;
  final double seniorCitizenSubs;

  // ----------------------------------------------------------
  // FOOTER (flat ₱ fee, added after "Current Bill")
  // ----------------------------------------------------------
  final double insurance;

  final String updatedBy;
  final Timestamp updatedAt;

  const RateModel({
    required this.generationSystem,
    required this.transmissionSystem,
    required this.transmissionAncillary,
    required this.systemLossCharge,
    required this.distributionSystem,
    required this.supplyRetailSystem,
    required this.meteringRetailSystem,
    required this.meteringRetailCustMo,
    required this.lifelineSubs,
    required this.rfsc,
    required this.generationVat,
    required this.transmissionVat,
    required this.transAncillaryVat,
    required this.systemLossVat,
    required this.distributionVat,
    required this.otherVat,
    required this.environmentalCharge,
    required this.missionaryElectrification,
    required this.npcStrandedDebts,
    required this.fitAllRenewable,
    required this.rec,
    required this.seniorCitizenSubs,
    required this.insurance,
    required this.updatedBy,
    required this.updatedAt,
  });

  // ============================================================
  // LINE ITEM DEFINITIONS
  //
  // Drives both the Rate Management form and the bill breakdown
  // calculator, so every screen iterates the same source of truth
  // instead of hand-listing fields in multiple places.
  // ============================================================

  static const List<RateLineItemDef> lineItems = [
    RateLineItemDef(key: 'generationSystem', label: 'Generation System', section: RateSection.charges),
    RateLineItemDef(key: 'transmissionSystem', label: 'Transmission System', section: RateSection.charges),
    RateLineItemDef(key: 'transmissionAncillary', label: 'Transmission Ancillary', section: RateSection.charges),
    RateLineItemDef(key: 'systemLossCharge', label: 'System Loss Charge', section: RateSection.charges),
    RateLineItemDef(key: 'distributionSystem', label: 'Distribution System', section: RateSection.charges),
    RateLineItemDef(key: 'supplyRetailSystem', label: 'Supply Retail System', section: RateSection.charges),
    RateLineItemDef(key: 'meteringRetailSystem', label: 'Metering Retail System', section: RateSection.charges),
    RateLineItemDef(key: 'meteringRetailCustMo', label: 'Metering Retail/Cust/Mo', section: RateSection.charges, isFlat: true),
    RateLineItemDef(key: 'lifelineSubs', label: 'Lifeline Subs', section: RateSection.charges),
    RateLineItemDef(key: 'rfsc', label: 'RFSC', section: RateSection.charges),

    RateLineItemDef(key: 'generationVat', label: 'Generation VAT', section: RateSection.vat),
    RateLineItemDef(key: 'transmissionVat', label: 'Transmission VAT', section: RateSection.vat),
    RateLineItemDef(key: 'transAncillaryVat', label: 'Trans. Ancillary VAT', section: RateSection.vat),
    RateLineItemDef(key: 'systemLossVat', label: 'System Loss VAT', section: RateSection.vat),
    RateLineItemDef(key: 'distributionVat', label: 'Distribution VAT', section: RateSection.vat),
    RateLineItemDef(key: 'otherVat', label: 'Other VAT', section: RateSection.vat),

    RateLineItemDef(key: 'environmentalCharge', label: 'Environmental Charge', section: RateSection.universal),
    RateLineItemDef(key: 'missionaryElectrification', label: 'Missionary Electrification', section: RateSection.universal),
    RateLineItemDef(key: 'npcStrandedDebts', label: 'NPC Stranded Debts', section: RateSection.universal),
    RateLineItemDef(key: 'fitAllRenewable', label: 'FIT-ALL (Renewable)', section: RateSection.universal),

    RateLineItemDef(key: 'rec', label: 'REC', section: RateSection.other),
    RateLineItemDef(key: 'seniorCitizenSubs', label: 'Senior Citizen Subs', section: RateSection.other),

    RateLineItemDef(key: 'insurance', label: 'Insurance', section: RateSection.footer, isFlat: true),
  ];

  // Default values seeded from the sample SORECO bill (kept as
  // fallbacks so a missing/partial Firestore doc still produces a
  // sensible, non-zero bill instead of erroring or reading as 0).
  static const Map<String, double> defaults = {
    'generationSystem': 7.0796,
    'transmissionSystem': 0.6643,
    'transmissionAncillary': 0.8727,
    'systemLossCharge': 1.0016,
    'distributionSystem': 0.8449,
    'supplyRetailSystem': 0.7732,
    'meteringRetailSystem': 0.4569,
    'meteringRetailCustMo': 5.00,
    'lifelineSubs': 0.0100,
    'rfsc': 0.4004,
    'generationVat': 0.7723,
    'transmissionVat': 0.0639,
    'transAncillaryVat': 0.0648,
    'systemLossVat': 0.1086,
    'distributionVat': 0.3014,
    'otherVat': 0.1077,
    'environmentalCharge': 0.0025,
    'missionaryElectrification': 0.2763,
    'npcStrandedDebts': 0.0428,
    'fitAllRenewable': 0.2011,
    'rec': 0.0095,
    'seniorCitizenSubs': 0.0009,
    'insurance': 5.00,
  };

  double valueFor(String key) {
    switch (key) {
      case 'generationSystem': return generationSystem;
      case 'transmissionSystem': return transmissionSystem;
      case 'transmissionAncillary': return transmissionAncillary;
      case 'systemLossCharge': return systemLossCharge;
      case 'distributionSystem': return distributionSystem;
      case 'supplyRetailSystem': return supplyRetailSystem;
      case 'meteringRetailSystem': return meteringRetailSystem;
      case 'meteringRetailCustMo': return meteringRetailCustMo;
      case 'lifelineSubs': return lifelineSubs;
      case 'rfsc': return rfsc;
      case 'generationVat': return generationVat;
      case 'transmissionVat': return transmissionVat;
      case 'transAncillaryVat': return transAncillaryVat;
      case 'systemLossVat': return systemLossVat;
      case 'distributionVat': return distributionVat;
      case 'otherVat': return otherVat;
      case 'environmentalCharge': return environmentalCharge;
      case 'missionaryElectrification': return missionaryElectrification;
      case 'npcStrandedDebts': return npcStrandedDebts;
      case 'fitAllRenewable': return fitAllRenewable;
      case 'rec': return rec;
      case 'seniorCitizenSubs': return seniorCitizenSubs;
      case 'insurance': return insurance;
      default: return 0;
    }
  }

  factory RateModel.fromMap(Map<String, dynamic> map) {
    double field(String key) =>
        (map[key] as num?)?.toDouble() ?? defaults[key]!;

    return RateModel(
      generationSystem: field('generationSystem'),
      transmissionSystem: field('transmissionSystem'),
      transmissionAncillary: field('transmissionAncillary'),
      systemLossCharge: field('systemLossCharge'),
      distributionSystem: field('distributionSystem'),
      supplyRetailSystem: field('supplyRetailSystem'),
      meteringRetailSystem: field('meteringRetailSystem'),
      meteringRetailCustMo: field('meteringRetailCustMo'),
      lifelineSubs: field('lifelineSubs'),
      rfsc: field('rfsc'),
      generationVat: field('generationVat'),
      transmissionVat: field('transmissionVat'),
      transAncillaryVat: field('transAncillaryVat'),
      systemLossVat: field('systemLossVat'),
      distributionVat: field('distributionVat'),
      otherVat: field('otherVat'),
      environmentalCharge: field('environmentalCharge'),
      missionaryElectrification: field('missionaryElectrification'),
      npcStrandedDebts: field('npcStrandedDebts'),
      fitAllRenewable: field('fitAllRenewable'),
      rec: field('rec'),
      seniorCitizenSubs: field('seniorCitizenSubs'),
      insurance: field('insurance'),
      updatedBy: map['updatedBy'] ?? '',
      updatedAt: map['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  factory RateModel.fromValuesMap(
    Map<String, double> values, {
    required String updatedBy,
    Timestamp? updatedAt,
  }) {
    return RateModel.fromMap({
      ...values,
      'updatedBy': updatedBy,
      'updatedAt': updatedAt ?? Timestamp.now(),
    });
  }

  static RateModel defaultRate() => RateModel.fromMap(const {});

  Map<String, dynamic> toMap() {
    return {
      for (final item in lineItems) item.key: valueFor(item.key),
      'updatedBy': updatedBy,
      'updatedAt': updatedAt,
    };
  }
}
