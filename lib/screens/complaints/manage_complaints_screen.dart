import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:soreconnect/data/sorsogon_address_data.dart';

class ManageComplaintsScreen extends StatefulWidget {
  const ManageComplaintsScreen({super.key});

  @override
  State<ManageComplaintsScreen> createState() =>
      _ManageComplaintsScreenState();
}

class _ManageComplaintsScreenState extends State<ManageComplaintsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // COLORS / THEME
  // ============================================================

  static const Color primaryOrange = Color(0xFFFFA000);
  static const Color backgroundColor = Color(0xFFFFF8E7);
  static const Color locationBackground = Color(0xFFF1F8F2);
  static const Color locationBorder = Color(0xFFB8D7BE);

  // ============================================================
  // FILTERS
  // ============================================================

  String _statusFilter = 'All Statuses';
  String _municipalityFilter = 'All Municipalities';
  String _barangayFilter = 'All Barangays';
  String _sortOption = 'Newest';

  // ============================================================
  // LOCATION CACHE
  // ============================================================

  final Map<String, Map<String, dynamic>> _locationCache = {};

  // ============================================================
  // SAFE STRING
  // ============================================================

  String _cleanString(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  // ============================================================
  // DATE
  // ============================================================

  DateTime? _getDate(dynamic value) {
    if (value == null) {
      return null;
    }

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
  // COMPLAINT DATE
  // ============================================================

  DateTime _getComplaintDate(
    Map<String, dynamic> data,
  ) {
    final date =
        _getDate(data['dateCreated']) ??
        _getDate(data['createdAt']) ??
        _getDate(data['dateSubmitted']) ??
        _getDate(data['submittedAt']) ??
        _getDate(data['timestamp']) ??
        _getDate(data['date']) ??
        _getDate(data['created_date']);

    return date ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ============================================================
  // CONSUMER NAME
  // ============================================================

  String _getConsumerName(
    Map<String, dynamic> data,
  ) {
    final value =
        data['consumerName'] ??
        data['fullName'] ??
        data['full_name'] ??
        data['name'] ??
        data['consumer_name'];

    final result = _cleanString(value);

    return result.isEmpty ? 'Unknown Consumer' : result;
  }

  // ============================================================
  // ACCOUNT NUMBER
  // ============================================================

  String _getAccountNumber(
    Map<String, dynamic> data,
  ) {
    final value =
        data['accountNumber'] ??
        data['accountNo'] ??
        data['account_number'] ??
        data['account'];

    final result = _cleanString(value);

    return result.isEmpty ? 'N/A' : result;
  }

  // ============================================================
  // CONSUMER ID
  // ============================================================

  String _getConsumerId(
    Map<String, dynamic> data,
  ) {
    final value =
        data['consumerId'] ??
        data['consumerID'] ??
        data['uid'] ??
        data['userId'] ??
        data['consumerUID'] ??
        data['consumerUid'];

    return _cleanString(value);
  }

  // ============================================================
  // SUBJECT
  // ============================================================

  String _getSubject(
    Map<String, dynamic> data,
  ) {
    final value =
        data['subject'] ??
        data['title'] ??
        data['complaintSubject'];

    final result = _cleanString(value);

    return result.isEmpty ? 'No Subject' : result;
  }

  // ============================================================
  // COMPLAINT TYPE
  // ============================================================

  String _getComplaintType(
    Map<String, dynamic> data,
  ) {
    final value =
        data['complaintType'] ??
        data['type'] ??
        data['category'];

    final result = _cleanString(value);

    return result.isEmpty ? 'N/A' : result;
  }

  // ============================================================
  // DESCRIPTION
  // ============================================================

  String _getDescription(
    Map<String, dynamic> data,
  ) {
    final value =
        data['description'] ??
        data['details'] ??
        data['complaint'] ??
        data['message'];

    final result = _cleanString(value);

    return result.isEmpty
        ? 'No description provided.'
        : result;
  }

  // ============================================================
  // RESPONSE
  // ============================================================

  String _getResponse(
    Map<String, dynamic> data,
  ) {
    final value =
        data['response'] ??
        data['reply'] ??
        data['remarks'] ??
        data['comment'];

    return _cleanString(value);
  }

  // ============================================================
  // STATUS NORMALIZATION
  // ============================================================

  String _normalizeStatus(
    dynamic value,
  ) {
    final status = _cleanString(value);

    if (status.isEmpty) {
      return 'Pending';
    }

    final lower = status.toLowerCase();

    switch (lower) {
      case 'pending':
        return 'Pending';

      case 'in progress':
      case 'in_progress':
      case 'in-progress':
      case 'ongoing':
        return 'In Progress';

      case 'resolved':
      case 'closed':
      case 'completed':
        return 'Resolved';

      default:
        return status;
    }
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _getStatusColor(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'resolved':
      case 'closed':
      case 'completed':
        return Colors.green;

      case 'in progress':
        return Colors.blue;

      case 'pending':
      default:
        return Colors.orange;
    }
  }

  // ============================================================
  // STATUS ICON
  // ============================================================

  IconData _getStatusIcon(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'resolved':
      case 'closed':
      case 'completed':
        return Icons.check_circle;

      case 'in progress':
        return Icons.pending_actions;

      case 'pending':
      default:
        return Icons.pending;
    }
  }

  // ============================================================
  // MUNICIPALITIES
  // ============================================================

  List<String> _getMunicipalities() {
    final municipalities =
        getSorsogonSecondDistrictMunicipalities()
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();

    municipalities.sort();

    return municipalities;
  }

  // ============================================================
  // BARANGAYS
  // ============================================================

  List<String> _getBarangaysForSelectedMunicipality() {
    if (_municipalityFilter == 'All Municipalities') {
      return [];
    }

    final barangays =
        getBarangaysForMunicipality(
              _municipalityFilter,
            )
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();

    barangays.sort();

    return barangays;
  }

  // ============================================================
  // DIRECT LOCATION
  // ============================================================

  Map<String, dynamic> _getDirectLocation(
    Map<String, dynamic> data,
  ) {
    final barangay = _cleanString(
      data['barangay'] ??
          data['baranggay'] ??
          data['barangayName'] ??
          data['brgy'],
    );

    final municipality = _cleanString(
      data['municipality'] ??
          data['municipalityName'] ??
          data['city'] ??
          data['cityName'],
    );

    final provinceValue = _cleanString(
      data['province'],
    );

    final province = provinceValue.isEmpty
        ? 'Sorsogon'
        : provinceValue;

    final address = _cleanString(
      data['address'] ??
          data['fullAddress'] ??
          data['completeAddress'],
    );

    return {
      'barangay': barangay,
      'municipality': municipality,
      'province': province,
      'address': address,
    };
  }

  // ============================================================
  // BUILD LOCATION
  // ============================================================

  Map<String, dynamic> _buildLocation(
    Map<String, dynamic> data,
  ) {
    final direct = _getDirectLocation(data);

    String barangay =
        _cleanString(direct['barangay']);

    String municipality =
        _cleanString(direct['municipality']);

    String province =
        _cleanString(direct['province']);

    String address =
        _cleanString(direct['address']);

    if (province.isEmpty) {
      province = 'Sorsogon';
    }

    if (address.isEmpty &&
        barangay.isNotEmpty &&
        municipality.isNotEmpty) {
      try {
        address = buildSorsogonAddress(
          municipality: municipality,
          barangay: barangay,
        );
      } catch (_) {}
    }

    return {
      'barangay': barangay,
      'municipality': municipality,
      'province': province,
      'address': address,
    };
  }

  // ============================================================
  // EMPTY LOCATION
  // ============================================================

  Map<String, dynamic> _emptyLocation() {
    return {
      'barangay': '',
      'municipality': '',
      'province': '',
      'address': '',
    };
  }

  // ============================================================
  // HAS LOCATION
  // ============================================================

  bool _hasLocation(
    Map<String, dynamic> location,
  ) {
    return _cleanString(
              location['barangay'],
            ).isNotEmpty ||
        _cleanString(
              location['municipality'],
            ).isNotEmpty ||
        _cleanString(
              location['province'],
            ).isNotEmpty ||
        _cleanString(
              location['address'],
            ).isNotEmpty;
  }

  // ============================================================
  // GET CONSUMER LOCATION
  // ============================================================

  Future<Map<String, dynamic>> _getConsumerLocation(
    Map<String, dynamic> complaintData,
  ) async {
    // ----------------------------------------------------------
    // FIRST: LOCATION DIRECTLY STORED IN COMPLAINT
    // ----------------------------------------------------------

    final direct =
        _getDirectLocation(complaintData);

    final directHasUsefulLocation =
        _cleanString(
              direct['barangay'],
            ).isNotEmpty ||
        _cleanString(
              direct['municipality'],
            ).isNotEmpty ||
        _cleanString(
              direct['address'],
            ).isNotEmpty;

    if (directHasUsefulLocation) {
      return direct;
    }

    // ----------------------------------------------------------
    // CONSUMER ID
    // ----------------------------------------------------------

    final consumerId =
        _getConsumerId(complaintData);

    if (consumerId.isEmpty) {
      return direct;
    }

    // ----------------------------------------------------------
    // CACHE
    // ----------------------------------------------------------

    final cached =
        _locationCache[consumerId];

    if (cached != null) {
      return cached;
    }

    // ----------------------------------------------------------
    // USERS DOCUMENT ID
    // ----------------------------------------------------------

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(consumerId)
          .get();

      if (userDoc.exists) {
        final userData =
            userDoc.data() ??
                <String, dynamic>{};

        final location =
            _buildLocation(userData);

        if (_hasLocation(location)) {
          _locationCache[consumerId] =
              location;

          return location;
        }
      }
    } catch (_) {}

    // ----------------------------------------------------------
    // USERS UID FIELD
    // ----------------------------------------------------------

    try {
      final result = await _firestore
          .collection('users')
          .where(
            'uid',
            isEqualTo: consumerId,
          )
          .limit(1)
          .get();

      if (result.docs.isNotEmpty) {
        final userData =
            result.docs.first.data();

        final location =
            _buildLocation(userData);

        if (_hasLocation(location)) {
          _locationCache[consumerId] =
              location;

          return location;
        }
      }
    } catch (_) {}

    // ----------------------------------------------------------
    // USERS USERID FIELD
    // ----------------------------------------------------------

    try {
      final result = await _firestore
          .collection('users')
          .where(
            'userId',
            isEqualTo: consumerId,
          )
          .limit(1)
          .get();

      if (result.docs.isNotEmpty) {
        final userData =
            result.docs.first.data();

        final location =
            _buildLocation(userData);

        if (_hasLocation(location)) {
          _locationCache[consumerId] =
              location;

          return location;
        }
      }
    } catch (_) {}

    // ----------------------------------------------------------
    // FALLBACK
    // ----------------------------------------------------------

    final empty = _emptyLocation();

    _locationCache[consumerId] = empty;

    return empty;
  }

  // ============================================================
  // STATUS FILTER
  // ============================================================

  bool _matchesStatus(
    Map<String, dynamic> data,
  ) {
    if (_statusFilter == 'All Statuses') {
      return true;
    }

    final status =
        _normalizeStatus(data['status']);

    return status.toLowerCase() ==
        _statusFilter.toLowerCase();
  }

  // ============================================================
  // LOCATION FILTER
  // ============================================================

  Future<List<QueryDocumentSnapshot>>
      _filterByLocation(
    List<QueryDocumentSnapshot> docs,
  ) async {
    final needsMunicipality =
        _municipalityFilter !=
            'All Municipalities';

    final needsBarangay =
        _barangayFilter !=
            'All Barangays';

    if (!needsMunicipality &&
        !needsBarangay) {
      return docs;
    }

    final result =
        <QueryDocumentSnapshot>[];

    for (final doc in docs) {
      final data =
          doc.data()
              as Map<String, dynamic>;

      final location =
          await _getConsumerLocation(data);

      final municipality =
          _cleanString(
        location['municipality'],
      );

      final barangay =
          _cleanString(
        location['barangay'],
      );

      if (needsMunicipality) {
        if (municipality.toLowerCase() !=
            _municipalityFilter.toLowerCase()) {
          continue;
        }
      }

      if (needsBarangay) {
        if (barangay.toLowerCase() !=
            _barangayFilter.toLowerCase()) {
          continue;
        }
      }

      result.add(doc);
    }

    return result;
  }

  // ============================================================
  // STATUS + SORT
  // ============================================================

  List<QueryDocumentSnapshot>
      _processStatusAndSort(
    List<QueryDocumentSnapshot> docs,
  ) {
    final result =
        List<QueryDocumentSnapshot>.from(
      docs,
    );

    result.removeWhere((doc) {
      final data =
          doc.data()
              as Map<String, dynamic>;

      return !_matchesStatus(data);
    });

    result.sort((a, b) {
      final dataA =
          a.data()
              as Map<String, dynamic>;

      final dataB =
          b.data()
              as Map<String, dynamic>;

      final dateA =
          _getComplaintDate(dataA);

      final dateB =
          _getComplaintDate(dataB);

      if (_sortOption == 'Newest') {
        return dateB.compareTo(dateA);
      }

      return dateA.compareTo(dateB);
    });

    return result;
  }

  // ============================================================
  // LOCATION CARD
  // Matches the screenshot design
  // ============================================================

  Widget _buildConsumerLocationCard(
    Map<String, dynamic> location,
  ) {
    final barangay =
        _cleanString(location['barangay']);

    final municipality =
        _cleanString(
      location['municipality'],
    );

    final province =
        _cleanString(location['province']);

    final address =
        _cleanString(location['address']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: locationBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: locationBorder,
          width: 1.2,
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
                color: Colors.green.shade800,
                size: 23,
              ),
              const SizedBox(width: 8),
              const Text(
                'Consumer Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          _buildLocationInfoRow(
            icon: Icons.home_outlined,
            label: 'Barangay',
            value: barangay.isEmpty
                ? 'Not available'
                : barangay,
          ),

          _buildLocationInfoRow(
            icon: Icons.location_city_outlined,
            label: 'Municipality',
            value: municipality.isEmpty
                ? 'Not available'
                : municipality,
          ),

          _buildLocationInfoRow(
            icon: Icons.map_outlined,
            label: 'Province',
            value: province.isEmpty
                ? 'Not available'
                : province,
          ),

          _buildLocationInfoRow(
            icon: Icons.location_on_outlined,
            label: 'Address',
            value: address.isEmpty
                ? 'Not available'
                : address,
            bottomPadding: 0,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOCATION INFO ROW
  // ============================================================

  Widget _buildLocationInfoRow({
    required IconData icon,
    required String label,
    required String value,
    double bottomPadding = 7,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomPadding,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 25,
            child: Icon(
              icon,
              size: 21,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(width: 5),

          SizedBox(
            width: 92,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOADING LOCATION CARD
  // ============================================================

  Widget _buildLocationLoading() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        top: 2,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: locationBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: locationBorder,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Loading consumer location...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
  ) {
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
            size: 18,
            color: Colors.grey.shade700,
          ),

          const SizedBox(width: 8),

          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // Matches screenshot
  // ============================================================

  Widget _buildStatusBadge(
    String status,
  ) {
    final statusColor =
        _getStatusColor(status);

    final statusIcon =
        _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black87,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: 17,
            color: statusColor,
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESPONSE DIALOG
  // ============================================================

  Future<void> _showResponseDialog(
    BuildContext screenContext,
    String complaintId,
    String currentStatus,
    String currentResponse,
  ) async {
    final responseController =
        TextEditingController(
      text: currentResponse,
    );

    const statuses = [
      'Pending',
      'In Progress',
      'Resolved',
    ];

    String selectedStatus =
        statuses.contains(currentStatus)
            ? currentStatus
            : 'Pending';

    bool saving = false;

    try {
      await showDialog<void>(
        context: screenContext,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
              dialogContext,
              setDialogState,
            ) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                ),

                title: const Text(
                  'Respond to Complaint',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                content:
                    SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller:
                            responseController,
                        maxLines: 6,
                        enabled: !saving,
                        decoration:
                            InputDecoration(
                          labelText:
                              'Response / Comment',
                          hintText:
                              'Enter your response to the consumer...',
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              10,
                            ),
                          ),
                          alignLabelWithHint:
                              true,
                        ),
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      DropdownButtonFormField<
                          String>(
                        value:
                            selectedStatus,
                        decoration:
                            InputDecoration(
                          labelText:
                              'Complaint Status',
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              10,
                            ),
                          ),
                        ),
                        items:
                            statuses.map(
                          (status) {
                            return DropdownMenuItem<
                                String>(
                              value: status,
                              child:
                                  Text(status),
                            );
                          },
                        ).toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value ==
                                    null) {
                                  return;
                                }

                                setDialogState(
                                  () {
                                    selectedStatus =
                                        value;
                                  },
                                );
                              },
                      ),
                    ],
                  ),
                ),

                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () {
                            if (Navigator
                                .of(
                              dialogContext,
                            ).canPop()) {
                              Navigator.of(
                                dialogContext,
                              ).pop();
                            }
                          },
                    child:
                        const Text('Cancel'),
                  ),

                  ElevatedButton.icon(
                    icon: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.save,
                          ),

                    label: Text(
                      saving
                          ? 'Saving...'
                          : 'Save Response',
                    ),

                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          primaryOrange,
                      foregroundColor:
                          Colors.white,
                    ),

                    onPressed: saving
                        ? null
                        : () async {
                            final response =
                                responseController
                                    .text
                                    .trim();

                            if (response
                                .isEmpty) {
                              if (!dialogContext
                                  .mounted) {
                                return;
                              }

                              ScaffoldMessenger
                                  .of(
                                dialogContext,
                              ).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text(
                                    'Please enter a response.',
                                  ),
                                ),
                              );

                              return;
                            }

                            setDialogState(
                              () {
                                saving = true;
                              },
                            );

                            try {
                              final user =
                                  FirebaseAuth
                                      .instance
                                      .currentUser;

                              await _firestore
                                  .collection(
                                      'complaints')
                                  .doc(
                                      complaintId)
                                  .update({
                                'response':
                                    response,
                                'status':
                                    selectedStatus,
                                'respondedAt':
                                    FieldValue
                                        .serverTimestamp(),
                                'respondedBy':
                                    user?.email ??
                                        user?.uid ??
                                        'Teller',
                              });

                              if (!dialogContext
                                  .mounted) {
                                return;
                              }

                              if (Navigator
                                  .of(
                                dialogContext,
                              ).canPop()) {
                                Navigator.of(
                                  dialogContext,
                                ).pop();
                              }

                              if (screenContext
                                  .mounted) {
                                ScaffoldMessenger
                                    .of(
                                  screenContext,
                                ).showSnackBar(
                                  const SnackBar(
                                    backgroundColor:
                                        Colors.green,
                                    content:
                                        Text(
                                      'Complaint updated successfully.',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!dialogContext
                                  .mounted) {
                                return;
                              }

                              setDialogState(
                                () {
                                  saving = false;
                                },
                              );

                              ScaffoldMessenger
                                  .of(
                                dialogContext,
                              ).showSnackBar(
                                SnackBar(
                                  backgroundColor:
                                      Colors.red,
                                  content: Text(
                                    'Failed to update complaint: $e',
                                  ),
                                ),
                              );
                            }
                          },
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      responseController.dispose();
    }
  }

  // ============================================================
  // FILTER DROPDOWN
  // ============================================================

  Widget _buildDropdownContainer({
    required Widget child,
    double height = 50,
  }) {
    return Container(
      width: double.infinity,
      height: height,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: child,
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<
            DropdownMenuItem<String>>
        items,
    required ValueChanged<String?>?
        onChanged,
  }) {
    return _buildDropdownContainer(
      height: 48,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
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
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY MESSAGE
  // ============================================================

  String _getEmptyMessage() {
    if (_municipalityFilter !=
            'All Municipalities' &&
        _barangayFilter !=
            'All Barangays') {
      return 'No complaints found in '
          '$_barangayFilter, '
          '$_municipalityFilter.';
    }

    if (_municipalityFilter !=
        'All Municipalities') {
      return 'No complaints found in '
          '$_municipalityFilter.';
    }

    if (_statusFilter !=
        'All Statuses') {
      return 'No $_statusFilter complaints found.';
    }

    return 'No complaints available.';
  }

  // ============================================================
  // COMPLAINT CARD
  // MAIN REDESIGNED CARD
  // ============================================================

  Widget _buildComplaintCard(
    BuildContext context,
    QueryDocumentSnapshot complaint,
    Map<String, dynamic> data,
  ) {
    final subject =
        _getSubject(data);

    final consumerName =
        _getConsumerName(data);

    final accountNumber =
        _getAccountNumber(data);

    final complaintType =
        _getComplaintType(data);

    final description =
        _getDescription(data);

    final response =
        _getResponse(data);

    final status =
        _normalizeStatus(data['status']);

    final complaintDate =
        _getComplaintDate(data);

    final hasDate =
        complaintDate.millisecondsSinceEpoch !=
            0;

    final dateText = hasDate
        ? DateFormat(
            'MMM dd, yyyy hh:mm a',
          ).format(complaintDate)
        : 'Date not available';

    final respondedBy =
        _cleanString(
      data['respondedBy'],
    );

    final respondedDate =
        _getDate(data['respondedAt']);

    final respondedDateText =
        respondedDate == null
            ? ''
            : DateFormat(
                'MMM dd, yyyy hh:mm a',
              ).format(respondedDate);

    return Container(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.07),
            blurRadius: 8,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ==================================================
            // SUBJECT + STATUS
            // ==================================================

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    subject,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 21,
                      color: Colors.black,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                _buildStatusBadge(
                  status,
                ),
              ],
            ),

            const SizedBox(
              height: 17,
            ),

            // ==================================================
            // CONSUMER INFORMATION
            // ==================================================

            _buildInfoRow(
              Icons.person_outline,
              'Consumer',
              consumerName,
            ),

            _buildInfoRow(
              Icons.credit_card_outlined,
              'Account #',
              accountNumber,
            ),

            _buildInfoRow(
              Icons.report_problem_outlined,
              'Complaint Type',
              complaintType,
            ),

            const SizedBox(
              height: 10,
            ),

            // ==================================================
            // CONSUMER LOCATION
            // ==================================================

            FutureBuilder<
                Map<String, dynamic>>(
              future:
                  _getConsumerLocation(
                data,
              ),
              builder: (
                context,
                locationSnapshot,
              ) {
                if (locationSnapshot
                        .connectionState ==
                    ConnectionState.waiting) {
                  return _buildLocationLoading();
                }

                final location =
                    locationSnapshot
                            .data ??
                        _emptyLocation();

                return _buildConsumerLocationCard(
                  location,
                );
              },
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // DATE SUBMITTED
            // ==================================================

            Text(
              'Date Submitted: $dateText',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            const Divider(
              height: 1,
              thickness: 1,
            ),

            const SizedBox(
              height: 20,
            ),

            // ==================================================
            // DESCRIPTION
            // ==================================================

            const Text(
              'Description',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              description,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Colors.black87,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // ==================================================
            // TELLER REPLY
            // ==================================================

            const Text(
              'Teller Reply',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            if (response.isEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(
                  14,
                ),
                decoration: BoxDecoration(
                  color:
                      Colors.grey.shade100,
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: Text(
                  'No response yet.',
                  style: TextStyle(
                    color:
                        Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(
                  14,
                ),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFF1F8F2),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                  border: Border.all(
                    color:
                        const Color(0xFFD0E5D3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      response,
                      style:
                          const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),

                    if (respondedBy
                        .isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets
                                .only(
                          top: 10,
                        ),
                        child: Text(
                          'Replied by: $respondedBy',
                          style:
                              TextStyle(
                            fontSize: 12,
                            color: Colors
                                .grey
                                .shade600,
                          ),
                        ),
                      ),

                    if (respondedDateText
                        .isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets
                                .only(
                          top: 3,
                        ),
                        child: Text(
                          'Responded: $respondedDateText',
                          style:
                              TextStyle(
                            fontSize: 12,
                            color: Colors
                                .grey
                                .shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            const SizedBox(
              height: 18,
            ),

            // ==================================================
            // RESPOND BUTTON
            // ==================================================

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: Icon(
                  response.isEmpty
                      ? Icons.reply_outlined
                      : Icons.edit_outlined,
                  size: 20,
                ),
                label: Text(
                  response.isEmpty
                      ? 'Respond to Complaint'
                      : 'Edit Response',
                ),
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      primaryOrange,
                  foregroundColor:
                      Colors.white,
                  elevation: 0,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                ),
                onPressed: () {
                  _showResponseDialog(
                    context,
                    complaint.id,
                    status,
                    response,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final municipalities =
        _getMunicipalities();

    final barangays =
        _getBarangaysForSelectedMunicipality();

    final safeBarangayValue =
        barangays.contains(
      _barangayFilter,
    )
            ? _barangayFilter
            : 'All Barangays';

    return Scaffold(
      backgroundColor:
          backgroundColor,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            primaryOrange,
        foregroundColor:
            Colors.white,
        title: const Text(
          'Manage Complaints',
          style: TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: Column(
        children: [
          // ======================================================
          // FILTER AREA
          // ======================================================

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              14,
              16,
              8,
            ),
            child: Column(
              children: [
                // ==================================================
                // SORT + STATUS
                // ==================================================

                Row(
                  children: [
                    Expanded(
                      child:
                          _buildFilterDropdown(
                        value:
                            _sortOption,
                        items: const [
                          DropdownMenuItem(
                            value:
                                'Newest',
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .sort,
                                  size: 18,
                                  color:
                                      Colors.orange,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  'Newest',
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value:
                                'Oldest',
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .sort,
                                  size: 18,
                                  color:
                                      Colors.orange,
                                ),
                                SizedBox(
                                  width: 8,
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
                          if (value ==
                              null) {
                            return;
                          }

                          setState(() {
                            _sortOption =
                                value;
                          });
                        },
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child:
                          _buildFilterDropdown(
                        value:
                            _statusFilter,
                        items: const [
                          DropdownMenuItem(
                            value:
                                'All Statuses',
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .tune,
                                  size: 18,
                                  color:
                                      Colors.orange,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  'All',
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value:
                                'Pending',
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .pending,
                                  size: 18,
                                  color:
                                      Colors.orange,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  'Pending',
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value:
                                'In Progress',
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .pending_actions,
                                  size: 18,
                                  color:
                                      Colors.blue,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  'In Progress',
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value:
                                'Resolved',
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .check_circle,
                                  size: 18,
                                  color:
                                      Colors.green,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  'Resolved',
                                ),
                              ],
                            ),
                          ),
                        ],
                        onChanged:
                            (value) {
                          if (value ==
                              null) {
                            return;
                          }

                          setState(() {
                            _statusFilter =
                                value;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 10,
                ),

                // ==================================================
                // MUNICIPALITY
                // ==================================================

                _buildFilterDropdown(
                  value:
                      _municipalityFilter,
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
                            width: 8,
                          ),
                          Text(
                            'All Municipalities',
                          ),
                        ],
                      ),
                    ),
                    ...municipalities.map(
                      (municipality) {
                        return DropdownMenuItem<
                            String>(
                          value:
                              municipality,
                          child: Text(
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
                    if (value ==
                        null) {
                      return;
                    }

                    setState(() {
                      _municipalityFilter =
                          value;

                      _barangayFilter =
                          'All Barangays';
                    });
                  },
                ),

                const SizedBox(
                  height: 10,
                ),

                // ==================================================
                // BARANGAY
                // ==================================================

                _buildFilterDropdown(
                  value:
                      safeBarangayValue,
                  items: [
                    DropdownMenuItem<
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
                                _municipalityFilter ==
                                        'All Municipalities'
                                    ? Colors.grey
                                    : Colors.orange,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: Text(
                              _municipalityFilter ==
                                      'All Municipalities'
                                  ? 'Select Municipality First'
                                  : 'All Barangays in $_municipalityFilter',
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...barangays.map(
                      (barangay) {
                        return DropdownMenuItem<
                            String>(
                          value:
                              barangay,
                          child: Text(
                            barangay,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                          ),
                        );
                      },
                    ),
                  ],
                  onChanged:
                      _municipalityFilter ==
                              'All Municipalities'
                          ? null
                          : (value) {
                              if (value ==
                                  null) {
                                return;
                              }

                              setState(() {
                                _barangayFilter =
                                    value;
                              });
                            },
                ),
              ],
            ),
          ),

          // ======================================================
          // ACTIVE FILTERS
          // ======================================================

          if (_statusFilter !=
                  'All Statuses' ||
              _municipalityFilter !=
                  'All Municipalities' ||
              _barangayFilter !=
                  'All Barangays')
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                8,
              ),
              child: Align(
                alignment:
                    Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (_statusFilter !=
                        'All Statuses')
                      Chip(
                        avatar:
                            const Icon(
                          Icons.filter_alt,
                          size: 16,
                        ),
                        label: Text(
                          _statusFilter,
                        ),
                        visualDensity:
                            VisualDensity
                                .compact,
                      ),

                    if (_municipalityFilter !=
                        'All Municipalities')
                      Chip(
                        avatar:
                            const Icon(
                          Icons
                              .location_city,
                          size: 16,
                        ),
                        label: Text(
                          _municipalityFilter,
                        ),
                        visualDensity:
                            VisualDensity
                                .compact,
                      ),

                    if (_barangayFilter !=
                        'All Barangays')
                      Chip(
                        avatar:
                            const Icon(
                          Icons.location_on,
                          size: 16,
                        ),
                        label: Text(
                          _barangayFilter,
                        ),
                        visualDensity:
                            VisualDensity
                                .compact,
                      ),
                  ],
                ),
              ),
            ),

          // ======================================================
          // COMPLAINT STREAM
          // ======================================================

          Expanded(
            child:
                StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection(
                    'complaints',
                  )
                  .snapshots(),

              builder: (
                context,
                snapshot,
              ) {
                // ------------------------------------------------
                // LOADING
                // ------------------------------------------------

                if (snapshot
                        .connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(
                      color: primaryOrange,
                    ),
                  );
                }

                // ------------------------------------------------
                // ERROR
                // ------------------------------------------------

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .all(
                        20,
                      ),
                      child: Text(
                        'Error loading complaints:\n'
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
                    child: Text(
                      'No complaint data available.',
                    ),
                  );
                }

                // ------------------------------------------------
                // ALL COMPLAINTS
                // ------------------------------------------------

                final allComplaints =
                    snapshot.data!.docs;

                if (allComplaints.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Icon(
                          Icons
                              .inbox_outlined,
                          size: 55,
                          color:
                              Colors.grey,
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        Text(
                          'No complaints found.',
                          style:
                              TextStyle(
                            color:
                                Colors.grey,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // ------------------------------------------------
                // STATUS + SORT
                // ------------------------------------------------

                final statusSorted =
                    _processStatusAndSort(
                  allComplaints,
                );

                // ------------------------------------------------
                // LOCATION FILTER
                // ------------------------------------------------

                return FutureBuilder<
                    List<
                        QueryDocumentSnapshot>>(
                  future:
                      _filterByLocation(
                    statusSorted,
                  ),

                  builder: (
                    context,
                    locationSnapshot,
                  ) {
                    if (locationSnapshot
                            .connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child:
                            CircularProgressIndicator(
                          color:
                              primaryOrange,
                        ),
                      );
                    }

                    if (locationSnapshot
                        .hasError) {
                      return Center(
                        child: Padding(
                          padding:
                              const EdgeInsets
                                  .all(
                            20,
                          ),
                          child: Text(
                            'Error filtering complaints:\n'
                            '${locationSnapshot.error}',
                            textAlign:
                                TextAlign
                                    .center,
                          ),
                        ),
                      );
                    }

                    final complaints =
                        locationSnapshot
                                .data ??
                            [];

                    if (complaints
                        .isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize:
                              MainAxisSize
                                  .min,
                          children: [
                            const Icon(
                              Icons
                                  .filter_alt_off,
                              size: 50,
                              color:
                                  Colors.grey,
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    30,
                              ),
                              child: Text(
                                _getEmptyMessage(),
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.grey,
                                  fontSize:
                                      14,
                                ),
                                textAlign:
                                    TextAlign
                                        .center,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // ------------------------------------------------
                    // RESULTS
                    // ------------------------------------------------

                    return Column(
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets
                                  .fromLTRB(
                            16,
                            4,
                            16,
                            2,
                          ),
                          child: Align(
                            alignment:
                                Alignment
                                    .centerLeft,
                            child: Text(
                              '${complaints.length} complaint${complaints.length == 1 ? '' : 's'} found',
                              style:
                                  TextStyle(
                                color: Colors
                                    .grey
                                    .shade700,
                                fontSize:
                                    12,
                                fontWeight:
                                    FontWeight
                                        .w500,
                              ),
                            ),
                          ),
                        ),

                        Expanded(
                          child:
                              ListView.builder(
                            padding:
                                const EdgeInsets
                                    .fromLTRB(
                              16,
                              10,
                              16,
                              20,
                            ),
                            itemCount:
                                complaints
                                    .length,
                            itemBuilder:
                                (
                              context,
                              index,
                            ) {
                              final complaint =
                                  complaints[
                                      index];

                              final data =
                                  complaint.data()
                                      as Map<
                                          String,
                                          dynamic>;

                              return _buildComplaintCard(
                                context,
                                complaint,
                                data,
                              );
                            },
                          ),
                        ),
                      ],
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