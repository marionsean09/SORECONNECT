import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ConsumerBillScreen extends StatefulWidget {
  const ConsumerBillScreen({super.key});

  @override
  State<ConsumerBillScreen> createState() => _ConsumerBillScreenState();
}

class _ConsumerBillScreenState extends State<ConsumerBillScreen> {
  String _selectedFilter = 'All';
  String _selectedSort = 'Newest';

  List<QueryDocumentSnapshot> _filterAndSortBills(
    List<QueryDocumentSnapshot> bills,
  ) {
    List<QueryDocumentSnapshot> result = List.from(bills);

    // FILTER
    if (_selectedFilter != 'All') {
      result = result.where((doc) {
        final bill = doc.data() as Map<String, dynamic>;

        return (bill['status'] ?? '')
                .toString()
                .toLowerCase() ==
            _selectedFilter.toLowerCase();
      }).toList();
    }

    // SORT
    result.sort((a, b) {
      final billA = a.data() as Map<String, dynamic>;
      final billB = b.data() as Map<String, dynamic>;

      final dateA = billA['generatedAt'] as Timestamp?;
      final dateB = billB['generatedAt'] as Timestamp?;

      final amountA =
          ((billA['totalAmount'] as num?) ?? 0).toDouble();

      final amountB =
          ((billB['totalAmount'] as num?) ?? 0).toDouble();

      switch (_selectedSort) {
        case 'Oldest':
          if (dateA == null || dateB == null) return 0;
          return dateA.compareTo(dateB);

        case 'Highest':
          return amountB.compareTo(amountA);

        case 'Lowest':
          return amountA.compareTo(amountB);

        default:
          if (dateA == null || dateB == null) return 0;
          return dateB.compareTo(dateA);
      }
    });

    return result;
  }

  Widget _drop(
    IconData icon,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down),
                items: items
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e,
                        child: Text(
                          e,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("User not logged in."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Bills"),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("bills")
            .where(
              "consumerId",
              isEqualTo: user.uid,
            )
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
                padding: const EdgeInsets.all(16),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No bills available."),
            );
          }

          final bills =
              _filterAndSortBills(snapshot.data!.docs);

          return Column(
            children: [
              // FILTER AND SORT
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _drop(
                        Icons.filter_list,
                        _selectedFilter,
                        ['All', 'Paid', 'Unpaid'],
                        (value) {
                          if (value != null) {
                            setState(() {
                              _selectedFilter = value;
                            });
                          }
                        },
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: _drop(
                        Icons.sort,
                        _selectedSort,
                        ['Newest', 'Oldest', 'Highest', 'Lowest'],
                        (value) {
                          if (value != null) {
                            setState(() {
                              _selectedSort = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // NUMBER OF BILLS
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "${bills.length} bill(s) found",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // BILL LIST
              Expanded(
                child: bills.isEmpty
                    ? const Center(
                        child: Text(
                          "No bills found.",
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          15,
                          0,
                          15,
                          15,
                        ),
                        itemCount: bills.length,
                        itemBuilder: (context, index) {
                          final bill =
                              bills[index].data()
                                  as Map<String, dynamic>;

                          final Timestamp? dueTimestamp =
                              bill["dueDate"] as Timestamp?;

                          final String dueDate =
                              dueTimestamp == null
                                  ? "-"
                                  : DateFormat(
                                      "MMM dd, yyyy",
                                    ).format(
                                      dueTimestamp.toDate(),
                                    );

                          final String status =
                              (bill["status"] ?? "unpaid")
                                  .toString();

                          final Color statusColor =
                              status.toLowerCase() == "paid"
                                  ? Colors.green
                                  : Colors.red;

                          final double totalAmount =
                              ((bill["totalAmount"] as num?) ?? 0)
                                  .toDouble();

                          return Card(
                            elevation: 4,
                            margin: const EdgeInsets.only(
                              bottom: 15,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(15),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "Electric Bill",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      Chip(
                                        backgroundColor:
                                            statusColor.withValues(alpha: .15),
                                        label: Text(
                                          status.toUpperCase(),
                                        ),
                                        labelStyle: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const Divider(),

                                  Text(
                                    "Billing Period: ${bill["billingPeriod"] ?? "-"}",
                                  ),

                                  Text(
                                    "Previous Reading: ${bill["previousReading"] ?? 0} kWh",
                                  ),

                                  Text(
                                    "Current Reading: ${bill["currentReading"] ?? 0} kWh",
                                  ),

                                  Text(
                                    "Consumption: ${bill["consumption"] ?? 0} kWh",
                                  ),

                                  Text(
                                    "Rate per kWh: ₱${bill["ratePerKwh"] ?? 0}",
                                  ),

                                  const SizedBox(height: 10),

                                  Text(
                                    "Due Date: $dueDate",
                                  ),

                                  const SizedBox(height: 10),

                                  Text(
                                    "Generated By: ${bill["generatedBy"] ?? "-"}",
                                  ),

                                  const Divider(),

                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      "₱${totalAmount.toStringAsFixed(2)}",
                                      style: const TextStyle(
                                        color: Color.fromARGB(255, 16, 15, 15),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}