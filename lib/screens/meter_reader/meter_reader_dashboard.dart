import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:soreconnect/screens/meter_reader/meter_reading_screen.dart';
import 'package:soreconnect/screens/auth/login_screen.dart';
import 'package:soreconnect/screens/shared/staff_profile_screen.dart';
import 'package:soreconnect/utils/pending_email_guard.dart';
import 'package:soreconnect/data/sorsogon_address_data.dart';
import 'package:soreconnect/models/bill_model.dart';
import 'package:soreconnect/utils/bill_calculator.dart';
import 'package:soreconnect/utils/page_transitions.dart';
import 'package:soreconnect/widgets/bill_breakdown_view.dart';
import 'package:soreconnect/widgets/export_bill_sheet.dart';
import 'package:soreconnect/widgets/minimal_filter_bar.dart';
import 'package:soreconnect/widgets/ticket_badge.dart';

class MeterReaderDashboard extends StatefulWidget {
  const MeterReaderDashboard({super.key});

  @override
  State<MeterReaderDashboard> createState() => _MeterReaderDashboardState();
}

class _MeterReaderDashboardState extends State<MeterReaderDashboard>
    with SingleTickerProviderStateMixin {
  static const Color _primaryGreen = Color(0xFF1B5E20);
  static const Color _accentGold = Color(0xFFDAA520);

  // ------------------------------------------------------------
  // FILTERS
  // ------------------------------------------------------------

  String _selectedMunicipality = 'All Municipalities';
  String _selectedBarangay = 'All Barangays';

  String _sortBy = 'Newest';

  // ------------------------------------------------------------
  // SEARCH
  // ------------------------------------------------------------

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Cache consumer locations so we do not repeatedly query Firestore.
  final Map<String, Map<String, dynamic>> _locationCache = {};

  // ------------------------------------------------------------
  // READINGS STREAM
  //
  // Created once (not inline in build()) so typing in the search
  // field — which calls setState() on every keystroke — doesn't
  // make StreamBuilder see a "new" stream, resubscribe, and briefly
  // replace this whole subtree (including the search field) with a
  // loading spinner. That was disposing the TextField's Element on
  // every keystroke, dropping focus/cursor/keyboard mid-word.
  // ------------------------------------------------------------

  late final Stream<QuerySnapshot> _readingsStream;

  // ------------------------------------------------------------
  // ENTRANCE ANIMATION
  // ------------------------------------------------------------

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _logoutPressed = false;

  @override
  void initState() {
    super.initState();

    // Safety net: finishes signing out if an email change was
    // confirmed while this screen wasn't the one watching for it
    // (e.g. backed out of the verify screen, or the app was
    // backgrounded when the confirmation link was tapped).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) checkPendingEmailConfirmed(context);
    });

    final user = FirebaseAuth.instance.currentUser;

    // Matches on EITHER the stable UID (every reading recorded from
    // now on) OR the current sign-in email (older readings recorded
    // before this account ever changed its email). Filtering by
    // email alone broke this list the moment a meter reader changed
    // their email — every reading they'd already recorded still had
    // the OLD email baked in as `recordedBy`, so it silently stopped
    // matching. UID never changes, so it's the reliable half of
    // this OR; the email half is just backward compatibility for
    // readings recorded before `recordedByUid` existed.
    _readingsStream = FirebaseFirestore.instance
        .collection('meter_readings')
        .where(
          Filter.or(
            Filter('recordedByUid', isEqualTo: user?.uid),
            Filter('recordedBy', isEqualTo: user?.email),
          ),
        )
        .snapshots();

    if (user != null) {
      _backfillOrphanedReadings(user.uid);
    }

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: pageTransitionCurve,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(_fadeAnimation);

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // BACKFILL ORPHANED READINGS (ONE-TIME)
  //
  // Readings recorded before this account's email was ever changed
  // only have the OLD email in `recordedBy`, with no `recordedByUid`
  // at all — so they don't match `_readingsStream`'s filter under
  // the new email. This attaches this account's stable UID to any
  // reading still carrying one of its known past emails, so they
  // reappear via the UID half of that filter. Once a document has
  // `recordedByUid`, later runs skip it — cheap to leave running.
  // ------------------------------------------------------------

  static const List<String> _knownPastEmails = [
    'meter_reader1_soreco1@email.com',
  ];

  Future<void> _backfillOrphanedReadings(String uid) async {
    for (final oldEmail in _knownPastEmails) {
      try {
        final orphaned = await FirebaseFirestore.instance
            .collection('meter_readings')
            .where('recordedBy', isEqualTo: oldEmail)
            .where('recordedByUid', isNull: true)
            .get();

        if (orphaned.docs.isEmpty) continue;

        final batch = FirebaseFirestore.instance.batch();

        for (final doc in orphaned.docs) {
          batch.update(doc.reference, {'recordedByUid': uid});
        }

        await batch.commit();
      } catch (e) {
        debugPrint(
          'Failed to backfill readings for $oldEmail: $e',
        );
      }
    }
  }

  // ------------------------------------------------------------
  // LOGOUT
  // ------------------------------------------------------------

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      smoothPageRoute(const LoginScreen()),
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
  // SEARCH MATCHING
  // ------------------------------------------------------------

  bool _matchesSearch(
    Map<String, dynamic> data,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return true;

    final searchable = [
      data['consumerName'],
      data['accountNumber'],
      data['billingPeriod'],
    ].map((v) => (v ?? '').toString().toLowerCase()).join(' ');

    return searchable.contains(query);
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
              color: Colors.black.withValues(alpha: 0.06),
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
      height: 46,
      decoration: BoxDecoration(
        color: enabled
            ? Colors.grey.shade100
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
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
                ? Colors.grey.shade600
                : Colors.grey.shade400,
            size: 20,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(14),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: enabled
                ? Colors.grey.shade800
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
                      size: 17,
                      color: enabled
                          ? (isDefault
                              ? Colors.orange
                              : Colors.grey.shade500)
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item == 'All Barangays' &&
                                _selectedMunicipality ==
                                    'All Municipalities'
                            ? 'Select Municipality First'
                            : item,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
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
    final data = doc.data() as Map<String, dynamic>;

    final status = (data['status'] ?? 'Pending').toString();

    final isVerified = status.toLowerCase() == 'verified' ||
        status.toLowerCase() == 'billed';

    final statusColor = isVerified ? Colors.green : Colors.orange;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showReadingDetailSheet(doc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['consumerName'] ?? 'Unknown Consumer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${data['accountNumber'] ?? 'N/A'} · '
                    '${data['billingPeriod'] ?? 'N/A'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // READING DETAIL SHEET
  // ============================================================

  void _showReadingDetailSheet(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final timestamp = data['recordedAt'] as Timestamp?;

    final date = timestamp != null
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(
            timestamp.toDate(),
          )
        : 'No date';

    final status = (data['status'] ?? 'Pending').toString();

    final isVerified = status.toLowerCase() == 'verified' ||
        status.toLowerCase() == 'billed';

    final location = _getReadingLocation(data);

    final barangay = location['barangay']?.toString() ?? '';
    final municipality = location['municipality']?.toString() ?? '';
    final province = location['province']?.toString() ?? '';
    final address = location['address']?.toString() ?? '';

    final rawBreakdown = data['breakdown'];
    final BillBreakdown? breakdown = rawBreakdown is Map
        ? BillBreakdown.fromMap(Map<String, dynamic>.from(rawBreakdown))
        : null;

    final previousReading =
        (data['previousReading'] as num?)?.toDouble() ?? 0.0;
    final currentReading =
        (data['currentReading'] as num?)?.toDouble() ?? 0.0;
    final consumption =
        (data['consumption'] as num?)?.toDouble() ?? 0.0;

    final ticketNumber = BillModel.ticketNumberFor(data, doc.id);

    // `bill_receipt_pdf.dart` reads the amount under `totalAmount`
    // (the `bills` collection's field name) — meter reading docs
    // store it as `computedAmount`, so map it across for export.
    final exportBill = {
      ...data,
      'totalAmount': data['computedAmount'] ?? 0,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (sheetContext, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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

                  // ------------------------------------------------
                  // TICKET + EXPORT
                  // ------------------------------------------------

                  Row(
                    children: [
                      if (ticketNumber.isNotEmpty)
                        TicketBadge(
                          ticketNumber: ticketNumber,
                          color: _primaryGreen,
                        ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.ios_share),
                        tooltip: 'Export reading',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => showExportBillOptions(
                          sheetContext,
                          bill: exportBill,
                          breakdown: breakdown,
                          ticketNumber: ticketNumber.isNotEmpty
                              ? ticketNumber
                              : doc.id,
                        ),
                      ),
                    ],
                  ),

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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isVerified
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: isVerified
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Account: ${data['accountNumber'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 13),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Meter No: ${data['meterNumber'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 13),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Billing Period: '
                    '${data['billingPeriod'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 13),
                  ),

                  const SizedBox(height: 12),

                  // ------------------------------------------------
                  // LOCATION
                  // ------------------------------------------------

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F8F5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                fontWeight: FontWeight.bold,
                                color: _primaryGreen,
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
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Divider(),

                  // ------------------------------------------------
                  // READINGS / BILL BREAKDOWN
                  // ------------------------------------------------

                  if (breakdown != null) ...[
                    BillBreakdownView(
                      breakdown: breakdown,
                      previousReading: previousReading,
                      currentReading: currentReading,
                      consumption: consumption,
                      municipality: municipality,
                      initiallyExpanded: true,
                    ),
                    const SizedBox(height: 8),
                  ] else ...[
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
                  ],

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
            );
          },
        );
      },
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
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
          Listener(
            onPointerDown: (_) => setState(
              () => _logoutPressed = true,
            ),
            onPointerUp: (_) => setState(
              () => _logoutPressed = false,
            ),
            onPointerCancel: (_) => setState(
              () => _logoutPressed = false,
            ),
            child: AnimatedScale(
              scale: _logoutPressed ? 0.88 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: IconButton(
                icon: const Icon(
                  Icons.logout,
                ),
                onPressed: _logout,
              ),
            ),
          ),
        ],
      ),

      // --------------------------------------------------------
      // BODY
      // --------------------------------------------------------

      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _readingsStream,

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

              return _matchesLocation(data) && _matchesSearch(data);
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

              final status = data['status']
                  ?.toString()
                  .toLowerCase();

              return status == 'verified' ||
                  status == 'billed';
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

            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
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
                              .withValues(
                            alpha: 0.06,
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
                        'Billed',
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
                  // SEARCH
                  // ============================================

                  MinimalSearchField(
                    controller: _searchController,
                    hintText:
                        "Search consumer, account #, billing period...",
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

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

                      MinimalDropdown<String>(
                        value: _sortBy,
                        icon: Icons.sort,
                        items: const [
                          'Newest',
                          'Oldest',
                          'Consumer Name',
                          'Verified',
                        ],
                        itemLabel: (value) {
                          switch (value) {
                            case 'Consumer Name':
                              return 'Name';
                            case 'Verified':
                              return 'Status';
                            default:
                              return value;
                          }
                        },
                        onChanged: (value) {
                          setState(() {
                            _sortBy = value ?? 'Newest';
                          });
                        },
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
                ),
              ),
            );
          },
        ),
      ),

      // --------------------------------------------------------
      // BOTTOM NAVIGATION
      // --------------------------------------------------------

      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          currentIndex: 0,
          elevation: 12,
          onTap: (index) {
            if (index == 1) {
              Navigator.push(
                context,
                smoothPageRoute(const MeterReadingScreen()),
              );
            } else if (index == 2) {
              Navigator.push(
                context,
                smoothPageRoute(
                  const StaffProfileScreen(
                    role: 'Meter Reader',
                    userTypeValue: 'meter_reader',
                  ),
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
            BottomNavigationBarItem(
              icon: Icon(
                Icons.person_outline,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}