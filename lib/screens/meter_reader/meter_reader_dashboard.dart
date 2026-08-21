import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:soreconnect/screens/meter_reader/meter_reading_screen.dart';
import 'package:soreconnect/screens/auth/login_screen.dart';

class MeterReaderDashboard extends StatefulWidget {
  const MeterReaderDashboard({super.key});

  @override
  State<MeterReaderDashboard> createState() =>
      _MeterReaderDashboardState();
}

class _MeterReaderDashboardState
    extends State<MeterReaderDashboard> {
  static const Color _primaryGreen = Color(0xFF1B5E20);
  static const Color _accentGold = Color(0xFFDAA520);

  String _sortBy = 'Newest';

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
    }
  }

  Widget _summaryCard(
    IconData icon,
    String title,
    int value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meter Reader Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),

      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('meter_readings')
              .where(
                'recordedBy',
                isEqualTo: user?.email,
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
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ),
              );
            }

            final readings =
                List<QueryDocumentSnapshot>.from(
              snapshot.data?.docs ?? [],
            );

            // SUMMARY COUNTS
            final total = readings.length;

            final pending = readings.where((doc) {
              final data =
                  doc.data() as Map<String, dynamic>;

              return data['status']
                      ?.toString()
                      .toLowerCase() ==
                  'pending';
            }).length;

            final verified = readings.where((doc) {
              final data =
                  doc.data() as Map<String, dynamic>;

              return data['status']
                      ?.toString()
                      .toLowerCase() ==
                  'verified';
            }).length;

            // SORTING
            readings.sort((a, b) {
              final dataA =
                  a.data() as Map<String, dynamic>;
              final dataB =
                  b.data() as Map<String, dynamic>;

              if (_sortBy == 'Newest') {
                final dateA =
                    dataA['recordedAt'] as Timestamp?;
                final dateB =
                    dataB['recordedAt'] as Timestamp?;

                return (dateB?.millisecondsSinceEpoch ?? 0)
                    .compareTo(
                  dateA?.millisecondsSinceEpoch ?? 0,
                );
              }

              if (_sortBy == 'Oldest') {
                final dateA =
                    dataA['recordedAt'] as Timestamp?;
                final dateB =
                    dataB['recordedAt'] as Timestamp?;

                return (dateA?.millisecondsSinceEpoch ?? 0)
                    .compareTo(
                  dateB?.millisecondsSinceEpoch ?? 0,
                );
              }

              if (_sortBy == 'Consumer Name') {
                return (dataA['consumerName'] ?? '')
                    .toString()
                    .compareTo(
                      (dataB['consumerName'] ?? '')
                          .toString(),
                    );
              }

              if (_sortBy == 'Verified') {
                return (dataB['status'] ?? '')
                    .toString()
                    .toLowerCase()
                    .compareTo(
                      (dataA['status'] ?? '')
                          .toString()
                          .toLowerCase(),
                    );
              }

              return 0;
            });

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                28,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  // HEADER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset:
                              const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meter Reader Dashboard',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                            color: _primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Submit meter readings and track your recorded readings.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SUMMARY
                  const Text(
                    'Reading Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      _summaryCard(
                        Icons.speed,
                        'Total',
                        total,
                        _primaryGreen,
                      ),

                      const SizedBox(width: 10),

                      _summaryCard(
                        Icons.pending_actions,
                        'Pending',
                        pending,
                        Colors.orange,
                      ),

                      const SizedBox(width: 10),

                      _summaryCard(
                        Icons.verified,
                        'Verified',
                        verified,
                        Colors.green,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // INFORMATION
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: _accentGold,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Meter readings are reviewed by the teller before the official bill is generated.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // DETAILS HEADER + SORT
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recorded Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.shade300,
                          ),
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                        child:
                            DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sortBy,
                            icon: const Icon(
                              Icons.sort,
                              size: 20,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Newest',
                                child: Text('Newest'),
                              ),
                              DropdownMenuItem(
                                value: 'Oldest',
                                child: Text('Oldest'),
                              ),
                              DropdownMenuItem(
                                value: 'Consumer Name',
                                child: Text('Name'),
                              ),
                              DropdownMenuItem(
                                value: 'Verified',
                                child: Text('Status'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _sortBy =
                                    value ?? 'Newest';
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // EMPTY STATE
                  if (readings.isEmpty)
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(
                        vertical: 30,
                      ),
                      child: Center(
                        child: Text(
                          'No recorded meter readings yet.',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),

                  // RECORDED DETAILS
                  ...readings.map((doc) {
                    final data =
                        doc.data()
                            as Map<String, dynamic>;

                    final timestamp =
                        data['recordedAt'] as Timestamp?;

                    final date =
                        timestamp != null
                            ? DateFormat(
                                'MMM dd, yyyy • hh:mm a',
                              ).format(
                                timestamp.toDate(),
                              )
                            : 'No date';

                    final status =
                        (data['status'] ?? 'Pending')
                            .toString();

                    final isVerified =
                        status.toLowerCase() ==
                            'verified';

                    return Card(
                      margin:
                          const EdgeInsets.only(
                        bottom: 12,
                      ),
                      elevation: 2,
                      child: Padding(
                        padding:
                            const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [

                            // NAME + STATUS
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    data['consumerName'] ??
                                        'Unknown Consumer',
                                    style:
                                        const TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ),

                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color: isVerified
                                        ? Colors.green
                                            .withOpacity(
                                                0.12)
                                        : Colors.orange
                                            .withOpacity(
                                                0.12),
                                    borderRadius:
                                        BorderRadius
                                            .circular(20),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: isVerified
                                          ? Colors.green
                                          : Colors.orange,
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            Text(
                              'Account: ${data['accountNumber'] ?? 'N/A'}',
                            ),

                            Text(
                              'Billing Period: ${data['billingPeriod'] ?? 'N/A'}',
                            ),

                            const Divider(),

                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .spaceBetween,
                              children: [
                                Text(
                                  'Previous: ${data['previousReading'] ?? 0}',
                                ),
                                Text(
                                  'Current: ${data['currentReading'] ?? 0}',
                                ),
                              ],
                            ),

                            const SizedBox(height: 5),

                            Text(
                              'Consumption: ${data['consumption'] ?? 0} kWh',
                              style: const TextStyle(
                                fontWeight:
                                    FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              date,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const MeterReadingScreen(),
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit),
            label: 'Readings',
          ),
        ],
      ),
    );
  }
}