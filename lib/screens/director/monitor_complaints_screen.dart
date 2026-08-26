import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:soreconnect/data/sorsogon_address_data.dart';

class MonitorComplaintsScreen extends StatefulWidget {
  const MonitorComplaintsScreen({super.key});

  @override
  State<MonitorComplaintsScreen> createState() =>
      _MonitorComplaintsScreenState();
}

class _MonitorComplaintsScreenState
    extends State<MonitorComplaintsScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color _primaryGreen = Color(0xFF1B5E20);
  static const Color _accentGold = Color(0xFFDAA520);

  // ============================================================
  // FILTERS
  // ============================================================

  String _sortOption = 'Newest';
  String _statusFilter = 'All';

  String _selectedMunicipality = 'All Municipalities';
  String _selectedBarangay = 'All Barangays';

  // ============================================================
  // LOCATION CACHE
  //
  // Key:
  // account number / UID / document ID
  //
  // This prevents repeatedly querying the users collection.
  // ============================================================

  final Map<String, Map<String, dynamic>> _locationCache = {};

  // ============================================================
  // LOADING LOCATION STATE
  // ============================================================

  bool _isResolvingLocations = false;

  // ============================================================
  // DATE HELPER
  // ============================================================

  DateTime? _getDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      final text = value.trim();

      if (text.isEmpty) {
        return null;
      }

      return DateTime.tryParse(text);
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
        _getDate(data['createdAt']) ??
        _getDate(data['dateCreated']) ??
        _getDate(data['dateSubmitted']) ??
        _getDate(data['submittedAt']) ??
        _getDate(data['timestamp']) ??
        _getDate(data['created_at']) ??
        _getDate(data['date_created']) ??
        _getDate(data['date_submitted']) ??
        _getDate(data['submitted_at']) ??
        _getDate(data['date']) ??
        _getDate(data['complaintDate']) ??
        _getDate(data['complaint_date']);

    return date ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ============================================================
  // SAFE STRING
  // ============================================================

  String _stringValue(
    Map<String, dynamic> data,
    String key,
  ) {
    final value = data[key];

    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  // ============================================================
  // NORMALIZE STRING
  //
  // Used for reliable municipality/barangay comparison.
  //
  // Example:
  //
  // "Santa Magdalena"
  // " santa magdalena "
  //
  // will match.
  // ============================================================

  String _normalizeText(
    dynamic value,
  ) {
    return (value ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  // ============================================================
  // NORMALIZE ACCOUNT NUMBER
  // ============================================================

  String _normalizeAccountNumber(
    dynamic value,
  ) {
    return (value ?? '').toString().trim();
  }

  // ============================================================
  // GET ACCOUNT NUMBER FROM COMPLAINT
  //
  // Supports multiple possible Firestore field names.
  // ============================================================

  String _getAccountNumber(
    Map<String, dynamic> data,
  ) {
    final values = [
      data['accountNumber'],
      data['accountNo'],
      data['account_number'],
      data['consumerAccountNumber'],
      data['consumerAccountNo'],
    ];

    for (final value in values) {
      final result = _normalizeAccountNumber(value);

      if (result.isNotEmpty) {
        return result;
      }
    }

    return '';
  }

  // ============================================================
  // GET CONSUMER UID FROM COMPLAINT
  //
  // Supports multiple possible field names.
  // ============================================================

  String _getConsumerId(
    Map<String, dynamic> data,
  ) {
    final values = [
      data['consumerId'],
      data['consumerUID'],
      data['consumerUid'],
      data['uid'],
      data['userId'],
      data['userID'],
      data['consumer_id'],
      data['user_id'],
    ];

    for (final value in values) {
      final result = (value ?? '').toString().trim();

      if (result.isNotEmpty) {
        return result;
      }
    }

    return '';
  }

  // ============================================================
  // GET DIRECT LOCATION FROM COMPLAINT
  //
  // This is the FALLBACK.
  //
  // The users collection is preferred.
  // ============================================================

  Map<String, dynamic> _getDirectLocation(
    Map<String, dynamic> data,
  ) {
    final barangay = (
      data['barangay'] ??
      data['brgy'] ??
      data['barangayName']
    )
        .toString()
        .trim();

    final municipality = (
      data['municipality'] ??
      data['city'] ??
      data['municipalityCity'] ??
      data['municipalityName']
    )
        .toString()
        .trim();

    final province = (
      data['province'] ??
      data['provinceName']
    )
        .toString()
        .trim();

    final address = (
      data['address'] ??
      data['fullAddress'] ??
      data['location']
    )
        .toString()
        .trim();

    return {
      'barangay': barangay,
      'municipality': municipality,
      'province':
          province.isEmpty ? 'Sorsogon' : province,
      'address': address,
      'source': 'complaint',
    };
  }

  // ============================================================
  // CHECK WHETHER LOCATION HAS DATA
  // ============================================================

  bool _hasLocation(
    Map<String, dynamic>? location,
  ) {
    if (location == null) {
      return false;
    }

    final barangay =
        (location['barangay'] ?? '').toString().trim();

    final municipality =
        (location['municipality'] ?? '').toString().trim();

    final province =
        (location['province'] ?? '').toString().trim();

    final address =
        (location['address'] ?? '').toString().trim();

    return barangay.isNotEmpty ||
        municipality.isNotEmpty ||
        province.isNotEmpty ||
        address.isNotEmpty;
  }

  // ============================================================
  // BUILD LOCATION FROM USER DATA
  // ============================================================

  Map<String, dynamic> _makeLocation(
    Map<String, dynamic> data,
  ) {
    final barangay = (
      data['barangay'] ??
      data['brgy'] ??
      data['barangayName']
    )
        .toString()
        .trim();

    final municipality = (
      data['municipality'] ??
      data['city'] ??
      data['municipalityCity'] ??
      data['municipalityName']
    )
        .toString()
        .trim();

    final province = (
      data['province'] ??
      data['provinceName']
    )
        .toString()
        .trim();

    String address = (
      data['address'] ??
      data['fullAddress'] ??
      data['location']
    )
        .toString()
        .trim();

    // ==========================================================
    // IF FIRESTORE ADDRESS IS EMPTY
    //
    // Construct the readable Sorsogon address.
    // ==========================================================

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
            '$barangay, $municipality, '
            '${province.isEmpty ? 'Sorsogon' : province}';
      }
    }

    return {
      'barangay': barangay,
      'municipality': municipality,
      'province':
          province.isEmpty ? 'Sorsogon' : province,
      'address': address,
      'source': 'users',
    };
  }

  // ============================================================
  // FIND USER BY ACCOUNT NUMBER
  //
  // Priority:
  //
  // 1. accountNumber
  // 2. accountNo
  // 3. account_number
  // ============================================================

  Future<Map<String, dynamic>?> _findUserByAccountNumber(
    String accountNumber,
  ) async {
    if (accountNumber.isEmpty) {
      return null;
    }

    final users =
        FirebaseFirestore.instance.collection('users');

    final fieldNames = [
      'accountNumber',
      'accountNo',
      'account_number',
    ];

    for (final field in fieldNames) {
      try {
        final snapshot = await users
            .where(
              field,
              isEqualTo: accountNumber,
            )
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs.first.data();
        }
      } catch (_) {
        // Continue trying the next possible field.
      }
    }

    return null;
  }

  // ============================================================
  // FIND USER BY UID FIELD
  //
  // Supports:
  //
  // uid
  // consumerId
  // userId
  // ============================================================

  Future<Map<String, dynamic>?> _findUserByUid(
    String uid,
  ) async {
    if (uid.isEmpty) {
      return null;
    }

    final users =
        FirebaseFirestore.instance.collection('users');

    final fieldNames = [
      'uid',
      'consumerId',
      'userId',
      'userID',
    ];

    for (final field in fieldNames) {
      try {
        final snapshot = await users
            .where(
              field,
              isEqualTo: uid,
            )
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs.first.data();
        }
      } catch (_) {
        // Continue.
      }
    }

    // ==========================================================
    // ALSO TRY DOCUMENT ID
    // ==========================================================

    try {
      final document =
          await users.doc(uid).get();

      if (document.exists &&
          document.data() != null) {
        return document.data();
      }
    } catch (_) {
      // Ignore and use fallback.
    }

    return null;
  }

  // ============================================================
  // RESOLVE COMPLAINT LOCATION
  //
  // PRIORITY:
  //
  // 1. accountNumber
  // 2. consumer UID
  // 3. direct complaint location
  //
  // This is the important fix.
  // ============================================================

  Future<Map<String, dynamic>> _resolveComplaintLocation(
    QueryDocumentSnapshot doc,
  ) async {
    final data =
        doc.data() as Map<String, dynamic>;

    final accountNumber =
        _getAccountNumber(data);

    final consumerId =
        _getConsumerId(data);

    // ==========================================================
    // CACHE KEY
    // ==========================================================

    final cacheKey = accountNumber.isNotEmpty
        ? 'account:$accountNumber'
        : consumerId.isNotEmpty
            ? 'uid:$consumerId'
            : 'complaint:${doc.id}';

    // ==========================================================
    // CHECK CACHE
    // ==========================================================

    if (_locationCache.containsKey(cacheKey)) {
      return _locationCache[cacheKey]!;
    }

    Map<String, dynamic>? userData;

    // ==========================================================
    // PRIORITY 1:
    // ACCOUNT NUMBER
    // ==========================================================

    if (accountNumber.isNotEmpty) {
      userData =
          await _findUserByAccountNumber(
        accountNumber,
      );
    }

    // ==========================================================
    // PRIORITY 2:
    // CONSUMER UID
    // ==========================================================

    if (userData == null &&
        consumerId.isNotEmpty) {
      userData =
          await _findUserByUid(
        consumerId,
      );
    }

    // ==========================================================
    // USE USER LOCATION
    // ==========================================================

    if (userData != null) {
      final location =
          _makeLocation(userData);

      if (_hasLocation(location)) {
        _locationCache[cacheKey] =
            location;

        return location;
      }
    }

    // ==========================================================
    // PRIORITY 3:
    // DIRECT COMPLAINT LOCATION
    // ==========================================================

    final directLocation =
        _getDirectLocation(data);

    if (_hasLocation(directLocation)) {
      _locationCache[cacheKey] =
          directLocation;

      return directLocation;
    }

    // ==========================================================
    // NO LOCATION FOUND
    // ==========================================================

    final emptyLocation = {
      'barangay': '',
      'municipality': '',
      'province': 'Sorsogon',
      'address': '',
      'source': 'none',
    };

    _locationCache[cacheKey] =
        emptyLocation;

    return emptyLocation;
  }

  // ============================================================
  // RESOLVE ALL COMPLAINT LOCATIONS
  //
  // This resolves locations before applying filters.
  //
  // Therefore the location filter works against the ACTUAL
  // consumer location rather than only fields inside complaints.
  // ============================================================

  Future<Map<String, Map<String, dynamic>>>
      _resolveAllLocations(
    List<QueryDocumentSnapshot> docs,
  ) async {
    final result =
        <String, Map<String, dynamic>>{};

    for (final doc in docs) {
      result[doc.id] =
          await _resolveComplaintLocation(doc);
    }

    return result;
  }

  // ============================================================
  // GET LOCATION VALUES
  // ============================================================

  String _getMunicipality(
    Map<String, dynamic> data,
  ) {
    final value =
        data['municipality'] ??
        data['city'] ??
        data['municipalityCity'] ??
        data['municipalityName'];

    return value?.toString().trim() ?? '';
  }

  String _getBarangay(
    Map<String, dynamic> data,
  ) {
    final value =
        data['barangay'] ??
        data['brgy'] ??
        data['barangayName'];

    return value?.toString().trim() ?? '';
  }

  String _getProvince(
    Map<String, dynamic> data,
  ) {
    final province =
        (data['province'] ?? '')
            .toString()
            .trim();

    return province.isEmpty
        ? 'Sorsogon'
        : province;
  }

  String _getAddress(
    Map<String, dynamic> data,
  ) {
    final address =
        (data['address'] ?? '')
            .toString()
            .trim();

    if (address.isNotEmpty) {
      return address;
    }

    final barangay =
        _getBarangay(data);

    final municipality =
        _getMunicipality(data);

    if (barangay.isNotEmpty &&
        municipality.isNotEmpty) {
      try {
        return buildSorsogonAddress(
          municipality: municipality,
          barangay: barangay,
        );
      } catch (_) {
        return '$barangay, $municipality, Sorsogon';
      }
    }

    return '';
  }

  // ============================================================
  // LOCATION MATCH
  // ============================================================

  bool _matchesLocation(
    Map<String, dynamic> location,
  ) {
    final municipality =
        _getMunicipality(location);

    final barangay =
        _getBarangay(location);

    // ==========================================================
    // MUNICIPALITY
    // ==========================================================

    if (_selectedMunicipality !=
        'All Municipalities') {
      if (_normalizeText(municipality) !=
          _normalizeText(
            _selectedMunicipality,
          )) {
        return false;
      }
    }

    // ==========================================================
    // BARANGAY
    // ==========================================================

    if (_selectedBarangay !=
        'All Barangays') {
      if (_normalizeText(barangay) !=
          _normalizeText(
            _selectedBarangay,
          )) {
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // STATUS NORMALIZER
  // ============================================================

  String _normalizeStatus(
    dynamic value,
  ) {
    return (value ?? 'Pending')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
  }

  // ============================================================
  // STATUS MATCH
  // ============================================================

  bool _matchesStatus(
    Map<String, dynamic> data,
  ) {
    if (_statusFilter == 'All') {
      return true;
    }

    final status =
        _normalizeStatus(
      data['status'],
    );

    return status ==
        _normalizeStatus(
          _statusFilter,
        );
  }

  // ============================================================
  // FILTER COMPLAINTS
  // ============================================================

  List<QueryDocumentSnapshot> _filterComplaints(
    List<QueryDocumentSnapshot> docs,
    Map<String, Map<String, dynamic>> locations,
  ) {
    return docs.where((doc) {
      final data =
          doc.data() as Map<String, dynamic>;

      final location =
          locations[doc.id] ??
              {
                'barangay': '',
                'municipality': '',
                'province': 'Sorsogon',
                'address': '',
              };

      return _matchesStatus(data) &&
          _matchesLocation(location);
    }).toList();
  }

  // ============================================================
  // SORT
  // ============================================================

  List<QueryDocumentSnapshot> _sortComplaints(
    List<QueryDocumentSnapshot> docs,
  ) {
    final sortedDocs =
        List<QueryDocumentSnapshot>.from(
      docs,
    );

    sortedDocs.sort((a, b) {
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

    return sortedDocs;
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _getStatusColor(
    String status,
  ) {
    switch (
        _normalizeStatus(status)) {
      case 'resolved':
        return Colors.green;

      case 'in progress':
        return Colors.blue;

      case 'pending':
      default:
        return Colors.orange;
    }
  }

  // ============================================================
  // LOCATION TEXT
  // ============================================================

  String _locationText(
    Map<String, dynamic> location,
  ) {
    final barangay =
        _getBarangay(location);

    final municipality =
        _getMunicipality(location);

    final province =
        _getProvince(location);

    final address =
        _getAddress(location);

    if (barangay.isNotEmpty &&
        municipality.isNotEmpty) {
      return '$barangay, '
          '$municipality, '
          '$province';
    }

    if (municipality.isNotEmpty) {
      return '$municipality, $province';
    }

    if (barangay.isNotEmpty) {
      return '$barangay, $province';
    }

    if (address.isNotEmpty) {
      return address;
    }

    return 'Location not provided';
  }

  // ============================================================
  // REPLY DIALOG
  // ============================================================

  Future<void> _showReplyDialog({
    required BuildContext context,
    required String complaintId,
    required Map<String, dynamic> data,
  }) async {
    final responseController =
        TextEditingController(
      text: _stringValue(
        data,
        'response',
      ),
    );

    String selectedStatus =
        (data['status'] ?? 'Pending')
            .toString()
            .trim();

    const statuses = [
      'Pending',
      'In Progress',
      'Resolved',
    ];

    if (!statuses.contains(
      selectedStatus,
    )) {
      selectedStatus = 'Pending';
    }

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
              dialogContext,
              setDialogState,
            ) {
              return AlertDialog(
                title: const Text(
                  'Reply to Complaint',
                ),
                content:
                    SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complaint: '
                        '${_stringValue(data, 'subject').isEmpty ? 'No Subject' : _stringValue(data, 'subject')}',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      // ==================================================
                      // LOCATION IN DIALOG
                      // ==================================================

                      FutureBuilder<
                          Map<String, dynamic>>(
                        future:
                            _resolveComplaintLocation(
                          _fakeDocumentForDialog(
                            complaintId,
                            data,
                          ),
                        ),
                        builder: (
                          context,
                          snapshot,
                        ) {
                          if (!snapshot.hasData) {
                            return const Text(
                              'Location: Loading...',
                              style:
                                  TextStyle(
                                color:
                                    Colors.grey,
                                fontSize:
                                    13,
                              ),
                            );
                          }

                          final location =
                              snapshot.data!;

                          return Text(
                            'Location: '
                            '${_locationText(location)}',
                            style:
                                const TextStyle(
                              color:
                                  Colors.grey,
                              fontSize:
                                  13,
                            ),
                          );
                        },
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      DropdownButtonFormField<
                          String>(
                        value:
                            selectedStatus,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Complaint Status',
                          border:
                              OutlineInputBorder(),
                        ),
                        items:
                            statuses.map(
                          (status) {
                            return DropdownMenuItem<
                                String>(
                              value:
                                  status,
                              child:
                                  Text(status),
                            );
                          },
                        ).toList(),
                        onChanged:
                            (value) {
                          if (value ==
                              null) {
                            return;
                          }

                          setDialogState(() {
                            selectedStatus =
                                value;
                          });
                        },
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      TextField(
                        controller:
                            responseController,
                        maxLines: 5,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Teller Reply',
                          hintText:
                              'Write your response to the consumer...',
                          border:
                              OutlineInputBorder(),
                          alignLabelWithHint:
                              true,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(
                        dialogContext,
                        rootNavigator: true,
                      ).pop();
                    },
                    child:
                        const Text('Cancel'),
                  ),

                  ElevatedButton(
                    onPressed: () async {
                      final response =
                          responseController
                              .text
                              .trim();

                      if (response.isEmpty) {
                        ScaffoldMessenger
                                .of(context)
                            .showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter a reply.',
                            ),
                          ),
                        );
                        return;
                      }

                      try {
                        final user =
                            FirebaseAuth
                                .instance
                                .currentUser;

                        await FirebaseFirestore
                            .instance
                            .collection(
                              'complaints',
                            )
                            .doc(
                              complaintId,
                            )
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
                                  'Teller',
                        });

                        if (dialogContext
                            .mounted) {
                          Navigator.of(
                            dialogContext,
                            rootNavigator: true,
                          ).pop();
                        }

                        if (context.mounted) {
                          ScaffoldMessenger
                                  .of(context)
                              .showSnackBar(
                            const SnackBar(
                              backgroundColor:
                                  Colors.green,
                              content: Text(
                                'Reply saved successfully.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger
                                  .of(context)
                              .showSnackBar(
                            SnackBar(
                              backgroundColor:
                                  Colors.red,
                              content: Text(
                                'Failed to save reply: $e',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child:
                        const Text(
                      'Save Reply',
                    ),
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
  // TEMPORARY DOCUMENT FOR DIALOG LOCATION LOOKUP
  // ============================================================

  QueryDocumentSnapshot
      _fakeDocumentForDialog(
    String id,
    Map<String, dynamic> data,
  ) {
    throw UnimplementedError();
  }

  // ============================================================
  // FILTER DECORATION
  // ============================================================

  BoxDecoration _filterDecoration() {
    return BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius:
          BorderRadius.circular(10),
      border: Border.all(
        color: Colors.grey.shade300,
      ),
    );
  }

  // ============================================================
  // SORT DROPDOWN
  // ============================================================

  Widget _buildSortDropdown() {
    return Container(
      height: 48,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      decoration:
          _filterDecoration(),
      child:
          DropdownButtonHideUnderline(
        child:
            DropdownButton<String>(
          value: _sortOption,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 20,
            color: Colors.grey,
          ),
          style: const TextStyle(
            color: Colors.black87,
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
                  SizedBox(width: 7),
                  Text('Newest'),
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
    );
  }

  // ============================================================
  // STATUS DROPDOWN
  // ============================================================

  Widget _buildStatusDropdown() {
    return Container(
      height: 48,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      decoration:
          _filterDecoration(),
      child:
          DropdownButtonHideUnderline(
        child:
            DropdownButton<String>(
          value: _statusFilter,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 20,
            color: Colors.grey,
          ),
          style: const TextStyle(
            color: Colors.black87,
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
                    Icons.forum,
                    size: 18,
                    color:
                        Colors.orange,
                  ),
                  SizedBox(width: 7),
                  Text('All'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'Pending',
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons.pending,
                    size: 18,
                    color:
                        Colors.orange,
                  ),
                  SizedBox(width: 7),
                  Text('Pending'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'In Progress',
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons.autorenew,
                    size: 18,
                    color: Colors.blue,
                  ),
                  SizedBox(width: 7),
                  Text('In Progress'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'Resolved',
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color:
                        Colors.green,
                  ),
                  SizedBox(width: 7),
                  Text('Resolved'),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _statusFilter = value;
              });
            }
          },
        ),
      ),
    );
  }

  // ============================================================
  // MUNICIPALITY DROPDOWN
  // ============================================================

  Widget _buildMunicipalityDropdown() {
    final municipalities = [
      'All Municipalities',
      ...getSorsogonSecondDistrictMunicipalities(),
    ];

    return Container(
      height: 48,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      decoration:
          _filterDecoration(),
      child:
          DropdownButtonHideUnderline(
        child:
            DropdownButton<String>(
          value:
              municipalities.contains(
            _selectedMunicipality,
          )
                  ? _selectedMunicipality
                  : 'All Municipalities',
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 20,
            color: Colors.grey,
          ),
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 13,
            fontWeight:
                FontWeight.w500,
          ),
          items:
              municipalities.map(
            (municipality) {
              return DropdownMenuItem<String>(
                value: municipality,
                child: Row(
                  children: [
                    Icon(
                      municipality ==
                              'All Municipalities'
                          ? Icons.location_on
                          : Icons.location_city,
                      size: 18,
                      color:
                          Colors.orange,
                    ),
                    const SizedBox(
                      width: 7,
                    ),
                    Flexible(
                      child: Text(
                        municipality,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ).toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }

            setState(() {
              _selectedMunicipality =
                  value;

              _selectedBarangay =
                  'All Barangays';
            });
          },
        ),
      ),
    );
  }

  // ============================================================
  // BARANGAY DROPDOWN
  // ============================================================

  Widget _buildBarangayDropdown() {
    final barangays =
        _selectedMunicipality ==
                'All Municipalities'
            ? <String>[]
            : getBarangaysForMunicipality(
                _selectedMunicipality,
              );

    final items = [
      'All Barangays',
      ...barangays,
    ];

    return Container(
      height: 48,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      decoration:
          _filterDecoration(),
      child:
          DropdownButtonHideUnderline(
        child:
            DropdownButton<String>(
          value:
              items.contains(
            _selectedBarangay,
          )
                  ? _selectedBarangay
                  : 'All Barangays',
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 20,
            color: Colors.grey,
          ),
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 13,
            fontWeight:
                FontWeight.w500,
          ),
          items:
              items.map(
            (barangay) {
              return DropdownMenuItem<String>(
                value: barangay,
                child: Row(
                  children: [
                    Icon(
                      barangay ==
                              'All Barangays'
                          ? Icons.location_on
                          : Icons.home,
                      size: 18,
                      color:
                          Colors.orange,
                    ),
                    const SizedBox(
                      width: 7,
                    ),
                    Flexible(
                      child: Text(
                        barangay,
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
              _selectedMunicipality ==
                      'All Municipalities'
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _selectedBarangay =
                            value;
                      });
                    },
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Monitor Complaints',
        ),
        backgroundColor:
            Theme.of(context)
                .primaryColor,
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
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'All Complaints',
                        style:
                            TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),

                    _buildSortDropdown(),

                    const SizedBox(
                      width: 8,
                    ),

                    _buildStatusDropdown(),
                  ],
                ),

                const SizedBox(
                  height: 8,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                          _buildMunicipalityDropdown(),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Expanded(
                      child:
                          _buildBarangayDropdown(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ======================================================
          // COMPLAINTS
          // ======================================================

          Expanded(
            child:
                StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore
                      .instance
                      .collection(
                        'complaints',
                      )
                      .snapshots(),

              builder:
                  (context, snapshot) {
                if (snapshot
                        .connectionState ==
                    ConnectionState
                        .waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
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

                if (!snapshot.hasData) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                final allDocs =
                    snapshot.data!.docs
                        .toList();

                if (allDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No complaints available.',
                    ),
                  );
                }

                // ==================================================
                // RESOLVE LOCATIONS
                // ==================================================

                return FutureBuilder<
                    Map<String,
                        Map<String, dynamic>>>(
                  future:
                      _resolveAllLocations(
                    allDocs,
                  ),
                  builder: (
                    context,
                    locationSnapshot,
                  ) {
                    if (locationSnapshot
                            .connectionState ==
                        ConnectionState
                            .waiting) {
                      return const Center(
                        child:
                            CircularProgressIndicator(),
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
                            'Error resolving consumer locations:\n'
                            '${locationSnapshot.error}',
                            textAlign:
                                TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final locations =
                        locationSnapshot
                                .data ??
                            {};

                    // ==================================================
                    // FILTER
                    // ==================================================

                    final filtered =
                        _filterComplaints(
                      allDocs,
                      locations,
                    );

                    // ==================================================
                    // SORT
                    // ==================================================

                    final complaints =
                        _sortComplaints(
                      filtered,
                    );

                    if (complaints.isEmpty) {
                      String message =
                          'No complaints available.';

                      if (_selectedBarangay !=
                          'All Barangays') {
                        message =
                            'No complaints found in '
                            '$_selectedBarangay.';
                      } else if (_selectedMunicipality !=
                          'All Municipalities') {
                        message =
                            'No complaints found in '
                            '$_selectedMunicipality.';
                      } else if (_statusFilter !=
                          'All') {
                        message =
                            'No $_statusFilter '
                            'complaints found.';
                      }

                      return Center(
                        child: Padding(
                          padding:
                              const EdgeInsets
                                  .all(
                            20,
                          ),
                          child: Text(
                            message,
                            textAlign:
                                TextAlign.center,
                          ),
                        ),
                      );
                    }

                    // ==================================================
                    // LIST
                    // ==================================================

                    return ListView.builder(
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        16,
                        8,
                        16,
                        16,
                      ),
                      itemCount:
                          complaints.length,
                      itemBuilder:
                          (context, index) {
                        final complaintDoc =
                            complaints[index];

                        final data =
                            complaintDoc
                                    .data()
                                as Map<String,
                                    dynamic>;

                        // ==================================================
                        // LOCATION
                        // ==================================================

                        final location =
                            locations[
                                    complaintDoc
                                        .id] ??
                                {
                                  'barangay': '',
                                  'municipality':
                                      '',
                                  'province':
                                      'Sorsogon',
                                  'address':
                                      '',
                                };

                        final barangay =
                            _getBarangay(
                          location,
                        );

                        final municipality =
                            _getMunicipality(
                          location,
                        );

                        final province =
                            _getProvince(
                          location,
                        );

                        final address =
                            _getAddress(
                          location,
                        );

                        // ==================================================
                        // STATUS
                        // ==================================================

                        final status =
                            (data['status'] ??
                                    'Pending')
                                .toString()
                                .trim();

                        final statusColor =
                            _getStatusColor(
                          status,
                        );

                        // ==================================================
                        // DATE
                        // ==================================================

                        final createdDate =
                            _getComplaintDate(
                          data,
                        );

                        final dateText =
                            createdDate
                                        .millisecondsSinceEpoch ==
                                    0
                                ? '-'
                                : DateFormat(
                                    'MMM dd, yyyy hh:mm a',
                                  ).format(
                                    createdDate,
                                  );

                        // ==================================================
                        // RESPONSE
                        // ==================================================

                        final response =
                            _stringValue(
                          data,
                          'response',
                        );

                        final respondedBy =
                            _stringValue(
                          data,
                          'respondedBy',
                        );

                        final respondedDate =
                            _getDate(
                          data['respondedAt'],
                        );

                        final respondedAtText =
                            respondedDate ==
                                    null
                                ? ''
                                : DateFormat(
                                    'MMM dd, yyyy hh:mm a',
                                  ).format(
                                    respondedDate,
                                  );

                        return Card(
                          elevation: 3,
                          margin:
                              const EdgeInsets
                                  .only(
                            bottom: 15,
                          ),
                          child: Padding(
                            padding:
                                const EdgeInsets
                                    .all(
                              15,
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                // ==========================================
                                // SUBJECT + STATUS
                                // ==========================================

                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Expanded(
                                      child:
                                          Text(
                                        _stringValue(
                                                  data,
                                                  'subject',
                                                )
                                                .isEmpty
                                            ? 'No Subject'
                                            : _stringValue(
                                                data,
                                                'subject',
                                              ),
                                        style:
                                            const TextStyle(
                                          fontSize:
                                              18,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(
                                      width: 8,
                                    ),

                                    Chip(
                                      label:
                                          Text(
                                        status,
                                      ),
                                      backgroundColor:
                                          statusColor
                                              .withOpacity(
                                        .15,
                                      ),
                                      labelStyle:
                                          TextStyle(
                                        color:
                                            statusColor,
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                        fontSize:
                                            12,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(
                                  height: 10,
                                ),

                                // ==========================================
                                // CONSUMER
                                // ==========================================

                                Text(
                                  'Consumer: '
                                  '${_stringValue(data, 'consumerName').isEmpty ? 'Unknown' : _stringValue(data, 'consumerName')}',
                                ),

                                const SizedBox(
                                  height: 3,
                                ),

                                Text(
                                  'Account #: '
                                  '${_getAccountNumber(data).isEmpty ? 'N/A' : _getAccountNumber(data)}',
                                ),

                                const SizedBox(
                                  height: 3,
                                ),

                                Text(
                                  'Complaint Type: '
                                  '${_stringValue(data, 'complaintType').isEmpty ? 'N/A' : _stringValue(data, 'complaintType')}',
                                ),

                                // ==========================================
                                // ACCURATE LOCATION CARD
                                // ==========================================

                                const SizedBox(
                                  height: 10,
                                ),

                                Container(
                                  width:
                                      double.infinity,
                                  padding:
                                      const EdgeInsets
                                          .all(
                                    12,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color: Colors
                                        .green
                                        .withOpacity(
                                      0.06,
                                    ),
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      10,
                                    ),
                                    border:
                                        Border.all(
                                      color: _primaryGreen
                                          .withOpacity(
                                        0.25,
                                      ),
                                    ),
                                  ),
                                  child:
                                      Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons
                                                .location_on,
                                            color:
                                                _primaryGreen,
                                            size:
                                                20,
                                          ),
                                          const SizedBox(
                                            width:
                                                7,
                                          ),
                                          const Text(
                                            'Consumer Location',
                                            style:
                                                TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .bold,
                                              fontSize:
                                                  14,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(
                                        height:
                                            8,
                                      ),

                                      // Barangay
                                      if (barangay
                                          .isNotEmpty)
                                        _locationRow(
                                          'Barangay',
                                          barangay,
                                          Icons
                                              .home_outlined,
                                        ),

                                      // Municipality
                                      if (municipality
                                          .isNotEmpty)
                                        _locationRow(
                                          'Municipality',
                                          municipality,
                                          Icons
                                              .location_city_outlined,
                                        ),

                                      // Province
                                      if (province
                                          .isNotEmpty)
                                        _locationRow(
                                          'Province',
                                          province,
                                          Icons
                                              .map_outlined,
                                        ),

                                      // Address
                                      if (address
                                          .isNotEmpty)
                                        _locationRow(
                                          'Address',
                                          address,
                                          Icons
                                              .place_outlined,
                                        ),

                                      if (barangay
                                              .isEmpty &&
                                          municipality
                                              .isEmpty &&
                                          address
                                              .isEmpty)
                                        const Padding(
                                          padding:
                                              EdgeInsets
                                                  .only(
                                            top:
                                                3,
                                          ),
                                          child:
                                              Text(
                                            'Location not provided',
                                            style:
                                                TextStyle(
                                              color:
                                                  Colors
                                                      .grey,
                                              fontSize:
                                                  13,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                const SizedBox(
                                  height: 8,
                                ),

                                Text(
                                  'Date Submitted: '
                                  '$dateText',
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.grey,
                                    fontSize:
                                        12,
                                  ),
                                ),

                                const Divider(
                                  height: 24,
                                ),

                                // ==========================================
                                // DESCRIPTION
                                // ==========================================

                                const Text(
                                  'Description',
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),

                                const SizedBox(
                                  height: 5,
                                ),

                                Text(
                                  _stringValue(
                                            data,
                                            'description',
                                          )
                                          .isEmpty
                                      ? 'No description provided.'
                                      : _stringValue(
                                          data,
                                          'description',
                                        ),
                                ),

                                const SizedBox(
                                  height: 15,
                                ),

                                // ==========================================
                                // TELLER RESPONSE
                                // ==========================================

                                const Text(
                                  'Teller Reply',
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),

                                const SizedBox(
                                  height: 5,
                                ),

                                if (response.isEmpty)
                                  const Text(
                                    'No response yet.',
                                    style:
                                        TextStyle(
                                      color:
                                          Colors
                                              .grey,
                                    ),
                                  )
                                else
                                  Container(
                                    width:
                                        double.infinity,
                                    padding:
                                        const EdgeInsets
                                            .all(
                                      12,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color: Colors
                                          .green
                                          .withOpacity(
                                        0.08,
                                      ),
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        10,
                                      ),
                                    ),
                                    child:
                                        Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                          response,
                                        ),

                                        if (respondedBy
                                            .isNotEmpty) ...[
                                          const SizedBox(
                                            height:
                                                8,
                                          ),
                                          Text(
                                            'Replied by: '
                                            '$respondedBy',
                                            style:
                                                const TextStyle(
                                              fontSize:
                                                  12,
                                              color:
                                                  Colors
                                                      .grey,
                                            ),
                                          ),
                                        ],

                                        if (respondedAtText
                                            .isNotEmpty) ...[
                                          const SizedBox(
                                            height:
                                                3,
                                          ),
                                          Text(
                                            'Responded: '
                                            '$respondedAtText',
                                            style:
                                                const TextStyle(
                                              fontSize:
                                                  12,
                                              color:
                                                  Colors
                                                      .grey,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                const SizedBox(
                                  height: 15,
                                ),

                                // ==========================================
                                // REPLY
                                // ==========================================

                                SizedBox(
                                  width:
                                      double.infinity,
                                  child:
                                      OutlinedButton
                                          .icon(
                                    icon: Icon(
                                      response
                                              .isEmpty
                                          ? Icons.reply
                                          : Icons.edit,
                                    ),
                                    label: Text(
                                      response.isEmpty
                                          ? 'Reply to Complaint'
                                          : 'Edit Reply',
                                    ),
                                    onPressed: () {
                                      _showReplyDialog(
                                        context:
                                            context,
                                        complaintId:
                                            complaintDoc
                                                .id,
                                        data:
                                            data,
                                      );
                                    },
                                  ),
                                ),
                              ],
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
  // LOCATION ROW
  // ============================================================

  Widget _locationRow(
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 5,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 17,
            color: Colors.grey.shade700,
          ),

          const SizedBox(
            width: 7,
          ),

          SizedBox(
            width: 82,
            child: Text(
              '$label:',
              style:
                  const TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w600,
                color:
                    Colors.black54,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}