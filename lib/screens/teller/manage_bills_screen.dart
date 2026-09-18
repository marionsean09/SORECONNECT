import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:soreconnect/data/sorsogon_address_data.dart';
import 'package:soreconnect/models/bill_model.dart';
import 'package:soreconnect/utils/bill_calculator.dart';
import 'package:soreconnect/utils/page_transitions.dart';
import 'package:soreconnect/widgets/bill_breakdown_view.dart';
import 'package:soreconnect/widgets/export_bill_sheet.dart';
import 'package:soreconnect/widgets/ticket_badge.dart';

// ============================================================
// MANAGE BILLS SCREEN
// Bills are posted directly by the meter reader, so there is no
// separate verification step. The teller can only edit a bill's
// status (Unpaid / Paid / Cancelled) at any time, repeatedly.
// ============================================================

class ManageBillsScreen extends StatefulWidget {
  const ManageBillsScreen({super.key});

  @override
  State<ManageBillsScreen> createState() => _ManageBillsScreenState();
}

class _ManageBillsScreenState extends State<ManageBillsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const Color primaryOrange = Color(0xFFFFA000);
  static const Color backgroundColor = Color(0xFFFFF8E7);

  String? _updatingBillId;

  // ============================================================
  // FILTERS
  // ============================================================

  String _sortOption = 'Newest';
  String _selectedStatus = 'All';
  String _selectedMonth = 'All Months';
  String _selectedMunicipality = 'All Municipalities';
  String _selectedBarangay = 'Select Municipality First';

  final TextEditingController _searchController =
      TextEditingController();
  String _searchQuery = '';

  // ============================================================
  // ENTRANCE ANIMATION
  // ============================================================

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

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

  static const List<String> _monthNames = [
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
  // DATE HELPERS
  // ============================================================

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  DateTime _getBillDate(Map<String, dynamic> data) {
    final date = _parseDate(data['generatedAt']) ??
        _parseDate(data['createdAt']) ??
        _parseDate(data['dueDate']);

    return date ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  int? _getBillMonth(Map<String, dynamic> data) {
    final raw = data['billingPeriod'];

    if (raw != null) {
      final billingPeriod = raw.toString().trim().toLowerCase();

      for (int i = 0; i < _monthNames.length; i++) {
        if (billingPeriod.contains(_monthNames[i].toLowerCase())) {
          return i + 1;
        }
      }
    }

    return _getBillDate(data).month;
  }

  // ============================================================
  // STATUS
  // ============================================================

  String _getFirestoreStatus(Map<String, dynamic> data) {
    return (data['status'] ?? '').toString().trim().toLowerCase();
  }

  String _getDisplayStatus(Map<String, dynamic> data) {
    final status = _getFirestoreStatus(data);

    switch (status) {
      case 'paid':
        return 'Paid';
      case 'unpaid':
        return 'Unpaid';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      case '':
        return 'Unpaid';
      default:
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'cancelled':
      case 'canceled':
        return Colors.grey;
      case 'unpaid':
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Icons.check_circle;
      case 'cancelled':
      case 'canceled':
        return Icons.cancel;
      case 'unpaid':
      default:
        return Icons.pending;
    }
  }

  // ============================================================
  // FIELD HELPERS
  // ============================================================

  String _stringValue(
    Map<String, dynamic> data,
    List<String> fields, {
    String fallback = '',
  }) {
    for (final field in fields) {
      final value = data[field];

      if (value != null) {
        final text = value.toString().trim();

        if (text.isNotEmpty) return text;
      }
    }

    return fallback;
  }

  double _doubleValue(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _getConsumerName(Map<String, dynamic> data) {
    return _stringValue(
      data,
      ['consumerName', 'full_name', 'fullName', 'name'],
      fallback: 'Unknown Consumer',
    );
  }

  String _getAccountNumber(Map<String, dynamic> data) {
    return _stringValue(
      data,
      ['accountNumber', 'accountNo', 'account_number', 'account'],
      fallback: 'N/A',
    );
  }

  String _getBarangay(Map<String, dynamic> data) {
    return _stringValue(data, ['barangay', 'baranggay']);
  }

  String _getMunicipality(Map<String, dynamic> data) {
    return _stringValue(data, ['municipality', 'city']);
  }

  String _getProvince(Map<String, dynamic> data) {
    return _stringValue(data, ['province'], fallback: 'Sorsogon');
  }

  String _getAddress(Map<String, dynamic> data) {
    return _stringValue(data, ['address']);
  }

  String _getLocationText(Map<String, dynamic> data) {
    final address = _getAddress(data);

    if (address.isNotEmpty) return address;

    final parts = <String>[
      _getBarangay(data),
      _getMunicipality(data),
      _getProvince(data),
    ].where((p) => p.isNotEmpty).toList();

    return parts.isEmpty ? 'Location not available' : parts.join(', ');
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  // ============================================================
  // FILTER MATCHING
  // ============================================================

  bool _matchesLocation(Map<String, dynamic> data) {
    if (_selectedMunicipality == 'All Municipalities') return true;

    if (_normalize(_getMunicipality(data)) !=
        _normalize(_selectedMunicipality)) {
      return false;
    }

    if (_selectedBarangay == 'All Barangays' ||
        _selectedBarangay == 'Select Municipality First') {
      return true;
    }

    return _normalize(_getBarangay(data)) ==
        _normalize(_selectedBarangay);
  }

  bool _matchesMonth(Map<String, dynamic> data) {
    if (_selectedMonth == 'All Months') return true;

    final selectedIndex = _monthNames.indexOf(_selectedMonth);

    if (selectedIndex == -1) return true;

    return _getBillMonth(data) == selectedIndex + 1;
  }

  bool _matchesStatus(Map<String, dynamic> data) {
    if (_selectedStatus == 'All') return true;

    return _getFirestoreStatus(data) == _selectedStatus.toLowerCase();
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return true;

    final searchable = [
      _getConsumerName(data),
      _getAccountNumber(data),
      data['billingPeriod'],
      _getDisplayStatus(data),
      _getBarangay(data),
      _getMunicipality(data),
      _getAddress(data),
    ].map((v) => (v ?? '').toString().toLowerCase()).join(' ');

    return searchable.contains(query);
  }

  List<QueryDocumentSnapshot> _filterBills(
    List<QueryDocumentSnapshot> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      return _matchesMonth(data) &&
          _matchesLocation(data) &&
          _matchesStatus(data) &&
          _matchesSearch(data);
    }).toList();
  }

  List<QueryDocumentSnapshot> _sortBills(
    List<QueryDocumentSnapshot> docs,
  ) {
    final result = List<QueryDocumentSnapshot>.from(docs);

    result.sort((a, b) {
      final dateA = _getBillDate(a.data() as Map<String, dynamic>);
      final dateB = _getBillDate(b.data() as Map<String, dynamic>);

      return _sortOption == 'Newest'
          ? dateB.compareTo(dateA)
          : dateA.compareTo(dateB);
    });

    return result;
  }

  // ============================================================
  // UPDATE BILL STATUS
  // ============================================================

  Future<void> _updateBillStatus(
    String billId,
    String newStatus,
  ) async {
    setState(() {
      _updatingBillId = billId;
    });

    try {
      await _firestore.collection('bills').doc(billId).update({
        'status': newStatus,
        'statusUpdatedBy': _auth.currentUser?.email ?? 'Teller',
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Bill status updated.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Failed to update bill status: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingBillId = null;
        });
      }
    }
  }

  // ============================================================
  // STATUS DIALOG
  // Can be opened repeatedly on any bill, regardless of its
  // current status, to switch it between Unpaid / Paid / Cancelled.
  // ============================================================

  Future<void> _showStatusDialog(
    String billId,
    String currentStatus,
  ) async {
    const statuses = ['unpaid', 'paid', 'cancelled'];

    String selectedStatus =
        statuses.contains(currentStatus) ? currentStatus : 'unpaid';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Update Bill Status',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: statuses.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setDialogState(() {
                    selectedStatus = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryOrange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _updateBillStatus(billId, selectedStatus);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // FILTER DROPDOWN
  // ============================================================

  Widget _buildCompactDropdown({
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 22,
            color: Colors.grey,
          ),
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Row(
                children: [
                  Icon(icon, size: 19, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }

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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
        border: enabled
            ? null
            : Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          isExpanded: true,
          hint: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: enabled ? Colors.orange : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hint,
                  style: TextStyle(
                    fontSize: 16,
                    color: enabled ? Colors.black87 : Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Colors.grey,
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Row(
                children: [
                  Icon(icon, size: 21, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: enabled
              ? (value) {
                  if (value != null) onChanged(value);
                }
              : null,
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final municipalities = getSorsogonSecondDistrictMunicipalities();

    final municipalitySelected =
        _selectedMunicipality != 'All Municipalities';

    final barangays = municipalitySelected
        ? getBarangaysForMunicipality(_selectedMunicipality)
        : <String>[];

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText:
                  "Search consumer, account #, billing period, "
                  "location...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: "Clear search",
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: primaryOrange,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactDropdown(
                  icon: Icons.tune,
                  value: _selectedStatus,
                  items: const [
                    'All',
                    'Unpaid',
                    'Paid',
                    'Cancelled',
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDropdown(
                  icon: Icons.calendar_month,
                  value: _selectedMonth,
                  items: ['All Months', ..._monthNames],
                  onChanged: (value) {
                    setState(() {
                      _selectedMonth = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: PopupMenuButton<String>(
                  tooltip: 'Sort',
                  icon: const Icon(Icons.sort, color: Colors.orange),
                  onSelected: (value) {
                    setState(() {
                      _sortOption = value;
                    });
                  },
                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem(
                        value: 'Newest',
                        child: Text('Newest'),
                      ),
                      PopupMenuItem(
                        value: 'Oldest',
                        child: Text('Oldest'),
                      ),
                    ];
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildLocationDropdown(
            icon: Icons.location_city,
            value: _selectedMunicipality,
            items: ['All Municipalities', ...municipalities],
            enabled: true,
            hint: 'All Municipalities',
            onChanged: (value) {
              setState(() {
                _selectedMunicipality = value;
                _selectedBarangay = value == 'All Municipalities'
                    ? 'Select Municipality First'
                    : 'All Barangays';
              });
            },
          ),
          const SizedBox(height: 12),
          _buildLocationDropdown(
            icon: Icons.location_on,
            value: municipalitySelected
                ? _selectedBarangay
                : 'Select Municipality First',
            items: municipalitySelected
                ? ['All Barangays', ...barangays]
                : ['Select Municipality First'],
            enabled: municipalitySelected,
            hint: municipalitySelected
                ? 'All Barangays'
                : 'Select Municipality First',
            onChanged: (value) {
              setState(() {
                _selectedBarangay = value;
              });
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary(List<QueryDocumentSnapshot> bills) {
    int paidCount = 0;
    int unpaidCount = 0;
    int cancelledCount = 0;

    double paidAmount = 0;
    double unpaidAmount = 0;

    for (final doc in bills) {
      final data = doc.data() as Map<String, dynamic>;
      final status = _getFirestoreStatus(data);
      final amount = _doubleValue(data, 'totalAmount');

      if (status == 'paid') {
        paidCount++;
        paidAmount += amount;
      } else if (status == 'cancelled' || status == 'canceled') {
        cancelledCount++;
      } else {
        unpaidCount++;
        unpaidAmount += amount;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryOrange.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  'Paid',
                  paidCount.toString(),
                  Colors.green,
                ),
              ),
              Expanded(
                child: _summaryItem(
                  'Unpaid',
                  unpaidCount.toString(),
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _summaryItem(
                  'Cancelled',
                  cancelledCount.toString(),
                  Colors.grey,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Paid Amount',
                style: TextStyle(color: Colors.grey),
              ),
              Text(
                '₱${paidAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Unpaid Amount',
                style: TextStyle(color: Colors.grey),
              ),
              Text(
                '₱${unpaidAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // ============================================================
  // BILL CARD
  // ============================================================

  Widget _buildBillCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final status = _getDisplayStatus(data);
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    final amount = _doubleValue(data, 'totalAmount');
    final consumption = _doubleValue(data, 'consumption');
    final previousReading = _doubleValue(data, 'previousReading');
    final currentReading = _doubleValue(data, 'currentReading');

    final rawBreakdown = data['breakdown'];
    final BillBreakdown? breakdown = rawBreakdown is Map
        ? BillBreakdown.fromMap(Map<String, dynamic>.from(rawBreakdown))
        : null;

    final billingPeriod = _stringValue(
      data,
      ['billingPeriod'],
      fallback: 'N/A',
    );

    final paymentStartDate =
        _parseDate(data['paymentStartDate']);
    final dueDate = _parseDate(data['dueDate']);
    final isUpdating = _updatingBillId == doc.id;
    final ticketNumber = BillModel.ticketNumberFor(data, doc.id);

    return Card(
      elevation: 3,
      shadowColor: primaryOrange.withValues(alpha: 0.25),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (ticketNumber.isNotEmpty) ...[
                  TicketBadge(
                    ticketNumber: ticketNumber,
                    color: primaryOrange,
                  ),
                  const SizedBox(width: 6),
                ],
                IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: 'Export bill',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showExportBillOptions(
                    context,
                    bill: data,
                    breakdown: breakdown,
                    ticketNumber: ticketNumber.isNotEmpty
                        ? ticketNumber
                        : doc.id,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _getConsumerName(data),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Account Number: ${_getAccountNumber(data)}'),
            Text('Billing Period: $billingPeriod'),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 17,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Location: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _getLocationText(data),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            if (breakdown != null) ...[
              BillBreakdownView(
                breakdown: breakdown,
                previousReading: previousReading,
                currentReading: currentReading,
                consumption: consumption,
                municipality: _getMunicipality(data),
              ),
              const SizedBox(height: 10),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Consumption',
                    style: TextStyle(color: Colors.grey),
                  ),
                  Text(
                    '${consumption.toStringAsFixed(2)} kWh',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(color: Colors.grey),
                  ),
                  Text(
                    '₱${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Payment Start',
                  style: TextStyle(color: Colors.grey),
                ),
                Text(
                  paymentStartDate != null
                      ? '${paymentStartDate.month}/'
                          '${paymentStartDate.day}/'
                          '${paymentStartDate.year}'
                      : 'N/A',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Due Date',
                  style: TextStyle(color: Colors.grey),
                ),
                Text(
                  dueDate != null
                      ? '${dueDate.month}/${dueDate.day}/${dueDate.year}'
                      : 'N/A',
                ),
              ],
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryOrange,
                  side: BorderSide(
                    color: primaryOrange.withValues(alpha: 0.6),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isUpdating
                    ? null
                    : () => _showStatusDialog(doc.id, _getFirestoreStatus(data)),
                icon: isUpdating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.rule_outlined),
                label: Text(isUpdating ? 'Updating...' : 'Edit Status'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    String message;

    if (_searchQuery.trim().isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 70,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 15),
            Text(
              'No bills match "${_searchQuery.trim()}".',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different keyword.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    switch (_selectedStatus) {
      case 'Paid':
        message = 'No paid bills found';
        break;
      case 'Unpaid':
        message = 'No unpaid bills found';
        break;
      case 'Cancelled':
        message = 'No cancelled bills found';
        break;
      default:
        message = 'No bills found';
    }

    if (_selectedMonth != 'All Months') {
      message += '\nfor $_selectedMonth';
    }

    if (_selectedMunicipality != 'All Municipalities') {
      message += '\nin $_selectedMunicipality';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 70,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 15),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try changing the filters.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
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
        title: const Text('Manage Bills'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('bills').snapshots(),
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
                        'Error loading bills:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final allBills = snapshot.data?.docs ?? [];

                final filteredBills = _filterBills(allBills);
                final bills = _sortBills(filteredBills);

                if (bills.isEmpty) {
                  return _buildEmptyState();
                }

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ListView(
                      padding:
                          const EdgeInsets.fromLTRB(15, 10, 15, 20),
                      children: [
                        _buildSummary(bills),
                        const SizedBox(height: 14),
                        ...bills.map(_buildBillCard),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
