import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:soreconnect/screens/meter_reader/meter_reading_screen.dart';
import 'package:soreconnect/screens/auth/login_screen.dart';
import 'package:soreconnect/data/sorsogon_address_data.dart';

class MeterReaderDashboard extends StatefulWidget {
  const MeterReaderDashboard({super.key});

  @override
  State<MeterReaderDashboard> createState() => _MeterReaderDashboardState();
}

class _MeterReaderDashboardState extends State<MeterReaderDashboard> {
  static const Color _primaryGreen = Color(0xFF1B5E20);
  static const Color _accentGold = Color(0xFFDAA520);

  // ------------------------------------------------------------
  // FILTERS
  // ------------------------------------------------------------

  String _selectedMunicipality = 'All Municipalities';
  String _selectedBarangay = 'All Barangays';

  String _sortBy = 'Newest';

  // Cache consumer locations so we do not repeatedly query Firestore.
  final Map<String, Map<String, dynamic>> _locationCache = {};

  // ------------------------------------------------------------
  // LOGOUT
  // ------------------------------------------------------------

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  // ------------------------------------------------------------
  // MUNICIPALITIES
  // ------------------------------------------------------------

  List<String> get _municipalities {
    return [
      'All Municipalities',
      ...getSorsogonSecondDistrictMunicipalities(),
    ];
  }

  // ------------------------------------------------------------
  // BARANGAYS
  // ------------------------------------------------------------

  List<String> get _barangays {
    if (_selectedMunicipality == 'All Municipalities') {
      return ['All Barangays'];
    }

    final barangays = getBarangaysForMunicipality(
      _selectedMunicipality,
    );

    return [
      'All Barangays',
      ...barangays,
    ];
  }

  // ------------------------------------------------------------
  // NORMALIZE TEXT
  // ------------------------------------------------------------

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  // ------------------------------------------------------------
  // GET LOCATION FROM READING
  // ------------------------------------------------------------

  Map<String, dynamic> _getReadingLocation(
    Map<String, dynamic> data,
  ) {
    // Direct fields from meter_readings.
    String barangay = _stringValue(
      data['barangay'],
    );

    String municipality = _stringValue(
      data['municipality'],
    );

    if (municipality.isEmpty) {
      municipality = _stringValue(
        data['municipalityName'],
      );
    }

    if (municipality.isEmpty) {
      municipality = _stringValue(
        data['city'],
      );
    }

    if (municipality.isEmpty) {
      municipality = _stringValue(
        data['cityMunicipality'],
      );
    }

    String province = _stringValue(
      data['province'],
    );

    String address = _stringValue(
      data['address'],
    );

    // ----------------------------------------------------------
    // Support a nested location object if your reading uses:
    //
    // location: {
    //   barangay: "...",
    //   municipality: "...",
    //   province: "...",
    //   address: "..."
    // }
    // ----------------------------------------------------------

    final location = data['location'];

    if (location is Map<String, dynamic>) {
      if (barangay.isEmpty) {
        barangay = _stringValue(
          location['barangay'],
        );
      }

      if (municipality.isEmpty) {
        municipality = _stringValue(
          location['municipality'],
        );
      }

      if (municipality.isEmpty) {
        municipality = _stringValue(
          location['city'],
        );
      }

      if (province.isEmpty) {
        province = _stringValue(
          location['province'],
        );
      }

      if (address.isEmpty) {
        address = _stringValue(
          location['address'],
        );
      }
    }

    if (province.isEmpty) {
      province = 'Sorsogon';
    }

    // Build address automatically when barangay and municipality
    // are available but address is empty.
    if (address.isEmpty &&
        municipality.isNotEmpty &&
        barangay.isNotEmpty) {
      try {
        address = buildSorsogonAddress(
          municipality: municipality,
          barangay: barangay,
        );
      } catch (_) {
        address = '$barangay, $municipality, $province';
      }
    }

    return {
      'barangay': barangay,
      'municipality': municipality,
      'province': province,
      'address': address,
    };
  }

  // ------------------------------------------------------------
  // STRING VALUE HELPER
  // ------------------------------------------------------------

  String _stringValue(dynamic value) {
    if (value == null) return '';

    final result = value.toString().trim();

    if (result.isEmpty || result.toLowerCase() == 'null') {
      return '';
    }

    return result;
  }

  // ------------------------------------------------------------
  // ACCOUNT NUMBER NORMALIZATION
  // ------------------------------------------------------------

  String _normalizeAccountNumber(String value) {
    return value.trim();
  }

  // ------------------------------------------------------------
  // FIND USER BY ACCOUNT NUMBER
  // ------------------------------------------------------------

  Future<Map<String, dynamic>?> _findUserByAccountNumber(
    String accountNumber,
  ) async {
    final normalizedAccountNumber =
        _normalizeAccountNumber(accountNumber);

    if (normalizedAccountNumber.isEmpty) {
      return null;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      final fields = [
        'accountNumber',
        'accountNo',
        'account_number',
      ];

      for (final field in fields) {
        try {
          final result = await firestore
              .collection('users')
              .where(
                field,
                isEqualTo: normalizedAccountNumber,
              )
              .limit(1)
              .get();

          if (result.docs.isNotEmpty) {
            return result.docs.first.data();
          }
        } catch (_) {
          // Continue checking the other possible fields.
        }
      }
    } catch (_) {
      // Ignore lookup errors.
    }

    return null;
  }

  // ------------------------------------------------------------
  // GET CONSUMER LOCATION WITH FALLBACK
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> _getConsumerLocation(
    Map<String, dynamic> readingData,
  ) async {
    final directLocation = _getReadingLocation(
      readingData,
    );

    final hasDirectLocation =
        directLocation['barangay'].toString().trim().isNotEmpty ||
        directLocation['municipality'].toString().trim().isNotEmpty ||
        directLocation['address'].toString().trim().isNotEmpty;

    if (hasDirectLocation) {
      return directLocation;
    }

    final accountNumber = _normalizeAccountNumber(
      _stringValue(
        readingData['accountNumber'],
      ),
    );

    if (accountNumber.isEmpty) {
      return directLocation;
    }

    if (_locationCache.containsKey(accountNumber)) {
      return _locationCache[accountNumber]!;
    }

    final userData = await _findUserByAccountNumber(
      accountNumber,
    );

    if (userData == null) {
      return directLocation;
    }

    String barangay = _stringValue(
      userData['barangay'],
    );

    String municipality = _stringValue(
      userData['municipality'],
    );

    if (municipality.isEmpty) {
      municipality = _stringValue(
        userData['municipalityName'],
      );
    }

    if (municipality.isEmpty) {
      municipality = _stringValue(
        userData['city'],
      );
    }

    String province = _stringValue(
      userData['province'],
    );

    if (province.isEmpty) {
      province = 'Sorsogon';
    }

    String address = _stringValue(
      userData['address'],
    );

    if (address.isEmpty &&
        municipality.isNotEmpty &&
        barangay.isNotEmpty) {
      try {
        address = buildSorsogonAddress(
          municipality: municipality,
          barangay: barangay,
        );
      } catch (_) {
        address = '$barangay, $municipality, $province';
      }
    }

    final location = {
      'barangay': barangay,
      'municipality': municipality,
      'province': province,
      'address': address,
    };

    _locationCache[accountNumber] = location;

    return location;
  }

  // ------------------------------------------------------------
  // LOCATION MATCHING
  // ------------------------------------------------------------

  bool _matchesLocation(
    Map<String, dynamic> data,
  ) {
    final location = _getReadingLocation(data);

    final barangay = _normalize(
      location['barangay']?.toString() ?? '',
    );

    final municipality = _normalize(
      location['municipality']?.toString() ?? '',
    );

    // Municipality filter
    if (_selectedMunicipality != 'All Municipalities') {
      if (municipality != _normalize(_selectedMunicipality)) {
        return false;
      }
    }

    // Barangay filter
    if (_selectedBarangay != 'All Barangays') {
      if (barangay != _normalize(_selectedBarangay)) {
        return false;
      }
    }

    return true;
  }

  // ------------------------------------------------------------
  // SUMMARY CARD
  // ------------------------------------------------------------

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
            Icon(
              icon,
              color: color,
              size: 26,
            ),
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

  // ------------------------------------------------------------
  // FILTER DROPDOWN
  // ------------------------------------------------------------

  Widget _buildLocationDropdown({
    required IconData icon,
    required String value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        color: enabled
            ? Colors.white
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value)
              ? value
              : items.first,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: enabled
                ? Colors.grey.shade500
                : Colors.grey.shade400,
            size: 28,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(14),
          style: TextStyle(
            fontSize: 16,
            color: enabled
                ? Colors.black87
                : Colors.grey.shade500,
          ),
          onChanged: enabled ? onChanged : null,
          items: items.map(
            (item) {
              final isDefault =
                  item == 'All Municipalities' ||
                  item == 'All Barangays';

              return DropdownMenuItem<String>(
                value: item,
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 23,
                      color: enabled
                          ? (isDefault
                              ? Colors.orange
                              : Colors.grey.shade500)
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        item == 'All Barangays' &&
                                _selectedMunicipality ==
                                    'All Municipalities'
                            ? 'Select Municipality First'
                            : item,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          color: enabled
                              ? (isDefault
                                  ? Colors.black87
                                  : Colors.black87)
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ).toList(),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // LOCATION FILTER SECTION
  // ------------------------------------------------------------

  Widget _buildLocationFilters() {
    return Column(
      children: [
        _buildLocationDropdown(
          icon: Icons.location_city_rounded,
          value: _selectedMunicipality,
          items: _municipalities,
          hint: 'All Municipalities',
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedMunicipality = value;

              // Reset barangay whenever municipality changes.
              _selectedBarangay = 'All Barangays';
            });
          },
        ),

        const SizedBox(height: 14),

        _buildLocationDropdown(
          icon: Icons.location_on_rounded,
          value: _selectedBarangay,
          items: _barangays,
          hint: 'All Barangays',
          enabled:
              _selectedMunicipality != 'All Municipalities',
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedBarangay = value;
            });
          },
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // LOCATION CARD DETAILS
  // ------------------------------------------------------------

  Widget _locationRow(
    IconData icon,
    String label,
    String value,
  ) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 6,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 17,
            color: _primaryGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: value,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // READING CARD
  // ------------------------------------------------------------

  Widget _buildReadingCard(
    QueryDocumentSnapshot doc,
  ) {
    final data =
        doc.data() as Map<String, dynamic>;

    final timestamp =
        data['recordedAt'] as Timestamp?;

    final date = timestamp != null
        ? DateFormat(
            'MMM dd, yyyy • hh:mm a',
          ).format(
            timestamp.toDate(),
          )
        : 'No date';

    final status =
        (data['status'] ?? 'Pending').toString();

    final isVerified =
        status.toLowerCase() == 'verified';

    final location =
        _getReadingLocation(data);

    final barangay =
        location['barangay']?.toString() ?? '';

    final municipality =
        location['municipality']?.toString() ?? '';

    final province =
        location['province']?.toString() ?? '';

    final address =
        location['address']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            // ------------------------------------------------
            // NAME + STATUS
            // ------------------------------------------------

            Row(
              children: [
                Expanded(
                  child: Text(
                    data['consumerName'] ??
                        'Unknown Consumer',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? Colors.green
                            .withOpacity(0.12)
                        : Colors.orange
                            .withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(20),
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

            // ------------------------------------------------
            // ACCOUNT
            // ------------------------------------------------

            Text(
              'Account: ${data['accountNumber'] ?? 'N/A'}',
              style: const TextStyle(
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 4),

            // ------------------------------------------------
            // BILLING PERIOD
            // ------------------------------------------------

            Text(
              'Billing Period: ${data['billingPeriod'] ?? 'N/A'}',
              style: const TextStyle(
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 10),

            // ------------------------------------------------
            // LOCATION
            // ------------------------------------------------

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F8F5),
                borderRadius:
                    BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.green
                      .withOpacity(0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 18,
                        color: _primaryGreen,
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'Location',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              FontWeight.bold,
                          color:
                              _primaryGreen,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  _locationRow(
                    Icons.location_on_outlined,
                    'Barangay',
                    barangay,
                  ),

                  _locationRow(
                    Icons.location_city_outlined,
                    'Municipality',
                    municipality,
                  ),

                  _locationRow(
                    Icons.map_outlined,
                    'Province',
                    province,
                  ),

                  _locationRow(
                    Icons.home_outlined,
                    'Address',
                    address,
                  ),

                  if (barangay.isEmpty &&
                      municipality.isEmpty &&
                      address.isEmpty)
                    const Text(
                      'Location not available',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle:
                            FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            const Divider(),

            // ------------------------------------------------
            // READINGS
            // ------------------------------------------------

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
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
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 8),

            // ------------------------------------------------
            // DATE
            // ------------------------------------------------

            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 15,
                  color: Colors.grey,
                ),
                const SizedBox(width: 5),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final user =
        FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor:
          const Color(0xFFFFF9ED),

      // --------------------------------------------------------
      // APP BAR
      // --------------------------------------------------------

      appBar: AppBar(
        title: const Text(
          'Meter Reader Dashboard',
        ),
        backgroundColor:
            Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout,
            ),
            onPressed: _logout,
          ),
        ],
      ),

      // --------------------------------------------------------
      // BODY
      // --------------------------------------------------------

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
                child:
                    CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding:
                      const EdgeInsets.all(20),
                  child: Text(
                    'Error: ${snapshot.error}',
                    style:
                        const TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ),
              );
            }

            final allReadings =
                List<QueryDocumentSnapshot>.from(
              snapshot.data?.docs ?? [],
            );

            // --------------------------------------------------
            // APPLY LOCATION FILTER
            // --------------------------------------------------

            final readings =
                allReadings.where((doc) {
              final data =
                  doc.data()
                      as Map<String, dynamic>;

              return _matchesLocation(data);
            }).toList();

            // --------------------------------------------------
            // SUMMARY COUNTS
            // --------------------------------------------------

            final total =
                readings.length;

            final pending =
                readings.where((doc) {
              final data =
                  doc.data()
                      as Map<String, dynamic>;

              return data['status']
                      ?.toString()
                      .toLowerCase() ==
                  'pending';
            }).length;

            final verified =
                readings.where((doc) {
              final data =
                  doc.data()
                      as Map<String, dynamic>;

              return data['status']
                      ?.toString()
                      .toLowerCase() ==
                  'verified';
            }).length;

            // --------------------------------------------------
            // SORTING
            // --------------------------------------------------

            readings.sort((a, b) {
              final dataA =
                  a.data()
                      as Map<String, dynamic>;

              final dataB =
                  b.data()
                      as Map<String, dynamic>;

              if (_sortBy == 'Newest') {
                final dateA =
                    dataA['recordedAt']
                        as Timestamp?;

                final dateB =
                    dataB['recordedAt']
                        as Timestamp?;

                return
                    (dateB?.millisecondsSinceEpoch ??
                            0)
                        .compareTo(
                  dateA?.millisecondsSinceEpoch ??
                      0,
                );
              }

              if (_sortBy == 'Oldest') {
                final dateA =
                    dataA['recordedAt']
                        as Timestamp?;

                final dateB =
                    dataB['recordedAt']
                        as Timestamp?;

                return
                    (dateA?.millisecondsSinceEpoch ??
                            0)
                        .compareTo(
                  dateB?.millisecondsSinceEpoch ??
                      0,
                );
              }

              if (_sortBy ==
                  'Consumer Name') {
                return
                    (dataA['consumerName'] ??
                            '')
                        .toString()
                        .compareTo(
                  (dataB['consumerName'] ??
                          '')
                      .toString(),
                );
              }

              if (_sortBy == 'Verified') {
                return
                    (dataB['status'] ?? '')
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

            // --------------------------------------------------
            // UI
            // --------------------------------------------------

            return SingleChildScrollView(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                28,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  // ============================================
                  // HEADER
                  // ============================================

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(18),
                    decoration:
                        BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withOpacity(
                            0.06,
                          ),
                          blurRadius: 12,
                          offset:
                              const Offset(
                            0,
                            6,
                          ),
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
                            color:
                                _primaryGreen,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
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

                  // ============================================
                  // LOCATION FILTER
                  // ============================================

                  const Text(
                    'Filter by Location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _buildLocationFilters(),

                  const SizedBox(height: 10),

                  // FILTER INFORMATION
                  if (_selectedMunicipality !=
                          'All Municipalities' ||
                      _selectedBarangay !=
                          'All Barangays')
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFE8F5E9,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.filter_alt,
                            size: 17,
                            color:
                                _primaryGreen,
                          ),
                          const SizedBox(
                            width: 7,
                          ),
                          Expanded(
                            child: Text(
                              _selectedBarangay !=
                                      'All Barangays'
                                  ? 'Showing readings from $_selectedBarangay, $_selectedMunicipality'
                                  : 'Showing readings from $_selectedMunicipality',
                              style:
                                  const TextStyle(
                                fontSize: 12,
                                color:
                                    _primaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // ============================================
                  // SUMMARY
                  // ============================================

                  const Text(
                    'Reading Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
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

                      const SizedBox(
                        width: 10,
                      ),

                      _summaryCard(
                        Icons.pending_actions,
                        'Pending',
                        pending,
                        Colors.orange,
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      _summaryCard(
                        Icons.verified,
                        'Verified',
                        verified,
                        Colors.green,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ============================================
                  // INFORMATION
                  // ============================================

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(14),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFFE8F5E9,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: _accentGold,
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        const Expanded(
                          child: Text(
                            'Meter readings are reviewed by the teller before the official bill is generated.',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  Color(
                                0xFF2E7D32,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ============================================
                  // DETAILS HEADER + SORT
                  // ============================================

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Recorded Details (${readings.length})',
                          style:
                              const TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 10,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors
                                .grey
                                .shade300,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                        ),
                        child:
                            DropdownButtonHideUnderline(
                          child:
                              DropdownButton<
                                  String>(
                            value: _sortBy,
                            icon:
                                const Icon(
                              Icons.sort,
                              size: 20,
                            ),
                            items:
                                const [
                              DropdownMenuItem(
                                value:
                                    'Newest',
                                child:
                                    Text(
                                  'Newest',
                                ),
                              ),
                              DropdownMenuItem(
                                value:
                                    'Oldest',
                                child:
                                    Text(
                                  'Oldest',
                                ),
                              ),
                              DropdownMenuItem(
                                value:
                                    'Consumer Name',
                                child:
                                    Text(
                                  'Name',
                                ),
                              ),
                              DropdownMenuItem(
                                value:
                                    'Verified',
                                child:
                                    Text(
                                  'Status',
                                ),
                              ),
                            ],
                            onChanged:
                                (value) {
                              setState(() {
                                _sortBy =
                                    value ??
                                        'Newest';
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ============================================
                  // EMPTY STATE
                  // ============================================

                  if (readings.isEmpty)
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 40,
                        horizontal: 20,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons
                                .location_off_outlined,
                            size: 45,
                            color: Colors
                                .grey
                                .shade400,
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          const Text(
                            'No recorded meter readings found.',
                            style: TextStyle(
                              color:
                                  Colors.grey,
                              fontWeight:
                                  FontWeight
                                      .w500,
                            ),
                            textAlign:
                                TextAlign
                                    .center,
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          if (_selectedMunicipality !=
                                  'All Municipalities' ||
                              _selectedBarangay !=
                                  'All Barangays')
                            const Text(
                              'Try changing the selected location filter.',
                              style:
                                  TextStyle(
                                color:
                                    Colors.grey,
                                fontSize: 12,
                              ),
                              textAlign:
                                  TextAlign
                                      .center,
                            ),
                        ],
                      ),
                    ),

                  // ============================================
                  // RECORDED DETAILS
                  // ============================================

                  ...readings.map(
                    (doc) => _buildReadingCard(
                      doc,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),

      // --------------------------------------------------------
      // BOTTOM NAVIGATION
      // --------------------------------------------------------

      bottomNavigationBar:
          BottomNavigationBar(
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
            icon: Icon(
              Icons.home_outlined,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.edit,
            ),
            label: 'Readings',
          ),
        ],
      ),
    );
  }
}