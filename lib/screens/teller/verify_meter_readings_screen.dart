import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:soreconnect/services/rate_service.dart';
import 'package:soreconnect/data/sorsogon_address_data.dart';

class VerifyMeterReadingsScreen extends StatefulWidget {
  const VerifyMeterReadingsScreen({super.key});

  @override
  State<VerifyMeterReadingsScreen> createState() =>
      _VerifyMeterReadingsScreenState();
}

class _VerifyMeterReadingsScreenState
    extends State<VerifyMeterReadingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _processingDocId;

  // ============================================================
  // FILTERS
  // ============================================================

  String _sortOption = 'Newest';
  String _selectedStatus = 'All';
  String _selectedMonth = 'All Months';
  String _selectedMunicipality = 'All Municipalities';
  String _selectedBarangay = 'Select Municipality First';

  // ============================================================
  // MONTHS
  // ============================================================

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  DateTime? _getReadingDate(Map<String, dynamic> data) {
    return _parseDate(data['recordedAt']) ??
        _parseDate(data['createdAt']) ??
        _parseDate(data['dateCreated']) ??
        _parseDate(data['timestamp']) ??
        _parseDate(data['generatedAt']);
  }

  DateTime? _getBillDate(Map<String, dynamic> data) {
    return _parseDate(data['generatedAt']) ??
        _parseDate(data['createdAt']) ??
        _parseDate(data['dateCreated']) ??
        _parseDate(data['dueDate']);
  }

  // ============================================================
  // BILLING PERIOD
  // ============================================================

  DateTime? _getBillingPeriodDate(Map<String, dynamic> data) {
    final raw = data['billingPeriod'];

    if (raw == null) return null;

    final billingPeriod = raw.toString().trim();

    if (billingPeriod.isEmpty) return null;

    final lower = billingPeriod.toLowerCase();

    for (int i = 0; i < _monthNames.length; i++) {
      if (lower.contains(_monthNames[i].toLowerCase())) {
        int year = DateTime.now().year;

        final yearMatch =
            RegExp(r'\b20\d{2}\b').firstMatch(billingPeriod);

        if (yearMatch != null) {
          year = int.tryParse(yearMatch.group(0)!) ?? year;
        }

        return DateTime(year, i + 1, 1);
      }
    }

    final numericMatch =
        RegExp(r'^(\d{1,2})[\/\-](20\d{2})$')
            .firstMatch(billingPeriod);

    if (numericMatch != null) {
      final month = int.tryParse(numericMatch.group(1)!);
      final year = int.tryParse(numericMatch.group(2)!);

      if (month != null &&
          year != null &&
          month >= 1 &&
          month <= 12) {
        return DateTime(year, month, 1);
      }
    }

    return null;
  }

  int? _getDocumentMonth(
    Map<String, dynamic> data, {
    required bool isBill,
  }) {
    final billingDate = _getBillingPeriodDate(data);

    if (billingDate != null) {
      return billingDate.month;
    }

    final fallbackDate =
        isBill ? _getBillDate(data) : _getReadingDate(data);

    return fallbackDate?.month;
  }

  // ============================================================
  // STATUS
  // ============================================================

  String _getFirestoreStatus(Map<String, dynamic> data) {
    return (data['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
  }

  String _getDisplayStatus(
    Map<String, dynamic> data, {
    required bool isBill,
  }) {
    if (!isBill) {
      return 'Pending';
    }

    final status = _getFirestoreStatus(data);

    if (status == 'paid') {
      return 'Paid';
    }

    if (status == 'unpaid') {
      return 'Unpaid';
    }

    if (status.isEmpty) {
      return 'Unknown';
    }

    return _capitalize(status);
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;

    return value[0].toUpperCase() + value.substring(1);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'unpaid':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'verified':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // BASIC FIRESTORE FIELD HELPERS
  // ============================================================

  String _stringValue(
    Map<String, dynamic> data,
    List<String> fields, {
    String fallback = '',
  }) {
    for (final field in fields) {
      final value = data[field];

      if (value != null) {
        final text = value.toString().trim();

        if (text.isNotEmpty) {
          return text;
        }
      }
    }

    return fallback;
  }

  double _doubleValue(
    Map<String, dynamic> data,
    String field,
  ) {
    final value = data[field];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ============================================================
  // CONSUMER
  // ============================================================

  String _getConsumerName(Map<String, dynamic> data) {
    return _stringValue(
      data,
      [
        'consumerName',
        'full_name',
        'fullName',
        'name',
      ],
      fallback: 'Unknown Consumer',
    );
  }

  String _getConsumerId(Map<String, dynamic> data) {
    return _stringValue(
      data,
      [
        'consumerId',
        'uid',
        'userId',
        'consumerUID',
      ],
    );
  }

  String _getAccountNumber(Map<String, dynamic> data) {
    return _stringValue(
      data,
      [
        'accountNumber',
        'accountNo',
        'account_number',
        'account',
      ],
      fallback: 'N/A',
    );
  }

  // ============================================================
  // LOCATION
  //
  // For bills:
  // Uses the location saved in the bill.
  //
  // For pending readings:
  // The current user's profile location is merged into the
  // reading before filtering/displaying.
  // ============================================================

  String _getBarangay(Map<String, dynamic> data) {
    return _stringValue(
      data,
      [
        'barangay',
        'baranggay',
      ],
    );
  }

  String _getMunicipality(Map<String, dynamic> data) {
    return _stringValue(
      data,
      [
        'municipality',
        'city',
      ],
    );
  }

  String _getProvince(Map<String, dynamic> data) {
    return _stringValue(
      data,
      [
        'province',
      ],
      fallback: 'Sorsogon',
    );
  }

  String _getAddress(Map<String, dynamic> data) {
    return _stringValue(
      data,
      [
        'address',
      ],
    );
  }

  String _getLocationText(Map<String, dynamic> data) {
    final address = _getAddress(data);
    final barangay = _getBarangay(data);
    final municipality = _getMunicipality(data);
    final province = _getProvince(data);

    if (address.isNotEmpty) {
      return address;
    }

    final parts = <String>[];

    if (barangay.isNotEmpty) {
      parts.add(barangay);
    }

    if (municipality.isNotEmpty) {
      parts.add(municipality);
    }

    if (province.isNotEmpty) {
      parts.add(province);
    }

    if (parts.isEmpty) {
      return 'Location not available';
    }

    return parts.join(', ');
  }

  // ============================================================
  // LOCATION NORMALIZATION
  // ============================================================

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  // ============================================================
  // LOCATION FILTER
  // ============================================================

  bool _matchesLocation(
    Map<String, dynamic> data,
  ) {
    if (_selectedMunicipality == 'All Municipalities') {
      return true;
    }

    final municipality = _normalize(
      _getMunicipality(data),
    );

    final selectedMunicipality = _normalize(
      _selectedMunicipality,
    );

    if (municipality != selectedMunicipality) {
      return false;
    }

    if (_selectedBarangay == 'All Barangays') {
      return true;
    }

    if (_selectedBarangay == 'Select Municipality First') {
      return true;
    }

    final barangay = _normalize(
      _getBarangay(data),
    );

    return barangay == _normalize(
      _selectedBarangay,
    );
  }

  // ============================================================
  // MONTH FILTER
  // ============================================================

  bool _matchesMonth(
    Map<String, dynamic> data, {
    required bool isBill,
  }) {
    if (_selectedMonth == 'All Months') {
      return true;
    }

    final selectedIndex =
        _monthNames.indexOf(_selectedMonth);

    if (selectedIndex == -1) {
      return true;
    }

    final documentMonth = _getDocumentMonth(
      data,
      isBill: isBill,
    );

    return documentMonth == selectedIndex + 1;
  }

  // ============================================================
  // STATUS FILTER - BILL
  // ============================================================

  bool _matchesBillStatus(
    Map<String, dynamic> data,
  ) {
    if (_selectedStatus == 'All') {
      return true;
    }

    final status = _getFirestoreStatus(data);

    switch (_selectedStatus) {
      case 'Paid':
        return status == 'paid';

      case 'Unpaid':
        return status == 'unpaid';

      case 'Pending':
        return false;

      default:
        return false;
    }
  }

  // ============================================================
  // STATUS FILTER - READING
  // ============================================================

  bool _matchesReadingStatus(
    Map<String, dynamic> data,
  ) {
    if (_selectedStatus == 'All' ||
        _selectedStatus == 'Pending') {
      return true;
    }

    return false;
  }

  // ============================================================
  // DOCUMENT FILTER - BILLS
  // ============================================================

  List<QueryDocumentSnapshot> _filterDocuments(
    List<QueryDocumentSnapshot> documents, {
    required bool isBill,
  }) {
    return documents.where((doc) {
      final data =
          doc.data() as Map<String, dynamic>;

      if (!_matchesMonth(
        data,
        isBill: isBill,
      )) {
        return false;
      }

      if (!_matchesLocation(data)) {
        return false;
      }

      if (isBill) {
        return _matchesBillStatus(data);
      }

      return _matchesReadingStatus(data);
    }).toList();
  }

  // ============================================================
  // SORT BILLS
  // ============================================================

  List<QueryDocumentSnapshot> _sortDocuments(
    List<QueryDocumentSnapshot> documents, {
    required bool isBill,
  }) {
    final result =
        List<QueryDocumentSnapshot>.from(
      documents,
    );

    result.sort((a, b) {
      final dataA =
          a.data() as Map<String, dynamic>;

      final dataB =
          b.data() as Map<String, dynamic>;

      final dateA = isBill
          ? _getBillDate(dataA)
          : _getReadingDate(dataA);

      final dateB = isBill
          ? _getBillDate(dataB)
          : _getReadingDate(dataB);

      final actualA =
          dateA ??
              DateTime.fromMillisecondsSinceEpoch(0);

      final actualB =
          dateB ??
              DateTime.fromMillisecondsSinceEpoch(0);

      if (_sortOption == 'Newest') {
        return actualB.compareTo(actualA);
      }

      return actualA.compareTo(actualB);
    });

    return result;
  }

  // ============================================================
  // SORT PENDING READINGS
  // ============================================================

  List<_ReadingItem> _sortReadingItems(
    List<_ReadingItem> items,
  ) {
    final result =
        List<_ReadingItem>.from(items);

    result.sort((a, b) {
      final dateA =
          _getReadingDate(a.data) ??
              DateTime.fromMillisecondsSinceEpoch(0);

      final dateB =
          _getReadingDate(b.data) ??
              DateTime.fromMillisecondsSinceEpoch(0);

      if (_sortOption == 'Newest') {
        return dateB.compareTo(dateA);
      }

      return dateA.compareTo(dateB);
    });

    return result;
  }

  // ============================================================
  // LOCATION DETAILS
  // ============================================================

  Widget _buildLocationDetails(
    Map<String, dynamic> data,
  ) {
    final location = _getLocationText(data);

    return Padding(
      padding: const EdgeInsets.only(
        top: 6,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 17,
            color: Colors.orange,
          ),
          const SizedBox(width: 5),
          const Text(
            'Location: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          Expanded(
            child: Text(
              location,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GET CURRENT CONSUMER PROFILE
  // ============================================================

  Map<String, dynamic>? _findCurrentProfile(
    Map<String, dynamic> reading,
    List<QueryDocumentSnapshot> users,
  ) {
    final consumerId =
        _getConsumerId(reading);

    if (consumerId.isEmpty) {
      return null;
    }

    for (final userDoc in users) {
      final userData =
          userDoc.data()
              as Map<String, dynamic>;

      final ids = [
        userDoc.id,
        _stringValue(
          userData,
          ['uid'],
        ),
        _stringValue(
          userData,
          ['userId'],
        ),
        _stringValue(
          userData,
          ['consumerId'],
        ),
        _stringValue(
          userData,
          ['consumerUID'],
        ),
      ];

      if (ids.any(
        (id) =>
            id.isNotEmpty &&
            id == consumerId,
      )) {
        return userData;
      }
    }

    return null;
  }

  // ============================================================
  // MERGE CURRENT PROFILE LOCATION
  //
  // IMPORTANT:
  // This does NOT update Firestore.
  //
  // It only creates a temporary copy used by this screen.
  // Therefore old meter-reading records are not modified.
  // ============================================================

  Map<String, dynamic> _getCurrentReadingData(
    Map<String, dynamic> reading,
    Map<String, dynamic>? profile,
  ) {
    final result =
        Map<String, dynamic>.from(reading);

    if (profile == null) {
      return result;
    }

    final currentBarangay = _stringValue(
      profile,
      [
        'barangay',
        'baranggay',
      ],
    );

    final currentMunicipality = _stringValue(
      profile,
      [
        'municipality',
        'city',
      ],
    );

    final currentProvince = _stringValue(
      profile,
      [
        'province',
      ],
      fallback: 'Sorsogon',
    );

    final currentAddress = _stringValue(
      profile,
      [
        'address',
      ],
    );

    // Use the current profile location.
    result['barangay'] = currentBarangay;
    result['municipality'] = currentMunicipality;
    result['province'] = currentProvince;
    result['address'] = currentAddress;

    // Also use current consumer information when available.
    final currentName = _stringValue(
      profile,
      [
        'consumerName',
        'full_name',
        'fullName',
        'name',
      ],
    );

    if (currentName.isNotEmpty) {
      result['consumerName'] = currentName;
    }

    final currentAccountNumber =
        _stringValue(
      profile,
      [
        'accountNumber',
        'accountNo',
        'account_number',
        'account',
      ],
    );

    if (currentAccountNumber.isNotEmpty) {
      result['accountNumber'] =
          currentAccountNumber;
    }

    return result;
  }

  // ============================================================
  // VERIFY READING
  // ============================================================

  Future<void> _verifyReading({
    required DocumentSnapshot readingDoc,
    required Map<String, dynamic> readingData,
    required double previousReading,
    required double currentReading,
    required double consumption,
    required double ratePerKwh,
    required String billingPeriod,
    required DateTime dueDate,
    required String billStatus,
  }) async {
    final docId = readingDoc.id;

    setState(() {
      _processingDocId = docId;
    });

    try {
      // Use the CURRENT profile-enriched reading data.
      final reading = Map<String, dynamic>.from(
        readingData,
      );

      final billRef =
          _firestore.collection('bills').doc();

      final totalAmount =
          consumption * ratePerKwh;

      final consumerId =
          _getConsumerId(reading);

      final consumerName =
          _getConsumerName(reading);

      final accountNumber =
          _getAccountNumber(reading);

      final barangay =
          _getBarangay(reading);

      final municipality =
          _getMunicipality(reading);

      final province =
          _getProvince(reading);

      String address =
          _getAddress(reading);

      // Construct address only if profile does not
      // contain a complete address.
      if (address.isEmpty &&
          barangay.isNotEmpty &&
          municipality.isNotEmpty) {
        try {
          address = buildSorsogonAddress(
            municipality: municipality,
            barangay: barangay,
          );
        } catch (_) {
          address =
              '$barangay, $municipality, $province';
        }
      }

      final billData =
          <String, dynamic>{
        'billId': billRef.id,
        'consumerId': consumerId,
        'consumerName': consumerName,
        'accountNumber': accountNumber,

        // CURRENT LOCATION AT VERIFICATION TIME
        'barangay': barangay,
        'municipality': municipality,
        'province': province,
        'address': address,

        'previousReading':
            previousReading,
        'currentReading':
            currentReading,
        'consumption':
            consumption,
        'ratePerKwh':
            ratePerKwh,
        'totalAmount':
            totalAmount,

        'billingPeriod':
            billingPeriod,

        'dueDate':
            Timestamp.fromDate(dueDate),

        'status':
            billStatus.toLowerCase(),

        'generatedBy':
            _auth.currentUser?.email ??
                'Teller',

        'generatedAt':
            FieldValue.serverTimestamp(),
      };

      final batch =
          _firestore.batch();

      // ========================================================
      // CREATE BILL
      // ========================================================

      batch.set(
        billRef,
        billData,
      );

      // ========================================================
      // UPDATE READING
      //
      // Save the CURRENT location into the reading as well.
      // This keeps the reading synchronized after verification.
      // ========================================================

      batch.update(
        readingDoc.reference,
        {
          'status': 'Verified',

          'verifiedBy':
              _auth.currentUser?.email ??
                  'Teller',

          'verifiedAt':
              FieldValue.serverTimestamp(),

          'barangay':
              barangay,
          'municipality':
              municipality,
          'province':
              province,
          'address':
              address,

          'consumerId':
              consumerId,
          'accountNumber':
              accountNumber,
        },
      );

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          backgroundColor:
              Colors.green,
          content: Text(
            'Bill verified and generated successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          backgroundColor:
              Colors.red,
          content: Text(
            'Error: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingDocId = null;
        });
      }
    }
  }

  // ============================================================
  // EDIT / VERIFY DIALOG
  // ============================================================

  Future<void> _showEditBillDialog(
    DocumentSnapshot readingDoc,
    Map<String, dynamic> data,
  ) async {
    final previousController =
        TextEditingController(
      text:
          '${data['previousReading'] ?? 0}',
    );

    final currentController =
        TextEditingController(
      text:
          '${data['currentReading'] ?? 0}',
    );

    final consumptionController =
        TextEditingController(
      text:
          '${data['consumption'] ?? 0}',
    );

    final rateController =
        TextEditingController(
      text:
          '${data['ratePerKwh'] ?? 0}',
    );

    final billingPeriodController =
        TextEditingController(
      text:
          '${data['billingPeriod'] ?? ''}',
    );

    double currentRate =
        _doubleValue(
      data,
      'ratePerKwh',
    );

    if (currentRate <= 0) {
      try {
        final rateService =
            RateService();

        currentRate =
            await rateService
                .getCurrentRate();

        rateController.text =
            currentRate.toString();
      } catch (_) {}
    }

    String selectedStatus =
        'unpaid';

    final firestoreStatus =
        _getFirestoreStatus(data);

    if (firestoreStatus == 'paid' ||
        firestoreStatus == 'unpaid') {
      selectedStatus =
          firestoreStatus;
    }

    DateTime selectedDueDate =
        _parseDate(
              data['dueDate'],
            ) ??
            DateTime.now().add(
              const Duration(
                days: 15,
              ),
            );

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            double calculateTotal() {
              final consumption =
                  double.tryParse(
                        consumptionController
                            .text,
                      ) ??
                      0;

              final rate =
                  double.tryParse(
                        rateController.text,
                      ) ??
                      0;

              return consumption *
                  rate;
            }

            return AlertDialog(
              title: const Text(
                'Edit and Verify Bill',
              ),
              content:
                  SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Text(
                      _getConsumerName(
                        data,
                      ),
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      'Account #: '
                      '${_getAccountNumber(data)}',
                      style:
                          TextStyle(
                        color: Colors
                            .grey
                            .shade600,
                      ),
                    ),

                    _buildLocationDetails(
                      data,
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    TextField(
                      controller:
                          previousController,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Previous Reading',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          currentController,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Current Reading',
                        border:
                            OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        final previous =
                            double.tryParse(
                                  previousController
                                      .text,
                                ) ??
                                0;

                        final current =
                            double.tryParse(
                                  currentController
                                      .text,
                                ) ??
                                0;

                        final consumption =
                            current -
                                previous;

                        setDialogState(() {
                          consumptionController
                                  .text =
                              consumption
                                  .toStringAsFixed(
                            2,
                          );
                        });
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          consumptionController,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Consumption (kWh)',
                        border:
                            OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        setDialogState(
                          () {},
                        );
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          rateController,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Rate per kWh',
                        border:
                            OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        setDialogState(
                          () {},
                        );
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          billingPeriodController,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Billing Period',
                        border:
                            OutlineInputBorder(),
                        hintText:
                            'Example: August 2026',
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    DropdownButtonFormField<
                        String>(
                      initialValue:
                          selectedStatus,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Bill Status',
                        border:
                            OutlineInputBorder(),
                      ),
                      items:
                          const [
                        DropdownMenuItem(
                          value:
                              'unpaid',
                          child:
                              Text(
                            'Unpaid',
                          ),
                        ),
                        DropdownMenuItem(
                          value:
                              'paid',
                          child:
                              Text(
                            'Paid',
                          ),
                        ),
                      ],
                      onChanged:
                          (value) {
                        setDialogState(
                          () {
                            selectedStatus =
                                value ??
                                    'unpaid';
                          },
                        );
                      },
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    ListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      title:
                          const Text(
                        'Due Date',
                      ),
                      subtitle:
                          Text(
                        '${selectedDueDate.month}/'
                        '${selectedDueDate.day}/'
                        '${selectedDueDate.year}',
                      ),
                      trailing:
                          const Icon(
                        Icons
                            .calendar_today,
                      ),
                      onTap:
                          () async {
                        final picked =
                            await showDatePicker(
                          context:
                              context,
                          initialDate:
                              selectedDueDate,
                          firstDate:
                              DateTime.now(),
                          lastDate:
                              DateTime.now()
                                  .add(
                            const Duration(
                              days:
                                  365,
                            ),
                          ),
                        );

                        if (picked !=
                            null) {
                          setDialogState(
                            () {
                              selectedDueDate =
                                  picked;
                            },
                          );
                        }
                      },
                    ),

                    const Divider(),

                    const Text(
                      'Total Amount',
                      style:
                          TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      '₱${calculateTotal().toStringAsFixed(2)}',
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFFD32F2F,
                        ),
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 25,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                      const Text(
                    'Cancel',
                  ),
                ),

                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(
                      0xFFD32F2F,
                    ),
                    foregroundColor:
                        Colors.white,
                  ),
                  onPressed:
                      () async {
                    final previous =
                        double.tryParse(
                              previousController
                                  .text,
                            ) ??
                            0;

                    final current =
                        double.tryParse(
                              currentController
                                  .text,
                            ) ??
                            0;

                    final consumption =
                        double.tryParse(
                              consumptionController
                                  .text,
                            ) ??
                            0;

                    final rate =
                        double.tryParse(
                              rateController
                                  .text,
                            ) ??
                            0;

                    if (current <
                        previous) {
                      ScaffoldMessenger
                              .of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Current reading cannot be less than previous reading.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (consumption <
                        0) {
                      ScaffoldMessenger
                              .of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Consumption cannot be negative.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (rate <= 0) {
                      ScaffoldMessenger
                              .of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Rate must be greater than zero.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                    );

                    await _verifyReading(
                      readingDoc:
                          readingDoc,
                      readingData:
                          data,
                      previousReading:
                          previous,
                      currentReading:
                          current,
                      consumption:
                          consumption,
                      ratePerKwh:
                          rate,
                      billingPeriod:
                          billingPeriodController
                              .text
                              .trim(),
                      dueDate:
                          selectedDueDate,
                      billStatus:
                          selectedStatus,
                    );
                  },
                  child:
                      const Text(
                    'SAVE & VERIFY',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    previousController.dispose();
    currentController.dispose();
    consumptionController.dispose();
    rateController.dispose();
    billingPeriodController.dispose();
  }

  // ============================================================
  // FILTER DROPDOWN
  // ============================================================

  Widget _buildCompactDropdown({
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String>
        onChanged,
  }) {
    return Container(
      height: 48,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      decoration:
          BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              Colors.grey.shade300,
        ),
      ),
      child:
          DropdownButtonHideUnderline(
        child:
            DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: const Icon(
            Icons
                .keyboard_arrow_down,
            size: 22,
            color: Colors.grey,
          ),
          style:
              const TextStyle(
            color:
                Colors.black87,
            fontSize: 14,
            fontWeight:
                FontWeight.w500,
          ),
          items:
              items.map((item) {
            return DropdownMenuItem<
                String>(
              value: item,
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color:
                        Colors.orange,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child: Text(
                      item,
                      overflow:
                          TextOverflow
                              .ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }

  // ============================================================
  // STATUS FILTER
  // ============================================================

  Widget _buildStatusFilter() {
    return _buildCompactDropdown(
      icon: Icons.tune,
      value:
          _selectedStatus,
      items: const [
        'All',
        'Pending',
        'Unpaid',
        'Paid',
      ],
      onChanged: (value) {
        setState(() {
          _selectedStatus =
              value;
        });
      },
    );
  }

  // ============================================================
  // MONTH FILTER
  // ============================================================

  Widget _buildMonthFilter() {
    return _buildCompactDropdown(
      icon:
          Icons.calendar_month,
      value:
          _selectedMonth,
      items: [
        'All Months',
        ..._monthNames,
      ],
      onChanged: (value) {
        setState(() {
          _selectedMonth =
              value;
        });
      },
    );
  }

  // ============================================================
  // MUNICIPALITY
  // ============================================================

  Widget _buildMunicipalityFilter() {
    final municipalities =
        getSorsogonSecondDistrictMunicipalities();

    return _buildLocationDropdown(
      icon:
          Icons.location_city,
      value:
          _selectedMunicipality,
      items: [
        'All Municipalities',
        ...municipalities,
      ],
      enabled: true,
      hint:
          'All Municipalities',
      onChanged: (value) {
        setState(() {
          _selectedMunicipality =
              value;

          if (value ==
              'All Municipalities') {
            _selectedBarangay =
                'Select Municipality First';
          } else {
            _selectedBarangay =
                'All Barangays';
          }
        });
      },
    );
  }

  // ============================================================
  // BARANGAY
  // ============================================================

  Widget _buildBarangayFilter() {
    final municipalitySelected =
        _selectedMunicipality !=
            'All Municipalities';

    if (!municipalitySelected) {
      return _buildLocationDropdown(
        icon:
            Icons.location_on,
        value:
            'Select Municipality First',
        items: const [
          'Select Municipality First',
        ],
        enabled: false,
        hint:
            'Select Municipality First',
        onChanged: (_) {},
      );
    }

    final barangays =
        getBarangaysForMunicipality(
      _selectedMunicipality,
    );

    return _buildLocationDropdown(
      icon:
          Icons.location_on,
      value:
          _selectedBarangay,
      items: [
        'All Barangays',
        ...barangays,
      ],
      enabled: true,
      hint:
          'All Barangays',
      onChanged: (value) {
        setState(() {
          _selectedBarangay =
              value;
        });
      },
    );
  }

  // ============================================================
  // LOCATION DROPDOWN
  // ============================================================

  Widget _buildLocationDropdown({
    required IconData icon,
    required String value,
    required List<String> items,
    required bool enabled,
    required String hint,
    required ValueChanged<String>
        onChanged,
  }) {
    return Container(
      height: 64,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      decoration:
          BoxDecoration(
        color: enabled
            ? Colors.grey.shade50
            : Colors.grey.shade100,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              Colors.grey.shade300,
        ),
      ),
      child:
          DropdownButtonHideUnderline(
        child:
            DropdownButton<String>(
          value:
              items.contains(value)
                  ? value
                  : null,
          isExpanded: true,
          isDense: false,
          hint: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: enabled
                    ? Colors.orange
                    : Colors.grey,
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Text(
                  hint,
                  style:
                      TextStyle(
                    fontSize: 16,
                    color: enabled
                        ? Colors
                            .black87
                        : Colors
                            .grey,
                  ),
                  overflow:
                      TextOverflow
                          .ellipsis,
                ),
              ),
            ],
          ),
          icon: const Icon(
            Icons
                .keyboard_arrow_down,
            color:
                Colors.grey,
          ),
          style: TextStyle(
            color: enabled
                ? Colors.black87
                : Colors.grey,
            fontSize: 16,
          ),
          items:
              items.map((item) {
            return DropdownMenuItem<
                String>(
              value: item,
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 21,
                    color: item ==
                            'Select Municipality First'
                        ? Colors.grey
                        : Colors.orange,
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child: Text(
                      item,
                      overflow:
                          TextOverflow
                              .ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: enabled
              ? (value) {
                  if (value !=
                      null) {
                    onChanged(
                      value,
                    );
                  }
                }
              : null,
        ),
      ),
    );
  }

  // ============================================================
  // FILTER BAR
  // ============================================================

  Widget _buildFilterBar() {
    return Container(
      color:
          const Color(0xFFFFF8E7),
      padding:
          const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        14,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child:
                    _buildStatusFilter(),
              ),
              const SizedBox(
                width: 8,
              ),
              Expanded(
                child:
                    _buildMonthFilter(),
              ),
              const SizedBox(
                width: 8,
              ),
              Container(
                height: 48,
                width: 48,
                decoration:
                    BoxDecoration(
                  color: Colors
                      .grey.shade50,
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                  border:
                      Border.all(
                    color: Colors
                        .grey.shade300,
                  ),
                ),
                child:
                    PopupMenuButton<
                        String>(
                  tooltip:
                      'Sort',
                  icon:
                      const Icon(
                    Icons.sort,
                    color:
                        Colors.orange,
                  ),
                  onSelected:
                      (value) {
                    setState(() {
                      _sortOption =
                          value;
                    });
                  },
                  itemBuilder:
                      (context) {
                    return const [
                      PopupMenuItem(
                        value:
                            'Newest',
                        child:
                            Text(
                          'Newest',
                        ),
                      ),
                      PopupMenuItem(
                        value:
                            'Oldest',
                        child:
                            Text(
                          'Oldest',
                        ),
                      ),
                    ];
                  },
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          _buildMunicipalityFilter(),

          const SizedBox(
            height: 12,
          ),

          _buildBarangayFilter(),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildFilterSummary(
    List<QueryDocumentSnapshot> bills,
    List<_ReadingItem> readings,
  ) {
    int paidCount = 0;
    int unpaidCount = 0;

    double paidAmount = 0;
    double unpaidAmount = 0;

    for (final doc in bills) {
      final data =
          doc.data()
              as Map<String, dynamic>;

      final status =
          _getFirestoreStatus(data);

      final amount =
          _doubleValue(
        data,
        'totalAmount',
      );

      if (status == 'paid') {
        paidCount++;
        paidAmount += amount;
      } else if (status ==
          'unpaid') {
        unpaidCount++;
        unpaidAmount += amount;
      }
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        color:
            Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons
                    .filter_alt_outlined,
                size: 18,
                color:
                    Colors.orange,
              ),
              const SizedBox(
                width: 7,
              ),
              Expanded(
                child: Text(
                  _getFilterSummaryTitle(),
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          Row(
            children: [
              Expanded(
                child:
                    _summaryItem(
                  'Pending',
                  readings.length
                      .toString(),
                  Colors.blue,
                ),
              ),
              Expanded(
                child:
                    _summaryItem(
                  'Paid',
                  paidCount
                      .toString(),
                  Colors.green,
                ),
              ),
              Expanded(
                child:
                    _summaryItem(
                  'Unpaid',
                  unpaidCount
                      .toString(),
                  Colors.orange,
                ),
              ),
            ],
          ),

          const Divider(
            height: 20,
          ),

          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              const Text(
                'Paid Amount',
                style:
                    TextStyle(
                  color:
                      Colors.grey,
                ),
              ),
              Text(
                '₱${paidAmount.toStringAsFixed(2)}',
                style:
                    const TextStyle(
                  color:
                      Colors.green,
                  fontWeight:
                      FontWeight
                          .bold,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 5,
          ),

          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              const Text(
                'Unpaid Amount',
                style:
                    TextStyle(
                  color:
                      Colors.grey,
                ),
              ),
              Text(
                '₱${unpaidAmount.toStringAsFixed(2)}',
                style:
                    const TextStyle(
                  color:
                      Colors.orange,
                  fontWeight:
                      FontWeight
                          .bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getFilterSummaryTitle() {
    final parts = <String>[];

    if (_selectedMunicipality !=
        'All Municipalities') {
      parts.add(
        _selectedMunicipality,
      );
    }

    if (_selectedBarangay !=
            'All Barangays' &&
        _selectedBarangay !=
            'Select Municipality First') {
      parts.add(
        _selectedBarangay,
      );
    }

    if (_selectedMonth !=
        'All Months') {
      parts.add(
        _selectedMonth,
      );
    }

    if (parts.isEmpty) {
      return 'All Locations / All Months';
    }

    return parts.join(' • ');
  }

  Widget _summaryItem(
    String title,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(
          height: 2,
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors
                .grey.shade600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BILL CARD
  // ============================================================

  Widget _buildBillCard(
    QueryDocumentSnapshot doc,
  ) {
    final data =
        doc.data()
            as Map<String, dynamic>;

    final status =
        _getDisplayStatus(
      data,
      isBill: true,
    );

    final statusColor =
        _getStatusColor(status);

    final amount =
        _doubleValue(
      data,
      'totalAmount',
    );

    final consumption =
        _doubleValue(
      data,
      'consumption',
    );

    final billingPeriod =
        _stringValue(
      data,
      ['billingPeriod'],
      fallback: 'N/A',
    );

    final dueDate =
        _parseDate(
      data['dueDate'],
    );

    return Card(
      elevation: 3,
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _getConsumerName(
                      data,
                    ),
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration:
                      BoxDecoration(
                    color: statusColor
                        .withValues(
                      alpha: 0.12,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      20,
                    ),
                  ),
                  child: Text(
                    status,
                    style:
                        TextStyle(
                      color:
                          statusColor,
                      fontWeight:
                          FontWeight
                              .bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            Text(
              'Account Number: '
              '${_getAccountNumber(data)}',
            ),

            Text(
              'Billing Period: '
              '$billingPeriod',
            ),

            _buildLocationDetails(
              data,
            ),

            const Divider(
              height: 24,
            ),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
              children: [
                const Text(
                  'Consumption',
                  style:
                      TextStyle(
                    color:
                        Colors.grey,
                  ),
                ),
                Text(
                  '${consumption.toStringAsFixed(2)} kWh',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight
                            .bold,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 6,
            ),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style:
                      TextStyle(
                    color:
                        Colors.grey,
                  ),
                ),
                Text(
                  '₱${amount.toStringAsFixed(2)}',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight
                            .bold,
                    fontSize: 17,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 6,
            ),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
              children: [
                const Text(
                  'Due Date',
                  style:
                      TextStyle(
                    color:
                        Colors.grey,
                  ),
                ),
                Text(
                  dueDate != null
                      ? '${dueDate.month}/'
                          '${dueDate.day}/'
                          '${dueDate.year}'
                      : 'N/A',
                ),
              ],
            ),

            if (status ==
                'Paid') ...[
              const SizedBox(
                height: 12,
              ),
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets
                        .all(10),
                decoration:
                    BoxDecoration(
                  color: Colors
                      .green.shade50,
                  borderRadius:
                      BorderRadius
                          .circular(
                    8,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons
                          .check_circle,
                      color:
                          Colors.green,
                      size: 20,
                    ),
                    SizedBox(
                      width: 8,
                    ),
                    Text(
                      'Payment received',
                      style:
                          TextStyle(
                        color:
                            Colors.green,
                        fontWeight:
                            FontWeight
                                .w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PENDING READING CARD
  // ============================================================

  Widget _buildPendingCard(
    _ReadingItem item,
  ) {
    final readingDoc =
        item.document;

    final data =
        item.data;

    final isProcessing =
        _processingDocId ==
            readingDoc.id;

    final previous =
        _doubleValue(
      data,
      'previousReading',
    );

    final current =
        _doubleValue(
      data,
      'currentReading',
    );

    final consumption =
        _doubleValue(
      data,
      'consumption',
    );

    return Card(
      elevation: 3,
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _getConsumerName(
                      data,
                    ),
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors
                        .blue
                        .withValues(
                      alpha: 0.12,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      20,
                    ),
                  ),
                  child:
                      const Text(
                    'Pending',
                    style:
                        TextStyle(
                      color:
                          Colors.blue,
                      fontWeight:
                          FontWeight
                              .bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            Text(
              'Account Number: '
              '${_getAccountNumber(data)}',
            ),

            Text(
              'Billing Period: '
              '${data['billingPeriod'] ?? 'N/A'}',
            ),

            // CURRENT PROFILE LOCATION
            _buildLocationDetails(
              data,
            ),

            const SizedBox(
              height: 12,
            ),

            const Divider(),

            Text(
              'Previous Reading: '
              '${previous.toStringAsFixed(2)} kWh',
            ),

            Text(
              'Current Reading: '
              '${current.toStringAsFixed(2)} kWh',
            ),

            Text(
              'Consumption: '
              '${consumption.toStringAsFixed(2)} kWh',
            ),

            const SizedBox(
              height: 15,
            ),

            SizedBox(
              width:
                  double.infinity,
              height: 50,
              child:
                  ElevatedButton.icon(
                onPressed:
                    _processingDocId !=
                            null
                        ? null
                        : () async {
                            await _showEditBillDialog(
                              readingDoc,
                              data,
                            );
                          },
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xFFD32F2F,
                  ),
                  foregroundColor:
                      Colors.white,
                ),
                icon: isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,
                          color:
                              Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.edit,
                      ),
                label: Text(
                  isProcessing
                      ? 'VERIFYING...'
                      : 'EDIT & VERIFY BILL',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    String message;

    switch (_selectedStatus) {
      case 'Paid':
        message =
            'No paid bills found';
        break;

      case 'Unpaid':
        message =
            'No unpaid bills found';
        break;

      case 'Pending':
        message =
            'No pending meter readings found';
        break;

      default:
        message =
            'No bills or readings found';
    }

    if (_selectedMonth !=
        'All Months') {
      message +=
          '\nfor $_selectedMonth';
    }

    if (_selectedMunicipality !=
        'All Municipalities') {
      message +=
          '\nin $_selectedMunicipality';
    }

    if (_selectedBarangay !=
            'All Barangays' &&
        _selectedBarangay !=
            'Select Municipality First') {
      message +=
          '\nBarangay: $_selectedBarangay';
    }

    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment
                .center,
        children: [
          Icon(
            Icons
                .receipt_long_outlined,
            size: 70,
            color:
                Colors.grey.shade400,
          ),

          const SizedBox(
            height: 15,
          ),

          Text(
            message,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            'Try changing the filters.',
            style: TextStyle(
              color:
                  Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FIRESTORE DATA VIEW
  //
  // IMPORTANT FIX:
  //
  // Pending meter readings are matched to the CURRENT consumer
  // profile in the users collection.
  //
  // Bills continue using their own saved location.
  // ============================================================

  Widget _buildFirestoreDataView() {
    return StreamBuilder<QuerySnapshot>(
      // Bills keep their saved location.
      stream: _firestore
          .collection('bills')
          .snapshots(),

      builder: (
        context,
        billSnapshot,
      ) {
        if (billSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (billSnapshot.hasError) {
          return Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              child: Text(
                'Error loading bills:\n'
                '${billSnapshot.error}',
                textAlign:
                    TextAlign.center,
              ),
            ),
          );
        }

        final bills =
            billSnapshot.data?.docs ??
                [];

        return StreamBuilder<QuerySnapshot>(
          // Only pending readings.
          stream: _firestore
              .collection(
                  'meter_readings')
              .where(
                'status',
                isEqualTo: 'Pending',
              )
              .snapshots(),

          builder: (
            context,
            readingSnapshot,
          ) {
            if (readingSnapshot
                    .connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child:
                    CircularProgressIndicator(),
              );
            }

            if (readingSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding:
                      const EdgeInsets
                          .all(20),
                  child: Text(
                    'Error loading meter readings:\n'
                    '${readingSnapshot.error}',
                    textAlign:
                        TextAlign.center,
                  ),
                ),
              );
            }

            final readings =
                readingSnapshot.data
                        ?.docs ??
                    [];

            // ==================================================
            // CURRENT CONSUMER PROFILES
            // ==================================================

            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .snapshots(),

              builder: (
                context,
                userSnapshot,
              ) {
                if (userSnapshot
                        .connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                if (userSnapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .all(20),
                      child: Text(
                        'Error loading consumer profiles:\n'
                        '${userSnapshot.error}',
                        textAlign:
                            TextAlign.center,
                      ),
                    ),
                  );
                }

                final users =
                    userSnapshot.data
                            ?.docs ??
                        [];

                // ==================================================
                // BUILD READING ITEMS USING CURRENT PROFILE
                // ==================================================

                final readingItems =
                    <_ReadingItem>[];

                for (final readingDoc
                    in readings) {
                  final originalData =
                      readingDoc.data()
                          as Map<String,
                              dynamic>;

                  // Find current consumer profile.
                  final profile =
                      _findCurrentProfile(
                    originalData,
                    users,
                  );

                  // Create temporary data containing the
                  // CURRENT profile location.
                  final currentData =
                      _getCurrentReadingData(
                    originalData,
                    profile,
                  );

                  // Apply month filter.
                  if (!_matchesMonth(
                    currentData,
                    isBill: false,
                  )) {
                    continue;
                  }

                  // Apply CURRENT location filter.
                  if (!_matchesLocation(
                    currentData,
                  )) {
                    continue;
                  }

                  // Apply pending status filter.
                  if (!_matchesReadingStatus(
                    currentData,
                  )) {
                    continue;
                  }

                  readingItems.add(
                    _ReadingItem(
                      document:
                          readingDoc,
                      data:
                          currentData,
                    ),
                  );
                }

                // ==================================================
                // FILTER BILLS
                // ==================================================

                final filteredBills =
                    _filterDocuments(
                  bills,
                  isBill: true,
                );

                // ==================================================
                // SORT
                // ==================================================

                final sortedBills =
                    _sortDocuments(
                  filteredBills,
                  isBill: true,
                );

                final sortedReadings =
                    _sortReadingItems(
                  readingItems,
                );

                // ==================================================
                // EMPTY
                // ==================================================

                if (sortedBills.isEmpty &&
                    sortedReadings.isEmpty) {
                  return _buildEmptyState();
                }

                // ==================================================
                // DISPLAY
                // ==================================================

                return ListView(
                  padding:
                      const EdgeInsets.fromLTRB(
                    15,
                    5,
                    15,
                    20,
                  ),
                  children: [
                    _buildFilterSummary(
                      sortedBills,
                      sortedReadings,
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    // ==================================================
                    // PENDING
                    // ==================================================

                    if (sortedReadings
                        .isNotEmpty) ...[
                      const Padding(
                        padding:
                            EdgeInsets.only(
                          left: 2,
                          bottom: 8,
                        ),
                        child:
                            Text(
                          'PENDING METER READINGS',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize:
                                14,
                            color:
                                Colors.blue,
                          ),
                        ),
                      ),

                      ...sortedReadings.map(
                        (item) =>
                            _buildPendingCard(
                          item,
                        ),
                      ),
                    ],

                    // ==================================================
                    // BILLS
                    // ==================================================

                    if (sortedBills
                        .isNotEmpty) ...[
                      const Padding(
                        padding:
                            EdgeInsets.only(
                          left: 2,
                          top: 8,
                          bottom: 8,
                        ),
                        child:
                            Text(
                          'BILL MONITORING',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize:
                                14,
                            color:
                                Colors.orange,
                          ),
                        ),
                      ),

                      ...sortedBills.map(
                        (doc) =>
                            _buildBillCard(
                          doc,
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Verify Meter Readings',
        ),
        backgroundColor:
            Theme.of(context)
                .primaryColor,
        foregroundColor:
            Colors.white,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child:
                _buildFirestoreDataView(),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// READING ITEM
//
// Holds the original Firestore document AND the temporary data
// containing the consumer's CURRENT profile location.
// ================================================================

class _ReadingItem {
  final QueryDocumentSnapshot document;
  final Map<String, dynamic> data;

  const _ReadingItem({
    required this.document,
    required this.data,
  });
}