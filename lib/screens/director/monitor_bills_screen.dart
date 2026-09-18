import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:soreconnect/data/sorsogon_address_data.dart';
import 'package:soreconnect/models/bill_model.dart';
import 'package:soreconnect/utils/bill_calculator.dart';
import 'package:soreconnect/widgets/bill_breakdown_view.dart';
import 'package:soreconnect/widgets/minimal_filter_bar.dart';
import 'package:soreconnect/widgets/ticket_badge.dart';

class MonitorBillsScreen extends StatefulWidget {
  const MonitorBillsScreen({super.key});

  @override
  State<MonitorBillsScreen> createState() => _MonitorBillsScreenState();
}

class _MonitorBillsScreenState extends State<MonitorBillsScreen> {
  // ============================================================
  // SORT
  // ============================================================

  String _sortOption = 'Newest';

  // ============================================================
  // PAYMENT FILTER
  // ============================================================

  String _paymentFilter = 'All';

  // ============================================================
  // LOCATION FILTER
  // ============================================================

  String _selectedMunicipality = 'All Municipalities';
  String _selectedBarangay = 'All Barangays';

  // ============================================================
  // SEARCH
  // ============================================================

  final TextEditingController _searchController =
      TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOCATION CACHE
  // ============================================================

  final Map<String, Map<String, dynamic>> _locationCache = {};

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
  // GET BILL DATE
  // ============================================================

  DateTime _getBillDate(Map<String, dynamic> data) {
    final date =
        _getDate(data['generatedAt']) ??
        _getDate(data['createdAt']) ??
        _getDate(data['dateGenerated']) ??
        _getDate(data['timestamp']) ??
        _getDate(data['datePosted']);

    return date ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ============================================================
  // NORMALIZE TEXT
  // ============================================================

  String _normalizeText(dynamic value) {
    if (value == null) {
      return '';
    }

    return value
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  // ============================================================
  // GET STRING VALUE
  // ============================================================

  String _getStringValue(
    Map<String, dynamic> data,
    List<String> fields,
  ) {
    for (final field in fields) {
      final value = data[field];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  // ============================================================
  // GET CONSUMER ID
  // ============================================================

  String _getConsumerId(Map<String, dynamic> data) {
    return _getStringValue(
      data,
      [
        'consumerId',
        'consumerUid',
        'userId',
        'uid',
        'userUid',
      ],
    );
  }

  // ============================================================
  // GET ACCOUNT NUMBER
  // ============================================================

  String _getAccountNumber(Map<String, dynamic> data) {
    return _getStringValue(
      data,
      [
        'accountNumber',
        'consumerAccountNumber',
        'accountNo',
        'consumerAccountNo',
      ],
    );
  }

  // ============================================================
  // GET BILL MUNICIPALITY
  // ============================================================

  String _getBillMunicipality(Map<String, dynamic> data) {
    return _getStringValue(
      data,
      [
        'municipality',
        'city',
        'town',
      ],
    );
  }

  // ============================================================
  // GET BILL BARANGAY
  // ============================================================

  String _getBillBarangay(Map<String, dynamic> data) {
    return _getStringValue(
      data,
      [
        'barangay',
        'brgy',
        'barangayName',
      ],
    );
  }

  // ============================================================
  // GET BILL ADDRESS
  // ============================================================

  String _getBillAddress(Map<String, dynamic> data) {
    return _getStringValue(
      data,
      [
        'address',
        'fullAddress',
      ],
    );
  }

  // ============================================================
  // CHECK IF LOCATION EXISTS
  // ============================================================

  bool _hasLocation(Map<String, dynamic> location) {
    final municipality = location['municipality']?.toString().trim() ?? '';
    final barangay = location['barangay']?.toString().trim() ?? '';
    final address = location['address']?.toString().trim() ?? '';

    return municipality.isNotEmpty ||
        barangay.isNotEmpty ||
        address.isNotEmpty;
  }

  // ============================================================
  // CREATE LOCATION FROM USER PROFILE
  // ============================================================

  Map<String, dynamic> _createUserLocation(
    Map<String, dynamic> userData,
  ) {
    return {
      'municipality': _getStringValue(
        userData,
        [
          'municipality',
          'city',
          'town',
        ],
      ),
      'barangay': _getStringValue(
        userData,
        [
          'barangay',
          'brgy',
          'barangayName',
        ],
      ),
      'province': _getStringValue(
        userData,
        [
          'province',
        ],
      ),
      'address': _getStringValue(
        userData,
        [
          'address',
          'fullAddress',
        ],
      ),
    };
  }

  // ============================================================
  // RESOLVE BILL LOCATION
  // ============================================================

  Future<Map<String, dynamic>> _resolveBillLocation(
    QueryDocumentSnapshot billDoc,
  ) async {
    final rawData = billDoc.data();

    if (rawData is! Map<String, dynamic>) {
      return {};
    }

    final data = rawData;

    final consumerId = _getConsumerId(data);
    final accountNumber = _getAccountNumber(data);

    final cacheKey = consumerId.isNotEmpty
        ? 'uid_$consumerId'
        : accountNumber.isNotEmpty
        ? 'account_$accountNumber'
        : 'bill_${billDoc.id}';

    if (_locationCache.containsKey(cacheKey)) {
      return _locationCache[cacheKey]!;
    }

    try {
      // ========================================================
      // PRIORITY 1: SEARCH USER BY UID
      // ========================================================

      if (consumerId.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(consumerId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();

          if (userData != null) {
            final location = _createUserLocation(userData);

            if (_hasLocation(location)) {
              _locationCache[cacheKey] = location;
              return location;
            }
          }
        }
      }

      // ========================================================
      // PRIORITY 2: SEARCH USER BY ACCOUNT NUMBER
      // ========================================================

      if (accountNumber.isNotEmpty) {
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where(
              'accountNumber',
              isEqualTo: accountNumber,
            )
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userData = userQuery.docs.first.data();

          final location = _createUserLocation(userData);

          if (_hasLocation(location)) {
            _locationCache[cacheKey] = location;
            return location;
          }
        }
      }
    } catch (e) {
      debugPrint(
        'Error getting latest consumer location: $e',
      );
    }

    // ==========================================================
    // FALLBACK LOCATION FROM BILL
    // ==========================================================

    final fallbackLocation = {
      'municipality': _getBillMunicipality(data),
      'barangay': _getBillBarangay(data),
      'province': _getStringValue(
        data,
        ['province'],
      ),
      'address': _getBillAddress(data),
    };

    _locationCache[cacheKey] = fallbackLocation;

    return fallbackLocation;
  }

  // ============================================================
  // RESOLVE ALL BILL LOCATIONS
  // ============================================================

  Future<Map<String, Map<String, dynamic>>> _resolveAllBillLocations(
    List<QueryDocumentSnapshot> bills,
  ) async {
    final locations = <String, Map<String, dynamic>>{};

    for (final bill in bills) {
      final location = await _resolveBillLocation(bill);

      locations[bill.id] = location;
    }

    return locations;
  }

  // ============================================================
  // PAYMENT STATUS
  // ============================================================

  String _normalizedStatus(Map<String, dynamic> data) {
    return (data['status'] ?? 'unpaid')
        .toString()
        .trim()
        .toLowerCase();
  }

  bool _isPaid(Map<String, dynamic> data) {
    return _normalizedStatus(data) == 'paid';
  }

  bool _isCancelled(Map<String, dynamic> data) {
    final status = _normalizedStatus(data);
    return status == 'cancelled' || status == 'canceled';
  }

  // ============================================================
  // CHECK LOCATION MATCH
  // ============================================================

  bool _matchesLocation(Map<String, dynamic> location) {
    if (_selectedMunicipality != 'All Municipalities') {
      final municipality = _normalizeText(
        location['municipality'],
      );

      final selectedMunicipality = _normalizeText(
        _selectedMunicipality,
      );

      if (municipality != selectedMunicipality) {
        return false;
      }
    }

    if (_selectedBarangay != 'All Barangays') {
      final barangay = _normalizeText(
        location['barangay'],
      );

      final selectedBarangay = _normalizeText(
        _selectedBarangay,
      );

      if (barangay != selectedBarangay) {
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // FILTER BILLS
  // ============================================================

  // ============================================================
  // SEARCH FILTER
  // ============================================================

  bool _matchesSearch(
    Map<String, dynamic> data,
    Map<String, dynamic> location,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return true;

    final searchable = [
      data['consumerName'],
      _getAccountNumber(data),
      data['billingPeriod'],
      data['status'],
      data['generatedBy'],
      location['municipality'],
      location['barangay'],
      location['address'],
    ].map((v) => (v ?? '').toString().toLowerCase()).join(' ');

    return searchable.contains(query);
  }

  List<QueryDocumentSnapshot> _filterBills(
    List<QueryDocumentSnapshot> docs,
    Map<String, Map<String, dynamic>> locations,
  ) {
    return docs.where((doc) {
      final rawData = doc.data();

      if (rawData is! Map<String, dynamic>) {
        return false;
      }

      final data = rawData;

      // PAYMENT FILTER

      if (_paymentFilter == 'Paid' && !_isPaid(data)) {
        return false;
      }

      if (_paymentFilter == 'Unpaid' &&
          (_isPaid(data) || _isCancelled(data))) {
        return false;
      }

      if (_paymentFilter == 'Cancelled' && !_isCancelled(data)) {
        return false;
      }

      // LOCATION FILTER

      final location = locations[doc.id] ?? {};

      if (!_matchesLocation(location)) {
        return false;
      }

      // SEARCH FILTER

      if (!_matchesSearch(data, location)) {
        return false;
      }

      return true;
    }).toList();
  }

  // ============================================================
  // SORT BILLS
  // ============================================================

  List<QueryDocumentSnapshot> _sortBills(
    List<QueryDocumentSnapshot> docs,
  ) {
    final sortedDocs = List<QueryDocumentSnapshot>.from(docs);

    sortedDocs.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;

      final dateA = _getBillDate(dataA);
      final dateB = _getBillDate(dataB);

      if (_sortOption == 'Newest') {
        return dateB.compareTo(dateA);
      }

      return dateA.compareTo(dateB);
    });

    return sortedDocs;
  }

  // ============================================================
  // AVAILABLE BARANGAYS
  // ============================================================

  List<String> _getAvailableBarangays() {
    if (_selectedMunicipality == 'All Municipalities') {
      return [];
    }

    return getBarangaysForMunicipality(
      _selectedMunicipality,
    );
  }

  // ============================================================
  // PAYMENT STATUS TEXT
  // ============================================================

  String _getPaymentStatus(Map<String, dynamic> data) {
    if (_isPaid(data)) return 'PAID';
    if (_isCancelled(data)) return 'CANCELLED';
    return 'UNPAID';
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(DateTime? date) {
    if (date == null || date.millisecondsSinceEpoch == 0) {
      return 'Date not available';
    }

    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final availableBarangays = _getAvailableBarangays();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Monitor Bills',
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ====================================================
          // FILTER AREA
          // ====================================================

          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              8,
            ),
            child: Column(
              children: [
                MinimalSearchField(
                  controller: _searchController,
                  hintText:
                      "Search consumer, account #, billing "
                      "period, location...",
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Bills',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // SORT

                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortOption,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            size: 20,
                            color: Colors.grey,
                          ),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Newest',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.sort,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 7),
                                  Text('Newest'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Oldest',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.sort,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 7),
                                  Text('Oldest'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _sortOption = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // PAYMENT

                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _paymentFilter,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            size: 20,
                            color: Colors.grey,
                          ),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'All',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 7),
                                  Text('All'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Paid',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 18,
                                    color: Colors.green,
                                  ),
                                  SizedBox(width: 7),
                                  Text('Paid'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Unpaid',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.pending,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 7),
                                  Text('Unpaid'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Cancelled',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.cancel,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(width: 7),
                                  Text('Cancelled'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _paymentFilter = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // LOCATION FILTERS

                Row(
                  children: [
                    // MUNICIPALITY

                    Expanded(
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedMunicipality,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 20,
                              color: Colors.grey,
                            ),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: 'All Municipalities',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_city,
                                      size: 18,
                                      color: Colors.orange,
                                    ),
                                    SizedBox(width: 7),
                                    Text('All Municipalities'),
                                  ],
                                ),
                              ),
                              ...getSorsogonSecondDistrictMunicipalities().map(
                                (municipality) {
                                  return DropdownMenuItem<String>(
                                    value: municipality,
                                    child: Text(
                                      municipality,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;

                              setState(() {
                                _selectedMunicipality = value;
                                _selectedBarangay = 'All Barangays';
                              });
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // BARANGAY

                    Expanded(
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedMunicipality ==
                                  'All Municipalities'
                              ? Colors.grey.shade200
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedBarangay,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 20,
                              color: Colors.grey,
                            ),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            onChanged:
                                _selectedMunicipality ==
                                    'All Municipalities'
                                ? null
                                : (value) {
                                    if (value == null) return;

                                    setState(() {
                                      _selectedBarangay = value;
                                    });
                                  },
                            items: [
                              const DropdownMenuItem<String>(
                                value: 'All Barangays',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 18,
                                      color: Colors.orange,
                                    ),
                                    SizedBox(width: 7),
                                    Text('All Barangays'),
                                  ],
                                ),
                              ),
                              ...availableBarangays.map(
                                (barangay) {
                                  return DropdownMenuItem<String>(
                                    value: barangay,
                                    child: Text(
                                      barangay,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ====================================================
          // BILLS STREAM
          // ====================================================

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bills')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Error loading bills:\n\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: Text('No bills found'),
                  );
                }

                final allBills = snapshot.data!.docs;

                return FutureBuilder<Map<String, Map<String, dynamic>>>(
                  future: _resolveAllBillLocations(allBills),
                  builder: (context, locationSnapshot) {
                    if (locationSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (locationSnapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Error loading consumer locations:\n\n'
                            '${locationSnapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final locations = locationSnapshot.data ?? {};

                    final filteredBills = _filterBills(
                      allBills,
                      locations,
                    );

                    final bills = _sortBills(filteredBills);

                    if (bills.isEmpty) {
                      String message = 'No bills found';

                      if (_searchQuery.trim().isNotEmpty) {
                        message =
                            'No bills match '
                            '"${_searchQuery.trim()}". '
                            'Try a different keyword.';
                      } else if (_selectedBarangay != 'All Barangays') {
                        message =
                            'No bills found for $_selectedBarangay, '
                            '$_selectedMunicipality';
                      } else if (_selectedMunicipality !=
                          'All Municipalities') {
                        message =
                            'No bills found for $_selectedMunicipality';
                      } else if (_paymentFilter == 'Paid') {
                        message = 'No paid bills found';
                      } else if (_paymentFilter == 'Unpaid') {
                        message = 'No unpaid bills found';
                      }

                      return Center(
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        16,
                      ),
                      itemCount: bills.length,
                      itemBuilder: (context, index) {
                        final billDoc = bills[index];

                        final data =
                            billDoc.data() as Map<String, dynamic>;

                        final ticketNumber = BillModel.ticketNumberFor(
                          data,
                          billDoc.id,
                        );

                        // PAYMENT

                        final isPaid = _isPaid(data);
                        final isCancelled = _isCancelled(data);

                        final statusText = _getPaymentStatus(data);

                        final statusColor = isPaid
                            ? Colors.green
                            : isCancelled
                                ? Colors.grey
                                : Colors.red;

                        // AMOUNT

                        final amount = data['totalAmount'];

                        double totalAmount = 0.0;

                        if (amount is num) {
                          totalAmount = amount.toDouble();
                        } else if (amount is String) {
                          totalAmount =
                              double.tryParse(amount) ?? 0.0;
                        }

                        // BREAKDOWN

                        final rawBreakdown = data['breakdown'];
                        final BillBreakdown? breakdown = rawBreakdown is Map
                            ? BillBreakdown.fromMap(
                                Map<String, dynamic>.from(rawBreakdown),
                              )
                            : null;

                        final previousReading =
                            (data['previousReading'] as num?)?.toDouble() ??
                                0.0;
                        final currentReading =
                            (data['currentReading'] as num?)?.toDouble() ??
                                0.0;
                        final consumption =
                            (data['consumption'] as num?)?.toDouble() ?? 0.0;

                        // DATE

                        final billDate = _getBillDate(data);

                        final dateText = _formatDate(billDate);

                        // LOCATION

                        final location = locations[billDoc.id] ?? {};

                        final municipality =
                            location['municipality']
                                ?.toString()
                                .trim() ??
                            '';

                        final barangay =
                            location['barangay']?.toString().trim() ?? '';

                        final address =
                            location['address']?.toString().trim() ?? '';

                        // BILL CARD

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showBillDetail(
                            context,
                            data: data,
                            breakdown: breakdown,
                            previousReading: previousReading,
                            currentReading: currentReading,
                            consumption: consumption,
                            totalAmount: totalAmount,
                            municipality: municipality,
                          ),
                          child: Card(
                          margin: const EdgeInsets.only(
                            bottom: 12,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // STATUS ICON

                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Icon(
                                    isPaid
                                        ? Icons.check_circle
                                        : isCancelled
                                            ? Icons.cancel
                                            : Icons.pending,
                                    color: statusColor,
                                    size: 32,
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // BILL INFORMATION

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (ticketNumber.isNotEmpty) ...[
                                        TicketBadge(
                                          ticketNumber: ticketNumber,
                                          color: Theme.of(
                                            context,
                                          ).primaryColor,
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      Text(
                                        data['consumerName'] ?? 'Unknown',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      Text(
                                        'Account: '
                                        '${data['accountNumber'] ?? 'N/A'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),

                                      const SizedBox(height: 4),

                                      Text(
                                        'Period: '
                                        '${data['billingPeriod'] ?? 'N/A'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),

                                      const SizedBox(height: 6),

                                      // LOCATION DISPLAY

                                      if (barangay.isNotEmpty ||
                                          municipality.isNotEmpty)
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.location_on,
                                              size: 16,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                barangay.isNotEmpty &&
                                                        municipality.isNotEmpty
                                                    ? '$barangay, $municipality'
                                                    : barangay.isNotEmpty
                                                    ? barangay
                                                    : municipality,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      else if (address.isNotEmpty)
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.location_on,
                                              size: 16,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                address,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        const Row(
                                          children: [
                                            Icon(
                                              Icons.location_off,
                                              size: 16,
                                              color: Colors.grey,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Location not available',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),

                                      const SizedBox(height: 6),

                                      Text(
                                        'Generated: $dateText',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // AMOUNT + STATUS

                                SizedBox(
                                  width: 105,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₱${totalAmount.toStringAsFixed(2)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

  // ============================================================
  // BILL DETAIL SHEET
  // ============================================================

  void _showBillDetail(
    BuildContext context, {
    required Map<String, dynamic> data,
    required BillBreakdown? breakdown,
    required double previousReading,
    required double currentReading,
    required double consumption,
    required double totalAmount,
    required String municipality,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    data['consumerName'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Account: ${data['accountNumber'] ?? 'N/A'} · '
                    '${data['billingPeriod'] ?? 'N/A'}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  if (breakdown != null)
                    BillBreakdownView(
                      breakdown: breakdown,
                      previousReading: previousReading,
                      currentReading: currentReading,
                      consumption: consumption,
                      municipality: municipality,
                      initiallyExpanded: true,
                    )
                  else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Consumption: ${consumption.toStringAsFixed(2)} kWh',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Total Amount: ₱${totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'This bill was generated before itemized '
                              'breakdowns were tracked.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}