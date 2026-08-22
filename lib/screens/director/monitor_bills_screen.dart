import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MonitorBillsScreen extends StatefulWidget {
  const MonitorBillsScreen({super.key});

  @override
  State<MonitorBillsScreen> createState() =>
      _MonitorBillsScreenState();
}

class _MonitorBillsScreenState
    extends State<MonitorBillsScreen> {

  // ============================================================
  // SORT OPTION
  // ============================================================

  String _sortOption = 'Newest';

  // ============================================================
  // PAYMENT FILTER
  // ============================================================

  String _paymentFilter = 'All';

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
        _getDate(data['timestamp']);

    return date ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ============================================================
  // FILTER BILLS
  // ============================================================

  List<QueryDocumentSnapshot> _filterBills(
    List<QueryDocumentSnapshot> docs,
  ) {
    if (_paymentFilter == 'All') {
      return docs;
    }

    return docs.where((doc) {
      final data =
          doc.data() as Map<String, dynamic>;

      final status =
          (data['status'] ?? 'unpaid')
              .toString()
              .toLowerCase();

      if (_paymentFilter == 'Paid') {
        return status == 'paid';
      }

      if (_paymentFilter == 'Unpaid') {
        return status != 'paid';
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
      } else {
        return dateA.compareTo(dateB);
      }
    });

    return sortedDocs;
  }

  // ============================================================
  // GET PAYMENT STATUS
  // ============================================================

  String _getPaymentStatus(
    Map<String, dynamic> data,
  ) {
    final status =
        (data['status'] ?? 'unpaid')
            .toString()
            .toLowerCase();

    if (status == 'paid') {
      return 'PAID';
    }

    return 'UNPAID';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
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

          // ====================================================
          // SORT + PAYMENT FILTER
          // ====================================================

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              8,
            ),

            child: Row(
              children: [

                // ==============================================
                // TITLE
                // ==============================================

                const Expanded(
                  child: Text(
                    'All Bills',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                // ==============================================
                // SORT DROPDOWN
                // ==============================================

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

                        // ========================================
                        // NEWEST
                        // ========================================

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

                        // ========================================
                        // OLDEST
                        // ========================================

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
                        if (value !=
                            null) {
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

                // ==============================================
                // PAYMENT FILTER
                // ==============================================

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

                        // ========================================
                        // ALL
                        // ========================================

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

                        // ========================================
                        // PAID
                        // ========================================

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

                        // ========================================
                        // UNPAID
                        // ========================================

                        DropdownMenuItem(
                          value: 'Unpaid',

                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min,

                            children: [
                              Icon(
                                Icons
                                    .pending,
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
                        if (value !=
                            null) {
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
          ),

          // ====================================================
          // BILLS LIST
          // ====================================================

          Expanded(
            child:
                StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore
                      .instance
                      .collection(
                    'bills',
                  )
                      .snapshots(),

              builder:
                  (context, snapshot) {

                // ==============================================
                // LOADING
                // ==============================================

                if (snapshot
                        .connectionState ==
                    ConnectionState
                        .waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                // ==============================================
                // ERROR
                // ==============================================

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                    ),
                  );
                }

                // ==============================================
                // NO DATA
                // ==============================================

                if (!snapshot.hasData ||
                    snapshot.data!.docs
                        .isEmpty) {
                  return const Center(
                    child: Text(
                      'No bills found',
                    ),
                  );
                }

                // ==============================================
                // FILTER
                // ==============================================

                final filteredBills =
                    _filterBills(
                  snapshot.data!.docs,
                );

                // ==============================================
                // SORT
                // ==============================================

                final bills =
                    _sortBills(
                  filteredBills,
                );

                // ==============================================
                // EMPTY AFTER FILTER
                // ==============================================

                if (bills.isEmpty) {
                  return Center(
                    child: Text(
                      _paymentFilter ==
                              'Paid'
                          ? 'No paid bills found'
                          : _paymentFilter ==
                                  'Unpaid'
                              ? 'No unpaid bills found'
                              : 'No bills found',
                    ),
                  );
                }

                // ==============================================
                // LIST
                // ==============================================

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
                        bills[index]
                            .data()
                            as Map<String,
                                dynamic>;

                    // ==========================================
                    // PAYMENT STATUS
                    // ==========================================

                    final isPaid =
                        (data['status'] ??
                                'unpaid')
                            .toString()
                            .toLowerCase() ==
                            'paid';

                    final statusText =
                        _getPaymentStatus(
                      data,
                    );

                    // ==========================================
                    // TOTAL AMOUNT
                    // ==========================================

                    final amount =
                        data['totalAmount'];

                    double totalAmount =
                        0.0;

                    if (amount
                        is num) {
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
                    // BILL DATE
                    // ==========================================

                    final billDate =
                        _getBillDate(
                      data,
                    );

                    String dateText =
                        'Date not available';

                    if (billDate
                        .millisecondsSinceEpoch >
                        0) {
                      dateText =
                          '${billDate.month.toString().padLeft(2, '0')}/'
                          '${billDate.day.toString().padLeft(2, '0')}/'
                          '${billDate.year}';
                    }

                    return Card(
                      margin:
                          const EdgeInsets.only(
                        bottom: 12,
                      ),

                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                          12,
                        ),

                        child: ListTile(
                          contentPadding:
                              EdgeInsets.zero,

                          // ========================================
                          // BILL ICON
                          // ========================================

                          leading:
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

                          // ========================================
                          // CONSUMER
                          // ========================================

                          title:
                              Text(
                            data['consumerName'] ??
                                'Unknown',

                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),

                          // ========================================
                          // BILL INFORMATION
                          // ========================================

                          subtitle:
                              Padding(
                            padding:
                                const EdgeInsets
                                    .only(
                              top: 5,
                            ),

                            child:
                                Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                              children: [

                                Text(
                                  'Account: ${data['accountNumber'] ?? 'N/A'}',
                                ),

                                const SizedBox(
                                  height: 3,
                                ),

                                Text(
                                  'Period: ${data['billingPeriod'] ?? 'N/A'}',
                                ),

                                const SizedBox(
                                  height: 3,
                                ),

                                Text(
                                  'Generated: $dateText',
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

                          // ========================================
                          // AMOUNT + STATUS
                          // ========================================

                          trailing:
                              Column(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,

                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .end,

                            children: [

                              Text(
                                '₱${totalAmount.toStringAsFixed(2)}',

                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize:
                                      16,
                                ),
                              ),

                              const SizedBox(
                                height: 5,
                              ),

                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      8,
                                  vertical:
                                      3,
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
                                        Colors.white,
                                    fontSize:
                                        10,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
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
            ),
          ),
        ],
      ),
    );
  }
}