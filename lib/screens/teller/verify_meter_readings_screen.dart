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
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  String? _processingDocId;

  // ============================================================
  // SORT
  // ============================================================

  String _sortOption = 'Newest';

  // ============================================================
  // STATUS FILTER
  // ============================================================

  String _selectedStatus = 'All';

  // ============================================================
  // MONTH FILTER
  // ============================================================

  String _selectedMonth = 'All Months';

  // ============================================================
  // MUNICIPALITY FILTER
  // ============================================================

  String _selectedMunicipality = 'All Municipalities';

  // ============================================================
  // BARANGAY FILTER
  // ============================================================

  String _selectedBarangay = 'Select Municipality First';

  // ============================================================
  // LOCATION CACHE
  // ============================================================

  final Map<String, Map<String, dynamic>> _locationCache = {};

  // ============================================================
  // MONTH NAMES
  // ============================================================

  final List<String> _monthNames = const [
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
  // GET DATE
  // ============================================================

  DateTime? _getDate(dynamic value) {
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

  // ============================================================
  // GET READING DATE
  // ============================================================

  DateTime _getReadingDate(
    Map<String, dynamic> data,
  ) {
    final date =
        _getDate(data['recordedAt']) ??
        _getDate(data['createdAt']) ??
        _getDate(data['dateCreated']) ??
        _getDate(data['timestamp']) ??
        _getDate(data['generatedAt']);

    return date ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ============================================================
  // GET BILL DATE
  // ============================================================

  DateTime _getBillDate(
    Map<String, dynamic> data,
  ) {
    final date =
        _getDate(data['generatedAt']) ??
        _getDate(data['createdAt']) ??
        _getDate(data['dateCreated']) ??
        _getDate(data['dueDate']);

    return date ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ============================================================
  // GET BILLING PERIOD DATE
  // ============================================================

  DateTime? _getBillingPeriodDate(
    Map<String, dynamic> data,
  ) {
    final billingPeriod =
        (data['billingPeriod'] ?? '')
            .toString()
            .trim();

    if (billingPeriod.isEmpty) {
      return null;
    }

    for (int month = 1; month <= 12; month++) {
      final monthName =
          _monthNames[month - 1];

      if (billingPeriod
          .toLowerCase()
          .contains(monthName.toLowerCase())) {
        int year = DateTime.now().year;

        final RegExp yearRegex =
            RegExp(r'\b(20\d{2})\b');

        final match =
            yearRegex.firstMatch(
          billingPeriod,
        );

        if (match != null) {
          year =
              int.tryParse(
                    match.group(1)!,
                  ) ??
                  year;
        }

        return DateTime(
          year,
          month,
          1,
        );
      }
    }

    return null;
  }

  // ============================================================
  // GET MONTH FOR DOCUMENT
  // ============================================================

  int? _getDocumentMonth(
    Map<String, dynamic> data,
    bool isBill,
  ) {
    final billingPeriodDate =
        _getBillingPeriodDate(data);

    if (billingPeriodDate != null) {
      return billingPeriodDate.month;
    }

    final date = isBill
        ? _getBillDate(data)
        : _getReadingDate(data);

    if (date.year ==
        DateTime.fromMillisecondsSinceEpoch(
          0,
        ).year) {
      return null;
    }

    return date.month;
  }

  // ============================================================
  // SORT DOCUMENTS
  // ============================================================

  List<QueryDocumentSnapshot> _sortDocuments(
    List<QueryDocumentSnapshot> docs, {
    bool isBill = false,
  }) {
    final sortedDocs =
        List<QueryDocumentSnapshot>.from(
      docs,
    );

    sortedDocs.sort(
      (a, b) {
        final dataA =
            a.data()
                as Map<String, dynamic>;

        final dataB =
            b.data()
                as Map<String, dynamic>;

        final dateA = isBill
            ? _getBillDate(dataA)
            : _getReadingDate(dataA);

        final dateB = isBill
            ? _getBillDate(dataB)
            : _getReadingDate(dataB);

        if (_sortOption == 'Newest') {
          return dateB.compareTo(dateA);
        }

        return dateA.compareTo(dateB);
      },
    );

    return sortedDocs;
  }

  // ============================================================
  // FILTER MONTH
  // ============================================================

  bool _matchesMonth(
    Map<String, dynamic> data,
    bool isBill,
  ) {
    if (_selectedMonth == 'All Months') {
      return true;
    }

    final selectedIndex =
        _monthNames.indexOf(
      _selectedMonth,
    );

    if (selectedIndex == -1) {
      return true;
    }

    final documentMonth =
        _getDocumentMonth(
      data,
      isBill,
    );

    return documentMonth ==
        selectedIndex + 1;
  }

  // ============================================================
  // GET CONSUMER NAME
  // ============================================================

  String _getConsumerName(
    Map<String, dynamic> data,
  ) {
    return (
      data['consumerName'] ??
      data['full_name'] ??
      data['fullName'] ??
      data['name'] ??
      'Unknown Consumer'
    )
        .toString()
        .trim();
  }

  // ============================================================
  // GET CONSUMER ID
  // ============================================================

  String _getConsumerId(
    Map<String, dynamic> data,
  ) {
    return (
      data['consumerId'] ??
      data['uid'] ??
      data['userId'] ??
      data['consumerUID'] ??
      ''
    )
        .toString()
        .trim();
  }

  // ============================================================
  // GET ACCOUNT NUMBER
  // ============================================================

  String _getAccountNumber(
    Map<String, dynamic> data,
  ) {
    final value =
        data['accountNumber'] ??
        data['accountNo'] ??
        data['account_number'] ??
        data['account'] ??
        '';

    return value
        .toString()
        .trim();
  }

  // ============================================================
  // GET STATUS
  // ============================================================

  String _getStatus(
    Map<String, dynamic> data,
    bool isBill,
  ) {
    final rawStatus =
        (data['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    if (!isBill) {
      return 'Pending';
    }

    if (rawStatus == 'paid') {
      return 'Paid';
    }

    return 'Unpaid';
  }

  // ============================================================
  // GET STATUS COLOR
  // ============================================================

  Color _getStatusColor(
    String status,
  ) {
    switch (status) {
      case 'Paid':
        return Colors.green;

      case 'Unpaid':
        return Colors.orange;

      case 'Pending':
        return Colors.blue;

      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // DIRECT LOCATION FROM DOCUMENT
  // ============================================================

  Map<String, dynamic> _getDirectLocation(
    Map<String, dynamic> data,
  ) {
    final barangay =
        (
          data['barangay'] ??
          data['baranggay'] ??
          ''
        )
            .toString()
            .trim();

    final municipality =
        (
          data['municipality'] ??
          data['city'] ??
          ''
        )
            .toString()
            .trim();

    final province =
        (
          data['province'] ??
          'Sorsogon'
        )
            .toString()
            .trim();

    final address =
        (
          data['address'] ??
          ''
        )
            .toString()
            .trim();

    return {
      'barangay': barangay,
      'municipality': municipality,
      'province': province,
      'address': address,
    };
  }

  // ============================================================
  // CREATE LOCATION FROM USER DOCUMENT
  // ============================================================

  Map<String, dynamic> _makeLocation(
    Map<String, dynamic> userData,
  ) {
    final barangay =
        (
          userData['barangay'] ??
          userData['baranggay'] ??
          ''
        )
            .toString()
            .trim();

    final municipality =
        (
          userData['municipality'] ??
          userData['city'] ??
          ''
        )
            .toString()
            .trim();

    final province =
        (
          userData['province'] ??
          'Sorsogon'
        )
            .toString()
            .trim();

    String address =
        (
          userData['address'] ??
          ''
        )
            .toString()
            .trim();

    if (address.isEmpty &&
        barangay.isNotEmpty &&
        municipality.isNotEmpty) {
      try {
        if (isValidBarangayForMunicipality(
          municipality: municipality,
          barangay: barangay,
        )) {
          address =
              buildSorsogonAddress(
            municipality:
                municipality,
            barangay:
                barangay,
          );
        } else {
          address =
              '$barangay, $municipality, $province';
        }
      } catch (_) {
        address =
            '$barangay, $municipality, $province';
      }
    }

    return {
      'barangay': barangay,
      'municipality': municipality,
      'province': province,
      'address': address,
    };
  }

  // ============================================================
  // NORMALIZE ACCOUNT NUMBER
  // ============================================================

  String _normalizeAccountNumber(
    dynamic value,
  ) {
    return value
        .toString()
        .trim()
        .replaceAll(
          RegExp(r'\s+'),
          '',
        );
  }

  // ============================================================
  // FIND USER BY ACCOUNT NUMBER
  // ============================================================

  Future<Map<String, dynamic>?>
      _findUserByAccountNumber(
    String accountNumber,
  ) async {
    if (accountNumber.isEmpty) {
      return null;
    }

    final normalized =
        _normalizeAccountNumber(
      accountNumber,
    );

    try {
      final snapshot =
          await _firestore
              .collection('users')
              .where(
                'accountNumber',
                isEqualTo: normalized,
              )
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
    } catch (_) {}

    try {
      final snapshot =
          await _firestore
              .collection('users')
              .where(
                'accountNo',
                isEqualTo: normalized,
              )
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
    } catch (_) {}

    try {
      final snapshot =
          await _firestore
              .collection('users')
              .where(
                'account_number',
                isEqualTo: normalized,
              )
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
    } catch (_) {}

    return null;
  }

  // ============================================================
  // FIND USER BY UID FIELD
  // ============================================================

  Future<Map<String, dynamic>?> _findUserByUid(
    String uid,
  ) async {
    if (uid.isEmpty) {
      return null;
    }

    try {
      final snapshot =
          await _firestore
              .collection('users')
              .where(
                'uid',
                isEqualTo: uid,
              )
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
    } catch (_) {}

    return null;
  }

  // ============================================================
  // FETCH CONSUMER LOCATION
  // ============================================================

  Future<Map<String, dynamic>>
      _getConsumerLocation(
    Map<String, dynamic> documentData,
  ) async {
    final accountNumber =
        _getAccountNumber(
      documentData,
    );

    final consumerId =
        _getConsumerId(
      documentData,
    );

    final directLocation =
        _getDirectLocation(
      documentData,
    );

    final normalizedAccount =
        _normalizeAccountNumber(
      accountNumber,
    );

    // ==========================================================
    // CACHE BY ACCOUNT NUMBER
    // ==========================================================

    if (normalizedAccount.isNotEmpty &&
        _locationCache.containsKey(
          'account:$normalizedAccount',
        )) {
      return _locationCache[
          'account:$normalizedAccount']!;
    }

    // ==========================================================
    // CACHE BY UID
    // ==========================================================

    if (consumerId.isNotEmpty &&
        _locationCache.containsKey(
          'uid:$consumerId',
        )) {
      return _locationCache[
          'uid:$consumerId']!;
    }

    // ==========================================================
    // 1. ACCOUNT NUMBER FIRST
    // ==========================================================

    if (normalizedAccount.isNotEmpty) {
      final userData =
          await _findUserByAccountNumber(
        normalizedAccount,
      );

      if (userData != null) {
        final location =
            _makeLocation(
          userData,
        );

        if (_hasLocation(location)) {
          _locationCache[
                  'account:$normalizedAccount'] =
              location;

          if (consumerId.isNotEmpty) {
            _locationCache[
                    'uid:$consumerId'] =
                location;
          }

          return location;
        }
      }
    }

    // ==========================================================
    // 2. UID FIELD
    // ==========================================================

    if (consumerId.isNotEmpty) {
      final userData =
          await _findUserByUid(
        consumerId,
      );

      if (userData != null) {
        final location =
            _makeLocation(
          userData,
        );

        if (_hasLocation(location)) {
          if (normalizedAccount.isNotEmpty) {
            _locationCache[
                    'account:$normalizedAccount'] =
                location;
          }

          _locationCache[
                  'uid:$consumerId'] =
              location;

          return location;
        }
      }
    }

    // ==========================================================
    // 3. USER DOCUMENT ID
    // ==========================================================

    if (consumerId.isNotEmpty) {
      try {
        final userDoc =
            await _firestore
                .collection('users')
                .doc(consumerId)
                .get();

        if (userDoc.exists) {
          final userData =
              userDoc.data() ??
                  <String, dynamic>{};

          final location =
              _makeLocation(
            userData,
          );

          if (_hasLocation(location)) {
            if (normalizedAccount.isNotEmpty) {
              _locationCache[
                      'account:$normalizedAccount'] =
                  location;
            }

            _locationCache[
                    'uid:$consumerId'] =
                location;

            return location;
          }
        }
      } catch (_) {}
    }

    // ==========================================================
    // 4. DIRECT LOCATION
    // ==========================================================

    if (_hasLocation(
      directLocation,
    )) {
      if (normalizedAccount.isNotEmpty) {
        _locationCache[
                'account:$normalizedAccount'] =
            directLocation;
      }

      if (consumerId.isNotEmpty) {
        _locationCache[
                'uid:$consumerId'] =
            directLocation;
      }

      return directLocation;
    }

    return {
      'barangay': '',
      'municipality': '',
      'province': '',
      'address': '',
    };
  }

  // ============================================================
  // CHECK LOCATION
  // ============================================================

  bool _hasLocation(
    Map<String, dynamic> location,
  ) {
    final barangay =
        (location['barangay'] ?? '')
            .toString()
            .trim();

    final municipality =
        (location['municipality'] ?? '')
            .toString()
            .trim();

    final province =
        (location['province'] ?? '')
            .toString()
            .trim();

    final address =
        (location['address'] ?? '')
            .toString()
            .trim();

    return barangay.isNotEmpty ||
        municipality.isNotEmpty ||
        province.isNotEmpty ||
        address.isNotEmpty;
  }

  // ============================================================
  // NORMALIZE LOCATION TEXT
  // ============================================================

  String _normalizeLocationText(
    dynamic value,
  ) {
    return value
        .toString()
        .trim()
        .toLowerCase();
  }

  // ============================================================
  // CHECK MUNICIPALITY/BARANGAY FILTER
  //
  // This is asynchronous because the location may have to be
  // fetched from the users collection.
  // ============================================================

  Future<bool> _matchesLocationFilter(
    Map<String, dynamic> data,
  ) async {
    // No municipality selected.
    if (_selectedMunicipality ==
        'All Municipalities') {
      return true;
    }

    final location =
        await _getConsumerLocation(
      data,
    );

    final municipality =
        _normalizeLocationText(
      location['municipality'],
    );

    final barangay =
        _normalizeLocationText(
      location['barangay'],
    );

    final selectedMunicipality =
        _normalizeLocationText(
      _selectedMunicipality,
    );

    // ==========================================================
    // MUNICIPALITY MUST MATCH FIRST
    // ==========================================================

    if (municipality !=
        selectedMunicipality) {
      return false;
    }

    // ==========================================================
    // ALL BARANGAYS IN SELECTED MUNICIPALITY
    // ==========================================================

    if (_selectedBarangay ==
        'All Barangays') {
      return true;
    }

    // ==========================================================
    // SPECIFIC BARANGAY
    // ==========================================================

    if (_selectedBarangay ==
        'Select Municipality First') {
      return true;
    }

    return barangay ==
        _normalizeLocationText(
      _selectedBarangay,
    );
  }

  // ============================================================
  // FILTER DOCUMENTS BY LOCATION
  // ============================================================

  Future<List<QueryDocumentSnapshot>>
      _filterDocumentsByLocation(
    List<QueryDocumentSnapshot> documents,
  ) async {
    if (_selectedMunicipality ==
        'All Municipalities') {
      return documents;
    }

    final List<QueryDocumentSnapshot>
        filtered = [];

    for (final doc in documents) {
      final data =
          doc.data()
              as Map<String, dynamic>;

      final matches =
          await _matchesLocationFilter(
        data,
      );

      if (matches) {
        filtered.add(doc);
      }
    }

    return filtered;
  }

  // ============================================================
  // LOCATION DETAILS - INLINE
  // ============================================================

  Widget _buildLocationDetails(
    Map<String, dynamic> location,
  ) {
    final barangay =
        (location['barangay'] ?? '')
            .toString()
            .trim();

    final municipality =
        (location['municipality'] ?? '')
            .toString()
            .trim();

    final province =
        (location['province'] ?? '')
            .toString()
            .trim();

    final address =
        (location['address'] ?? '')
            .toString()
            .trim();

    String locationText = '';

    if (address.isNotEmpty) {
      locationText = address;
    } else {
      if (barangay.isNotEmpty) {
        locationText = barangay;
      }

      if (municipality.isNotEmpty) {
        locationText += locationText.isEmpty
            ? municipality
            : ', $municipality';
      }

      if (province.isNotEmpty) {
        locationText += locationText.isEmpty
            ? province
            : ', $province';
      }
    }

    if (locationText.isEmpty) {
      locationText = 'Location not available';
    }

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
          const SizedBox(
            width: 5,
          ),
          const Text(
            'Location: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          Expanded(
            child: Text(
              locationText,
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
  // VERIFY READING
  // ============================================================

  Future<void> _verifyReading({
    required DocumentSnapshot readingDoc,
    required double previousReading,
    required double currentReading,
    required double consumption,
    required double ratePerKwh,
    required String billingPeriod,
    required DateTime dueDate,
    required String billStatus,
  }) async {
    final String docId =
        readingDoc.id;

    setState(() {
      _processingDocId =
          docId;
    });

    try {
      final reading =
          readingDoc.data()
                  as Map<String, dynamic>? ??
              {};

      final DocumentReference billRef =
          _firestore
              .collection("bills")
              .doc();

      final double totalAmount =
          consumption *
              ratePerKwh;

      final String consumerId =
          _getConsumerId(
        reading,
      );

      final String consumerName =
          (
            reading["consumerName"] ??
            reading["full_name"] ??
            reading["fullName"] ??
            reading["name"] ??
            "N/A"
          )
              .toString()
              .trim();

      final String accountNumber =
          _getAccountNumber(
        reading,
      );

      final location =
          await _getConsumerLocation(
        reading,
      );

      final String barangay =
          (
            location["barangay"] ??
            ""
          )
              .toString()
              .trim();

      final String municipality =
          (
            location["municipality"] ??
            ""
          )
              .toString()
              .trim();

      final String province =
          (
            location["province"] ??
            "Sorsogon"
          )
              .toString()
              .trim();

      String address =
          (
            location["address"] ??
            ""
          )
              .toString()
              .trim();

      if (address.isEmpty &&
          barangay.isNotEmpty &&
          municipality.isNotEmpty) {
        try {
          address =
              buildSorsogonAddress(
            municipality:
                municipality,
            barangay:
                barangay,
          );
        } catch (_) {
          address =
              '$barangay, $municipality, $province';
        }
      }

      // ==========================================================
      // BILL DATA
      // ==========================================================

      final Map<String, dynamic>
          billData = {
        "billId":
            billRef.id,

        "consumerId":
            consumerId,

        "consumerName":
            consumerName,

        "accountNumber":
            accountNumber,

        "barangay":
            barangay,

        "municipality":
            municipality,

        "province":
            province,

        "address":
            address,

        "previousReading":
            previousReading,

        "currentReading":
            currentReading,

        "consumption":
            consumption,

        "ratePerKwh":
            ratePerKwh,

        "totalAmount":
            totalAmount,

        "billingPeriod":
            billingPeriod,

        "dueDate":
            Timestamp.fromDate(
          dueDate,
        ),

        "status":
            billStatus.toLowerCase(),

        "generatedBy":
            _auth.currentUser?.email ??
                "Teller",

        "generatedAt":
            FieldValue.serverTimestamp(),
      };

      final WriteBatch batch =
          _firestore.batch();

      // ==========================================================
      // CREATE BILL
      // ==========================================================

      batch.set(
        billRef,
        billData,
      );

      // ==========================================================
      // UPDATE READING
      // ==========================================================

      batch.update(
        readingDoc.reference,
        {
          "status":
              "Verified",

          "verifiedBy":
              _auth.currentUser?.email ??
                  "Teller",

          "verifiedAt":
              FieldValue.serverTimestamp(),

          "barangay":
              barangay,

          "municipality":
              municipality,

          "province":
              province,

          "address":
              address,

          "consumerId":
              consumerId,

          "accountNumber":
              accountNumber,
        },
      );

      await batch.commit();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          backgroundColor:
              Colors.green,
          content: Text(
            "Bill verified and generated successfully.",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          backgroundColor:
              Colors.red,
          content:
              Text(
            "Error: $e",
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingDocId =
              null;
        });
      }
    }
  }

  // ============================================================
  // EDIT BILL DIALOG
  // ============================================================

  Future<void> _showEditBillDialog(
    DocumentSnapshot readingDoc,
  ) async {
    final data =
        readingDoc.data()
            as Map<String, dynamic>;

    final previousReadingController =
        TextEditingController(
      text:
          "${data["previousReading"] ?? 0}",
    );

    final currentReadingController =
        TextEditingController(
      text:
          "${data["currentReading"] ?? 0}",
    );

    final consumptionController =
        TextEditingController(
      text:
          "${data["consumption"] ?? 0}",
    );

    final billingPeriodController =
        TextEditingController(
      text:
          "${data["billingPeriod"] ?? ""}",
    );

    double currentRate =
        (data["ratePerKwh"]
                    as num?)
                ?.toDouble() ??
            0;

    if (currentRate == 0) {
      try {
        final RateService rateService =
            RateService();

        currentRate =
            await rateService
                .getCurrentRate();
      } catch (_) {}
    }

    final rateController =
        TextEditingController(
      text:
          currentRate.toString(),
    );

    String selectedStatus =
        "unpaid";

    DateTime selectedDueDate =
        DateTime.now().add(
      const Duration(
        days: 15,
      ),
    );

    if (!mounted) {
      return;
    }

    await showDialog(
      context: context,
      builder:
          (dialogContext) {
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
                        rateController
                            .text,
                      ) ??
                      0;

              return consumption *
                  rate;
            }

            return AlertDialog(
              title:
                  const Text(
                "Edit and Verify Bill",
              ),
              content:
                  SingleChildScrollView(
                child:
                    Column(
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
                        fontSize:
                            18,
                      ),
                    ),

                    Text(
                      "Account #: ${_getAccountNumber(data)}",
                      style:
                          TextStyle(
                        color:
                            Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    FutureBuilder<
                        Map<String,
                            dynamic>>(
                      future:
                          _getConsumerLocation(
                        data,
                      ),
                      builder: (
                        context,
                        snapshot,
                      ) {
                        if (snapshot
                                .connectionState ==
                            ConnectionState
                                .waiting) {
                          return const Padding(
                            padding:
                                EdgeInsets.only(
                              top: 6,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                  ),
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  "Loading location...",
                                ),
                              ],
                            ),
                          );
                        }

                        return _buildLocationDetails(
                          snapshot.data ??
                              {
                                'barangay':
                                    '',
                                'municipality':
                                    '',
                                'province':
                                    '',
                                'address':
                                    '',
                              },
                        );
                      },
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    TextField(
                      controller:
                          previousReadingController,
                      keyboardType:
                          TextInputType.number,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Previous Reading",
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          currentReadingController,
                      keyboardType:
                          TextInputType.number,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Current Reading",
                        border:
                            OutlineInputBorder(),
                      ),
                      onChanged:
                          (_) {
                        final previous =
                            double.tryParse(
                                  previousReadingController
                                      .text,
                                ) ??
                                0;

                        final current =
                            double.tryParse(
                                  currentReadingController
                                      .text,
                                ) ??
                                0;

                        final consumption =
                            current -
                                previous;

                        setDialogState(
                          () {
                            consumptionController
                                    .text =
                                consumption
                                    .toStringAsFixed(
                              2,
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          consumptionController,
                      keyboardType:
                          TextInputType.number,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Consumption (kWh)",
                        border:
                            OutlineInputBorder(),
                      ),
                      onChanged:
                          (_) {
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
                          TextInputType.number,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Rate per kWh",
                        border:
                            OutlineInputBorder(),
                      ),
                      onChanged:
                          (_) {
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
                            "Billing Period",
                        border:
                            OutlineInputBorder(),
                        hintText:
                            "Example: August 2026",
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    DropdownButtonFormField<
                        String>(
                      value:
                          selectedStatus,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Bill Status",
                        border:
                            OutlineInputBorder(),
                      ),
                      items:
                          const [
                        DropdownMenuItem(
                          value:
                              "unpaid",
                          child:
                              Text(
                            "Unpaid",
                          ),
                        ),
                        DropdownMenuItem(
                          value:
                              "paid",
                          child:
                              Text(
                            "Paid",
                          ),
                        ),
                      ],
                      onChanged:
                          (value) {
                        setDialogState(
                          () {
                            selectedStatus =
                                value ??
                                    "unpaid";
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
                        "Due Date",
                      ),
                      subtitle:
                          Text(
                        "${selectedDueDate.month}/${selectedDueDate.day}/${selectedDueDate.year}",
                      ),
                      trailing:
                          const Icon(
                        Icons.calendar_today,
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
                              DateTime.now().add(
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
                      "Total Amount",
                      style:
                          TextStyle(
                        fontSize:
                            16,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),

                    const SizedBox(
                      height:
                          5,
                    ),

                    Text(
                      "₱${calculateTotal().toStringAsFixed(2)}",
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFFD32F2F,
                        ),
                        fontWeight:
                            FontWeight.bold,
                        fontSize:
                            25,
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
                    "Cancel",
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
                    final previousReading =
                        double.tryParse(
                              previousReadingController
                                  .text,
                            ) ??
                            0;

                    final currentReading =
                        double.tryParse(
                              currentReadingController
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

                    if (currentReading <
                        previousReading) {
                      ScaffoldMessenger
                          .of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content:
                              Text(
                            "Current reading cannot be less than previous reading.",
                          ),
                        ),
                      );

                      return;
                    }

                    if (consumption < 0) {
                      ScaffoldMessenger
                          .of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content:
                              Text(
                            "Consumption cannot be negative.",
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
                          content:
                              Text(
                            "Rate must be greater than zero.",
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
                      previousReading:
                          previousReading,
                      currentReading:
                          currentReading,
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
                    "SAVE & VERIFY",
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    previousReadingController.dispose();
    currentReadingController.dispose();
    consumptionController.dispose();
    rateController.dispose();
    billingPeriodController.dispose();
  }

  // ============================================================
  // STATUS FILTER
  // ============================================================

  Widget _buildStatusFilter() {
    return _buildCompactDropdown(
      icon: Icons.tune,
      value: _selectedStatus,
      items: const [
        'All',
        'Pending',
        'Unpaid',
        'Paid',
      ],
      onChanged: (value) {
        setState(() {
          _selectedStatus = value;
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
      value: _selectedMonth,
      items: [
        'All Months',
        ..._monthNames,
      ],
      onChanged: (value) {
        setState(() {
          _selectedMonth = value;
        });
      },
    );
  }

  // ============================================================
  // MUNICIPALITY FILTER
  //
  // Uses your sorsogon_address_data.dart
  // ============================================================

  Widget _buildMunicipalityFilter() {
    final municipalities =
        getSorsogonSecondDistrictMunicipalities();

    return _buildLocationDropdown(
      icon: Icons.location_city,
      value: _selectedMunicipality,
      items: [
        'All Municipalities',
        ...municipalities,
      ],
      enabled: true,
      hint: 'All Municipalities',
      onChanged: (value) {
        setState(() {
          _selectedMunicipality =
              value;

          // IMPORTANT:
          // Reset barangay every time the municipality changes.
          _selectedBarangay =
              value ==
                      'All Municipalities'
                  ? 'Select Municipality First'
                  : 'All Barangays';
        });
      },
    );
  }

  // ============================================================
  // BARANGAY FILTER
  //
  // Barangays are generated ONLY from the selected municipality.
  // ============================================================

  Widget _buildBarangayFilter() {
    final bool municipalitySelected =
        _selectedMunicipality !=
            'All Municipalities';

    if (!municipalitySelected) {
      return _buildLocationDropdown(
        icon: Icons.location_on,
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
      icon: Icons.location_on,
      value: _selectedBarangay,
      items: [
        'All Barangays',
        ...barangays,
      ],
      enabled: true,
      hint: 'All Barangays',
      onChanged: (value) {
        setState(() {
          _selectedBarangay =
              value;
        });
      },
    );
  }

  // ============================================================
  // COMPACT DROPDOWN
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
        color:
            Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border:
            Border.all(
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
          icon:
              const Icon(
            Icons.keyboard_arrow_down,
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
              items.map(
            (item) {
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
                            TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ).toList(),
          onChanged:
              (value) {
            if (value != null) {
              onChanged(
                value,
              );
            }
          },
        ),
      ),
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
    required ValueChanged<String> onChanged,
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
            BorderRadius.circular(
          14,
        ),
        border:
            Border.all(
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
          hint:
              Row(
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
                    fontSize:
                        16,
                    color: enabled
                        ? Colors.black87
                        : Colors.grey,
                    fontWeight:
                        FontWeight.w400,
                  ),
                  overflow:
                      TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          icon:
              const Icon(
            Icons.keyboard_arrow_down,
            color: Colors.grey,
          ),
          style:
              TextStyle(
            color: enabled
                ? Colors.black87
                : Colors.grey,
            fontSize: 16,
          ),
          items:
              items.map(
            (item) {
              return DropdownMenuItem<
                  String>(
                value:
                    item,
                child:
                    Row(
                  children: [
                    Icon(
                      icon,
                      size: 21,
                      color:
                          item ==
                                  'Select Municipality First'
                              ? Colors.grey
                              : Colors.orange,
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child:
                          Text(
                        item,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ).toList(),
          onChanged:
              enabled
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
  // BUILD BILL CARD
  // ============================================================

  Widget _buildBillCard(
    QueryDocumentSnapshot doc,
  ) {
    final data =
        doc.data()
            as Map<String, dynamic>;

    final String status =
        _getStatus(
      data,
      true,
    );

    final Color statusColor =
        _getStatusColor(
      status,
    );

    final amount =
        (data['totalAmount']
                    as num?)
                ?.toDouble() ??
            0;

    final billingPeriod =
        (data['billingPeriod'] ??
                'N/A')
            .toString();

    final dueDate =
        _getDate(
      data['dueDate'],
    );

    return Card(
      elevation: 3,
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child:
                      Text(
                    _getConsumerName(
                      data,
                    ),
                    style:
                        const TextStyle(
                      fontSize:
                          18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal:
                        10,
                    vertical:
                        6,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        statusColor.withOpacity(
                      0.12,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child:
                      Text(
                    status,
                    style:
                        TextStyle(
                      color:
                          statusColor,
                      fontWeight:
                          FontWeight.bold,
                      fontSize:
                          12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            Text(
              "Account Number: ${_getAccountNumber(data)}",
            ),

            Text(
              "Billing Period: $billingPeriod",
            ),

            FutureBuilder<
                Map<String,
                    dynamic>>(
              future:
                  _getConsumerLocation(
                data,
              ),
              builder: (
                context,
                snapshot,
              ) {
                if (snapshot
                        .connectionState ==
                    ConnectionState.waiting) {
                  return const Padding(
                    padding:
                        EdgeInsets.only(
                      top: 8,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                          ),
                        ),
                        SizedBox(
                          width: 8,
                        ),
                        Text(
                          "Loading location...",
                        ),
                      ],
                    ),
                  );
                }

                return _buildLocationDetails(
                  snapshot.data ??
                      {
                        'barangay':
                            '',
                        'municipality':
                            '',
                        'province':
                            '',
                        'address':
                            '',
                      },
                );
              },
            ),

            const Divider(
              height: 24,
            ),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Consumption",
                  style:
                      TextStyle(
                    color:
                        Colors.grey,
                  ),
                ),
                Text(
                  "${data['consumption'] ?? 0} kWh",
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 6,
            ),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Total Amount",
                  style:
                      TextStyle(
                    color:
                        Colors.grey,
                  ),
                ),
                Text(
                  "₱${amount.toStringAsFixed(2)}",
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize:
                        17,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 6,
            ),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Due Date",
                  style:
                      TextStyle(
                    color:
                        Colors.grey,
                  ),
                ),
                Text(
                  dueDate != null
                      ? "${dueDate.month}/${dueDate.day}/${dueDate.year}"
                      : "N/A",
                ),
              ],
            ),

            if (status == 'Paid') ...[
              const SizedBox(
                height: 12,
              ),

              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(
                  10,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.green.shade50,
                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                ),
                child:
                    const Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color:
                          Colors.green,
                      size:
                          20,
                    ),
                    SizedBox(
                      width:
                          8,
                    ),
                    Text(
                      "Payment received",
                      style:
                          TextStyle(
                        color:
                            Colors.green,
                        fontWeight:
                            FontWeight.w600,
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
  // BUILD PENDING CARD
  // ============================================================

  Widget _buildPendingCard(
    QueryDocumentSnapshot readingDoc,
  ) {
    final data =
        readingDoc.data()
            as Map<String, dynamic>;

    final isProcessing =
        _processingDocId ==
            readingDoc.id;

    return Card(
      elevation: 3,
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child:
                      Text(
                    _getConsumerName(
                      data,
                    ),
                    style:
                        const TextStyle(
                      fontSize:
                          18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal:
                        10,
                    vertical:
                        6,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.blue.withOpacity(
                      0.12,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child:
                      const Text(
                    "Pending",
                    style:
                        TextStyle(
                      color:
                          Colors.blue,
                      fontWeight:
                          FontWeight.bold,
                      fontSize:
                          12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            Text(
              "Account Number: ${_getAccountNumber(data)}",
            ),

            Text(
              "Billing Period: ${data["billingPeriod"] ?? "N/A"}",
            ),

            FutureBuilder<
                Map<String,
                    dynamic>>(
              future:
                  _getConsumerLocation(
                data,
              ),
              builder: (
                context,
                snapshot,
              ) {
                if (snapshot
                        .connectionState ==
                    ConnectionState.waiting) {
                  return const Padding(
                    padding:
                        EdgeInsets.only(
                      top: 8,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                          ),
                        ),
                        SizedBox(
                          width: 8,
                        ),
                        Text(
                          "Loading location...",
                        ),
                      ],
                    ),
                  );
                }

                return _buildLocationDetails(
                  snapshot.data ??
                      {
                        'barangay':
                            '',
                        'municipality':
                            '',
                        'province':
                            '',
                        'address':
                            '',
                      },
                );
              },
            ),

            const SizedBox(
              height: 12,
            ),

            const Divider(),

            Text(
              "Previous Reading: ${data["previousReading"] ?? 0} kWh",
            ),

            Text(
              "Current Reading: ${data["currentReading"] ?? 0} kWh",
            ),

            Text(
              "Consumption: ${data["consumption"] ?? 0} kWh",
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
                icon:
                    isProcessing
                        ? const SizedBox(
                            width:
                                18,
                            height:
                                18,
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
                label:
                    Text(
                  isProcessing
                      ? "VERIFYING..."
                      : "EDIT & VERIFY BILL",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FILTER BAR
  //
  // Layout:
  //
  // [ Status ] [ Month ] [ Sort ]
  //
  // [ Municipality                         v ]
  //
  // [ Barangay                             v ]
  //
  // Barangay is disabled until municipality
  // is selected.
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
      child:
          Column(
        children: [
          // ========================================================
          // ROW 1
          // STATUS + MONTH + SORT
          // ========================================================

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
                height:
                    48,
                width:
                    48,
                decoration:
                    BoxDecoration(
                  color:
                      Colors.grey.shade50,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  border:
                      Border.all(
                    color:
                        Colors.grey.shade300,
                  ),
                ),
                child:
                    PopupMenuButton<
                        String>(
                  tooltip:
                      "Sort",
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
                            "Newest",
                        child:
                            Text(
                          "Newest",
                        ),
                      ),
                      PopupMenuItem(
                        value:
                            "Oldest",
                        child:
                            Text(
                          "Oldest",
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

          // ========================================================
          // ROW 2
          // MUNICIPALITY
          // ========================================================

          _buildMunicipalityFilter(),

          const SizedBox(
            height: 12,
          ),

          // ========================================================
          // ROW 3
          // BARANGAY
          // ========================================================

          _buildBarangayFilter(),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    String message;

    if (_selectedStatus ==
        'Paid') {
      message =
          "No paid bills found";
    } else if (_selectedStatus ==
        'Unpaid') {
      message =
          "No unpaid bills found";
    } else if (_selectedStatus ==
        'Pending') {
      message =
          "No pending meter readings found";
    } else {
      message =
          "No bills or readings found";
    }

    if (_selectedMonth !=
        'All Months') {
      message +=
          "\nfor $_selectedMonth";
    }

    if (_selectedMunicipality !=
        'All Municipalities') {
      message +=
          "\nin $_selectedMunicipality";
    }

    if (_selectedBarangay !=
            'All Barangays' &&
        _selectedBarangay !=
            'Select Municipality First') {
      message +=
          "\nBarangay: $_selectedBarangay";
    }

    return Center(
      child:
          Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size:
                70,
            color:
                Colors.grey.shade400,
          ),

          const SizedBox(
            height:
                15,
          ),

          Text(
            message,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontSize:
                  18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
                8,
          ),

          Text(
            "Try changing the filters.",
            style:
                TextStyle(
              color:
                  Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER SUMMARY
  // ============================================================

  Widget _buildFilterSummary(
    List<QueryDocumentSnapshot> bills,
    List<QueryDocumentSnapshot> readings,
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
          _getStatus(
        data,
        true,
      );

      final amount =
          (data['totalAmount']
                      as num?)
                  ?.toDouble() ??
              0;

      if (status == 'Paid') {
        paidCount++;
        paidAmount +=
            amount;
      } else {
        unpaidCount++;
        unpaidAmount +=
            amount;
      }
    }

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border:
            Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_alt_outlined,
                size:
                    18,
                color:
                    Colors.orange,
              ),

              const SizedBox(
                width:
                    7,
              ),

              Expanded(
                child:
                    Text(
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
            height:
                10,
          ),

          Row(
            children: [
              Expanded(
                child:
                    _summaryItem(
                  "Pending",
                  readings.length
                      .toString(),
                  Colors.blue,
                ),
              ),

              Expanded(
                child:
                    _summaryItem(
                  "Paid",
                  paidCount.toString(),
                  Colors.green,
                ),
              ),

              Expanded(
                child:
                    _summaryItem(
                  "Unpaid",
                  unpaidCount.toString(),
                  Colors.orange,
                ),
              ),
            ],
          ),

          if (_selectedStatus ==
                  'All' ||
              _selectedStatus ==
                  'Paid' ||
              _selectedStatus ==
                  'Unpaid') ...[
            const Divider(
              height:
                  20,
            ),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Paid Amount",
                  style:
                      TextStyle(
                    color:
                        Colors.grey,
                  ),
                ),

                Text(
                  "₱${paidAmount.toStringAsFixed(2)}",
                  style:
                      const TextStyle(
                    color:
                        Colors.green,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height:
                  5,
            ),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Unpaid Amount",
                  style:
                      TextStyle(
                    color:
                        Colors.grey,
                  ),
                ),

                Text(
                  "₱${unpaidAmount.toStringAsFixed(2)}",
                  style:
                      const TextStyle(
                    color:
                        Colors.orange,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // FILTER SUMMARY TITLE
  // ============================================================

  String _getFilterSummaryTitle() {
    final List<String> parts = [];

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

  // ============================================================
  // SUMMARY ITEM
  // ============================================================

  Widget _summaryItem(
    String title,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style:
              TextStyle(
            fontSize:
                20,
            fontWeight:
                FontWeight.bold,
            color:
                color,
          ),
        ),

        const SizedBox(
          height:
              2,
        ),

        Text(
          title,
          style:
              TextStyle(
            fontSize:
                12,
            color:
                Colors.grey.shade600,
          ),
        ),
      ],
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
      appBar:
          AppBar(
        title:
            const Text(
          "Verify Meter Readings",
        ),
        backgroundColor:
            Theme.of(
          context,
        ).primaryColor,
        foregroundColor:
            Colors.white,
      ),

      body:
          Column(
        children: [
          // ========================================================
          // FILTERS
          // ========================================================

          _buildFilterBar(),

          // ========================================================
          // DATA
          // ========================================================

          Expanded(
            child:
                StreamBuilder<QuerySnapshot>(
              stream:
                  _firestore
                      .collection(
                        "bills",
                      )
                      .snapshots(),

              builder: (
                context,
                billSnapshot,
              ) {
                if (billSnapshot
                        .connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                if (billSnapshot.hasError) {
                  return Center(
                    child:
                        Text(
                      "Error loading bills:\n${billSnapshot.error}",
                      textAlign:
                          TextAlign.center,
                    ),
                  );
                }

                return StreamBuilder<
                    QuerySnapshot>(
                  stream:
                      _firestore
                          .collection(
                            "meter_readings",
                          )
                          .where(
                            "status",
                            isEqualTo:
                                "Pending",
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
                        child:
                            Text(
                          "Error loading readings:\n${readingSnapshot.error}",
                          textAlign:
                              TextAlign.center,
                        ),
                      );
                    }

                    final bills =
                        billSnapshot.data?.docs ??
                            [];

                    final pendingReadings =
                        readingSnapshot.data?.docs ??
                            [];

                    // ==================================================
                    // FILTER STATUS + MONTH FIRST
                    // ==================================================

                    final statusMonthBills =
                        bills.where(
                      (doc) {
                        final data =
                            doc.data()
                                as Map<String,
                                    dynamic>;

                        final status =
                            _getStatus(
                          data,
                          true,
                        );

                        if (_selectedStatus ==
                                'Paid' &&
                            status !=
                                'Paid') {
                          return false;
                        }

                        if (_selectedStatus ==
                                'Unpaid' &&
                            status !=
                                'Unpaid') {
                          return false;
                        }

                        if (_selectedStatus ==
                            'Pending') {
                          return false;
                        }

                        return _matchesMonth(
                          data,
                          true,
                        );
                      },
                    ).toList();

                    // ==================================================
                    // FILTER PENDING READINGS
                    // ==================================================

                    final statusMonthReadings =
                        pendingReadings.where(
                      (doc) {
                        final data =
                            doc.data()
                                as Map<String,
                                    dynamic>;

                        if (_selectedStatus !=
                                'All' &&
                            _selectedStatus !=
                                'Pending') {
                          return false;
                        }

                        return _matchesMonth(
                          data,
                          false,
                        );
                      },
                    ).toList();

                    // ==================================================
                    // LOCATION FILTER
                    //
                    // This FutureBuilder is necessary because the
                    // location may come from the users collection.
                    // ==================================================

                    return FutureBuilder<
                        List<
                            List<
                                QueryDocumentSnapshot>>>(
                      future:
                          Future.wait([
                        _filterDocumentsByLocation(
                          statusMonthBills,
                        ),
                        _filterDocumentsByLocation(
                          statusMonthReadings,
                        ),
                      ]),
                      builder: (
                        context,
                        locationSnapshot,
                      ) {
                        if (locationSnapshot
                                .connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child:
                                CircularProgressIndicator(),
                          );
                        }

                        if (locationSnapshot.hasError) {
                          return Center(
                            child:
                                Text(
                              "Error filtering location:\n${locationSnapshot.error}",
                              textAlign:
                                  TextAlign.center,
                            ),
                          );
                        }

                        final filteredBills =
                            locationSnapshot
                                    .data?[0] ??
                                [];

                        final filteredReadings =
                            locationSnapshot
                                    .data?[1] ??
                                [];

                        // ==================================================
                        // SORT
                        // ==================================================

                        final sortedBills =
                            _sortDocuments(
                          filteredBills,
                          isBill:
                              true,
                        );

                        final sortedReadings =
                            _sortDocuments(
                          filteredReadings,
                          isBill:
                              false,
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
                              height:
                                  10,
                            ),

                            // ==================================================
                            // PENDING
                            // ==================================================

                            if (sortedReadings
                                .isNotEmpty) ...[
                              const Padding(
                                padding:
                                    EdgeInsets.only(
                                  left:
                                      2,
                                  bottom:
                                      8,
                                ),
                                child:
                                    Text(
                                  "PENDING METER READINGS",
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
                                (
                                  doc,
                                ) =>
                                    _buildPendingCard(
                                  doc,
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
                                  left:
                                      2,
                                  top:
                                      8,
                                  bottom:
                                      8,
                                ),
                                child:
                                    Text(
                                  "BILL MONITORING",
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
                                (
                                  doc,
                                ) =>
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
            ),
          ),
        ],
      ),
    );
  }
}