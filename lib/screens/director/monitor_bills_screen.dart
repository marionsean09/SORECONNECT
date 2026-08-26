import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:soreconnect/data/sorsogon_address_data.dart';

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

  DateTime _getBillDate(
    Map<String, dynamic> data,
  ) {
    final date =
        _getDate(data['generatedAt']) ??
        _getDate(data['createdAt']) ??
        _getDate(data['dateGenerated']) ??
        _getDate(data['timestamp']) ??
        _getDate(data['datePosted']);

    return date ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ============================================================
  // NORMALIZE TEXT
  //
  // This is important for accurate location matching.
  //
  // Example:
  // "Salvacion"
  // " salvacion "
  // "SALVACION"
  //
  // will all match.
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
  // GET BILL MUNICIPALITY
  //
  // We intentionally read the municipality DIRECTLY from the
  // bill document.
  // ============================================================

  String _getBillMunicipality(
    Map<String, dynamic> data,
  ) {
    final municipality =
        data['municipality'] ??
        data['city'] ??
        data['town'] ??
        '';

    return municipality.toString().trim();
  }

  // ============================================================
  // GET BILL BARANGAY
  // ============================================================

  String _getBillBarangay(
    Map<String, dynamic> data,
  ) {
    final barangay =
        data['barangay'] ??
        data['brgy'] ??
        data['barangayName'] ??
        '';

    return barangay.toString().trim();
  }

  // ============================================================
  // GET BILL ADDRESS
  // ============================================================

  String _getBillAddress(
    Map<String, dynamic> data,
  ) {
    final address =
        data['address'] ??
        '';

    return address.toString().trim();
  }

  // ============================================================
  // PAYMENT STATUS
  // ============================================================

  bool _isPaid(
    Map<String, dynamic> data,
  ) {
    final status =
        (data['status'] ?? 'unpaid')
            .toString()
            .trim()
            .toLowerCase();

    return status == 'paid';
  }

  // ============================================================
  // FILTER BILLS
  //
  // IMPORTANT:
  // This happens AFTER fetching ALL bills.
  //
  // There is NO Firestore where() query here.
  // ============================================================

  List<QueryDocumentSnapshot> _filterBills(
    List<QueryDocumentSnapshot> docs,
  ) {
    return docs.where((doc) {
      final rawData = doc.data();

      if (rawData is! Map<String, dynamic>) {
        return false;
      }

      final data = rawData;

      // --------------------------------------------------------
      // PAYMENT FILTER
      // --------------------------------------------------------

      if (_paymentFilter == 'Paid') {
        if (!_isPaid(data)) {
          return false;
        }
      }

      if (_paymentFilter == 'Unpaid') {
        if (_isPaid(data)) {
          return false;
        }
      }

      // --------------------------------------------------------
      // MUNICIPALITY FILTER
      // --------------------------------------------------------

      if (_selectedMunicipality !=
          'All Municipalities') {
        final billMunicipality =
            _normalizeText(
          _getBillMunicipality(data),
        );

        final selectedMunicipality =
            _normalizeText(
          _selectedMunicipality,
        );

        if (billMunicipality !=
            selectedMunicipality) {
          return false;
        }
      }

      // --------------------------------------------------------
      // BARANGAY FILTER
      // --------------------------------------------------------

      if (_selectedBarangay !=
          'All Barangays') {
        final billBarangay =
            _normalizeText(
          _getBillBarangay(data),
        );

        final selectedBarangay =
            _normalizeText(
          _selectedBarangay,
        );

        if (billBarangay !=
            selectedBarangay) {
          return false;
        }
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
    final sortedDocs =
        List<QueryDocumentSnapshot>.from(docs);

    sortedDocs.sort((a, b) {
      final dataA =
          a.data() as Map<String, dynamic>;

      final dataB =
          b.data() as Map<String, dynamic>;

      final dateA =
          _getBillDate(dataA);

      final dateB =
          _getBillDate(dataB);

      if (_sortOption == 'Newest') {
        return dateB.compareTo(dateA);
      }

      return dateA.compareTo(dateB);
    });

    return sortedDocs;
  }

  // ============================================================
  // AVAILABLE BARANGAYS
  //
  // Barangays depend on the selected municipality.
  // ============================================================

  List<String> _getAvailableBarangays() {
    if (_selectedMunicipality ==
        'All Municipalities') {
      return [];
    }

    return getBarangaysForMunicipality(
      _selectedMunicipality,
    );
  }

  // ============================================================
  // PAYMENT STATUS TEXT
  // ============================================================

  String _getPaymentStatus(
    Map<String, dynamic> data,
  ) {
    return _isPaid(data)
        ? 'PAID'
        : 'UNPAID';
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(
    DateTime? date,
  ) {
    if (date == null ||
        date.millisecondsSinceEpoch == 0) {
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
    final availableBarangays =
        _getAvailableBarangays();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Monitor Bills',
        ),
        backgroundColor:
            Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),

      body: Column(
        children: [
          // ======================================================
          // FILTER AREA
          // ======================================================

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              8,
            ),
            child: Column(
              children: [
                // ==================================================
                // TITLE + SORT
                // ==================================================

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Bills',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),

                    // ----------------------------------------------
                    // SORT
                    // ----------------------------------------------

                    Container(
                      height: 48,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.grey.shade100,
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
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
                              _sortOption,
                          icon:
                              const Icon(
                            Icons
                                .keyboard_arrow_down,
                            size: 20,
                            color:
                                Colors.grey,
                          ),
                          style:
                              const TextStyle(
                            color:
                                Colors.black87,
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w500,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Newest',
                              child: Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.sort,
                                    size: 18,
                                    color:
                                        Colors.orange,
                                  ),
                                  SizedBox(
                                    width: 7,
                                  ),
                                  Text(
                                    'Newest',
                                  ),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Oldest',
                              child: Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.sort,
                                    size: 18,
                                    color:
                                        Colors.orange,
                                  ),
                                  SizedBox(
                                    width: 7,
                                  ),
                                  Text(
                                    'Oldest',
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onChanged:
                              (value) {
                            if (value != null) {
                              setState(() {
                                _sortOption =
                                    value;
                              });
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    // ----------------------------------------------
                    // PAYMENT
                    // ----------------------------------------------

                    Container(
                      height: 48,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.grey.shade100,
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
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
                              _paymentFilter,
                          icon:
                              const Icon(
                            Icons
                                .keyboard_arrow_down,
                            size: 20,
                            color:
                                Colors.grey,
                          ),
                          style:
                              const TextStyle(
                            color:
                                Colors.black87,
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w500,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'All',
                              child: Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons
                                        .receipt_long,
                                    size: 18,
                                    color:
                                        Colors.orange,
                                  ),
                                  SizedBox(
                                    width: 7,
                                  ),
                                  Text(
                                    'All',
                                  ),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Paid',
                              child: Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons
                                        .check_circle,
                                    size: 18,
                                    color:
                                        Colors.green,
                                  ),
                                  SizedBox(
                                    width: 7,
                                  ),
                                  Text(
                                    'Paid',
                                  ),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Unpaid',
                              child: Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.pending,
                                    size: 18,
                                    color:
                                        Colors.red,
                                  ),
                                  SizedBox(
                                    width: 7,
                                  ),
                                  Text(
                                    'Unpaid',
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onChanged:
                              (value) {
                            if (value != null) {
                              setState(() {
                                _paymentFilter =
                                    value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 10,
                ),

                // ==================================================
                // LOCATION FILTERS
                // ==================================================

                Row(
                  children: [
                    // ----------------------------------------------
                    // MUNICIPALITY
                    // ----------------------------------------------

                    Expanded(
                      child: Container(
                        height: 48,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 10,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              Colors.grey.shade100,
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                          border: Border.all(
                            color:
                                Colors.grey.shade300,
                          ),
                        ),
                        child:
                            DropdownButtonHideUnderline(
                          child:
                              DropdownButton<String>(
                            isExpanded:
                                true,
                            value:
                                _selectedMunicipality,
                            icon:
                                const Icon(
                              Icons
                                  .keyboard_arrow_down,
                              size: 20,
                              color:
                                  Colors.grey,
                            ),
                            style:
                                const TextStyle(
                              color:
                                  Colors.black87,
                              fontSize: 13,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                            items: [
                              const DropdownMenuItem<
                                  String>(
                                value:
                                    'All Municipalities',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons
                                          .location_city,
                                      size: 18,
                                      color:
                                          Colors.orange,
                                    ),
                                    SizedBox(
                                      width: 7,
                                    ),
                                    Text(
                                      'All Municipalities',
                                    ),
                                  ],
                                ),
                              ),

                              ...getSorsogonSecondDistrictMunicipalities()
                                  .map(
                                (
                                  municipality,
                                ) {
                                  return DropdownMenuItem<
                                      String>(
                                    value:
                                        municipality,
                                    child:
                                        Text(
                                      municipality,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                    ),
                                  );
                                },
                              ),
                            ],
                            onChanged:
                                (value) {
                              if (value == null) {
                                return;
                              }

                              setState(() {
                                _selectedMunicipality =
                                    value;

                                // --------------------------------
                                // Only reset Barangay because
                                // barangays depend on municipality.
                                // --------------------------------

                                _selectedBarangay =
                                    'All Barangays';
                              });
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    // ----------------------------------------------
                    // BARANGAY
                    // ----------------------------------------------

                    Expanded(
                      child: Container(
                        height: 48,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 10,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              _selectedMunicipality ==
                                      'All Municipalities'
                                  ? Colors
                                      .grey.shade200
                                  : Colors
                                      .grey.shade100,
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                          border: Border.all(
                            color:
                                Colors.grey.shade300,
                          ),
                        ),
                        child:
                            DropdownButtonHideUnderline(
                          child:
                              DropdownButton<String>(
                            isExpanded:
                                true,

                            value:
                                _selectedBarangay,

                            icon:
                                const Icon(
                              Icons
                                  .keyboard_arrow_down,
                              size: 20,
                              color:
                                  Colors.grey,
                            ),

                            style:
                                const TextStyle(
                              color:
                                  Colors.black87,
                              fontSize: 13,
                              fontWeight:
                                  FontWeight.w500,
                            ),

                            // Disable until municipality
                            // is selected.
                            onChanged:
                                _selectedMunicipality ==
                                        'All Municipalities'
                                    ? null
                                    : (value) {
                                        if (value ==
                                            null) {
                                          return;
                                        }

                                        setState(() {
                                          _selectedBarangay =
                                              value;
                                        });
                                      },

                            items: [
                              const DropdownMenuItem<
                                  String>(
                                value:
                                    'All Barangays',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons
                                          .location_on,
                                      size: 18,
                                      color:
                                          Colors.orange,
                                    ),
                                    SizedBox(
                                      width: 7,
                                    ),
                                    Text(
                                      'All Barangays',
                                    ),
                                  ],
                                ),
                              ),

                              ...availableBarangays
                                  .map(
                                (
                                  barangay,
                                ) {
                                  return DropdownMenuItem<
                                      String>(
                                    value:
                                        barangay,
                                    child:
                                        Text(
                                      barangay,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
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

          // ======================================================
          // BILLS STREAM
          //
          // IMPORTANT:
          // NO where() FILTER HERE.
          //
          // This fetches EVERY bill in Firestore.
          // ======================================================

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore
                  .instance
                  .collection('bills')
                  .snapshots(),

              builder:
                  (context, snapshot) {
                // ------------------------------------------------
                // LOADING
                // ------------------------------------------------

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                // ------------------------------------------------
                // ERROR
                // ------------------------------------------------

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        20,
                      ),
                      child: Text(
                        'Error loading bills:\n\n'
                        '${snapshot.error}',
                        textAlign:
                            TextAlign.center,
                      ),
                    ),
                  );
                }

                // ------------------------------------------------
                // NO DATA
                // ------------------------------------------------

                if (!snapshot.hasData) {
                  return const Center(
                    child:
                        Text('No bills found'),
                  );
                }

                // ------------------------------------------------
                // FETCH ALL DOCUMENTS
                //
                // No location restriction.
                // No payment restriction.
                // ------------------------------------------------

                final allBills =
                    snapshot.data!.docs;

                // ------------------------------------------------
                // APPLY LOCAL FILTERS
                // ------------------------------------------------

                final filteredBills =
                    _filterBills(
                  allBills,
                );

                // ------------------------------------------------
                // SORT AFTER FILTER
                // ------------------------------------------------

                final bills =
                    _sortBills(
                  filteredBills,
                );

                // ------------------------------------------------
                // EMPTY RESULT
                // ------------------------------------------------

                if (bills.isEmpty) {
                  String message =
                      'No bills found';

                  if (_selectedBarangay !=
                      'All Barangays') {
                    message =
                        'No bills found for '
                        '$_selectedBarangay, '
                        '$_selectedMunicipality';
                  } else if (_selectedMunicipality !=
                      'All Municipalities') {
                    message =
                        'No bills found for '
                        '$_selectedMunicipality';
                  } else if (_paymentFilter ==
                      'Paid') {
                    message =
                        'No paid bills found';
                  } else if (_paymentFilter ==
                      'Unpaid') {
                    message =
                        'No unpaid bills found';
                  }

                  return Center(
                    child: Text(
                      message,
                      textAlign:
                          TextAlign.center,
                    ),
                  );
                }

                // ------------------------------------------------
                // BILL LIST
                // ------------------------------------------------

                return ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    16,
                  ),

                  itemCount:
                      bills.length,

                  itemBuilder:
                      (context, index) {
                    final data =
                        bills[index].data()
                            as Map<String,
                                dynamic>;

                    // ==========================================
                    // PAYMENT
                    // ==========================================

                    final isPaid =
                        _isPaid(data);

                    final statusText =
                        _getPaymentStatus(
                      data,
                    );

                    // ==========================================
                    // AMOUNT
                    // ==========================================

                    final amount =
                        data['totalAmount'];

                    double totalAmount =
                        0.0;

                    if (amount is num) {
                      totalAmount =
                          amount.toDouble();
                    } else if (amount
                        is String) {
                      totalAmount =
                          double.tryParse(
                                amount,
                              ) ??
                              0.0;
                    }

                    // ==========================================
                    // DATE
                    // ==========================================

                    final billDate =
                        _getBillDate(
                      data,
                    );

                    final dateText =
                        _formatDate(
                      billDate,
                    );

                    // ==========================================
                    // LOCATION
                    // ==========================================

                    final municipality =
                        _getBillMunicipality(
                      data,
                    );

                    final barangay =
                        _getBillBarangay(
                      data,
                    );

                    final address =
                        _getBillAddress(
                      data,
                    );

                    // ==========================================
                    // BILL CARD
                    // ==========================================

                    return Card(
                      margin:
                          const EdgeInsets.only(
                        bottom: 12,
                      ),

                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),

                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [
                            // ==================================
                            // STATUS ICON
                            // ==================================

                            Padding(
                              padding:
                                  const EdgeInsets
                                      .only(
                                top: 4,
                              ),
                              child:
                                  Icon(
                                isPaid
                                    ? Icons
                                        .check_circle
                                    : Icons
                                        .pending,

                                color: isPaid
                                    ? Colors
                                        .green
                                    : Colors
                                        .orange,

                                size: 32,
                              ),
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            // ==================================
                            // BILL INFORMATION
                            // ==================================

                            Expanded(
                              child:
                                  Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,

                                children: [
                                  // --------------------------------
                                  // CONSUMER
                                  // --------------------------------

                                  Text(
                                    data[
                                            'consumerName'] ??
                                        'Unknown',

                                    maxLines:
                                        1,

                                    overflow:
                                        TextOverflow
                                            .ellipsis,

                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                      fontSize:
                                          16,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 8,
                                  ),

                                  // --------------------------------
                                  // ACCOUNT
                                  // --------------------------------

                                  Text(
                                    'Account: '
                                    '${data['accountNumber'] ?? 'N/A'}',

                                    maxLines:
                                        1,

                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                  ),

                                  const SizedBox(
                                    height: 4,
                                  ),

                                  // --------------------------------
                                  // BILLING PERIOD
                                  // --------------------------------

                                  Text(
                                    'Period: '
                                    '${data['billingPeriod'] ?? 'N/A'}',

                                    maxLines:
                                        1,

                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                  ),

                                  const SizedBox(
                                    height: 6,
                                  ),

                                  // --------------------------------
                                  // LOCATION
                                  // --------------------------------

                                  if (barangay
                                          .isNotEmpty ||
                                      municipality
                                          .isNotEmpty)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        const Icon(
                                          Icons
                                              .location_on,
                                          size:
                                              16,
                                          color:
                                              Colors.orange,
                                        ),
                                        const SizedBox(
                                          width:
                                              4,
                                        ),
                                        Expanded(
                                          child:
                                              Text(
                                            barangay.isNotEmpty &&
                                                    municipality.isNotEmpty
                                                ? '$barangay, $municipality'
                                                : barangay.isNotEmpty
                                                    ? barangay
                                                    : municipality,

                                            maxLines:
                                                2,

                                            overflow:
                                                TextOverflow
                                                    .ellipsis,

                                            style:
                                                const TextStyle(
                                              fontSize:
                                                  12,
                                              color:
                                                  Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else if (address
                                      .isNotEmpty)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        const Icon(
                                          Icons
                                              .location_on,
                                          size:
                                              16,
                                          color:
                                              Colors.orange,
                                        ),
                                        const SizedBox(
                                          width:
                                              4,
                                        ),
                                        Expanded(
                                          child:
                                              Text(
                                            address,
                                            maxLines:
                                                2,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                            style:
                                                const TextStyle(
                                              fontSize:
                                                  12,
                                              color:
                                                  Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Row(
                                      children: const [
                                        Icon(
                                          Icons
                                              .location_off,
                                          size:
                                              16,
                                          color:
                                              Colors.grey,
                                        ),
                                        SizedBox(
                                          width:
                                              4,
                                        ),
                                        Text(
                                          'Location not available',
                                          style:
                                              TextStyle(
                                            fontSize:
                                                12,
                                            color:
                                                Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),

                                  const SizedBox(
                                    height: 6,
                                  ),

                                  // --------------------------------
                                  // GENERATED
                                  // --------------------------------

                                  Text(
                                    'Generated: '
                                    '$dateText',

                                    maxLines:
                                        1,

                                    overflow:
                                        TextOverflow
                                            .ellipsis,

                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.grey,
                                      fontSize:
                                          12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            // ==================================
                            // AMOUNT + STATUS
                            // ==================================

                            SizedBox(
                              width: 105,

                              child:
                                  Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .end,

                                children: [
                                  Text(
                                    '₱${totalAmount.toStringAsFixed(2)}',

                                    maxLines:
                                        1,

                                    overflow:
                                        TextOverflow
                                            .ellipsis,

                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                      fontSize:
                                          16,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 10,
                                  ),

                                  Container(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal:
                                          8,
                                      vertical:
                                          4,
                                    ),

                                    decoration:
                                        BoxDecoration(
                                      color: isPaid
                                          ? Colors
                                              .green
                                          : Colors
                                              .red,

                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        5,
                                      ),
                                    ),

                                    child:
                                        Text(
                                      statusText,

                                      style:
                                          const TextStyle(
                                        color:
                                            Colors
                                                .white,
                                        fontSize:
                                            10,
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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