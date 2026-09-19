import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:soreconnect/models/meter_reading_model.dart';
import 'package:soreconnect/models/rate_model.dart';
import 'package:soreconnect/services/rate_service.dart';
import 'package:soreconnect/data/sorsogon_address_data.dart';
import 'package:soreconnect/utils/bill_calculator.dart';
import 'package:soreconnect/widgets/bill_breakdown_view.dart';

class MeterReadingScreen extends StatefulWidget {
  const MeterReadingScreen({super.key});

  @override
  State<MeterReadingScreen> createState() => _MeterReadingScreenState();
}

class _MeterReadingScreenState extends State<MeterReadingScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // Keeps this tab's state alive when swiping to another bottom-nav
  // tab, instead of disposing and rebuilding from scratch each time.
  @override
  bool get wantKeepAlive => true;
  // ============================================================
  // FIREBASE / SERVICES
  // ============================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RateService _rateService = RateService();

  StreamSubscription<RateModel>? _rateSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _branchSub;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _searchValueController =
      TextEditingController();

  final TextEditingController _currentReadingController =
      TextEditingController();

  final TextEditingController _interestController =
      TextEditingController(text: '0');

  final TextEditingController _adjustmentsController =
      TextEditingController(text: '0');

  // ============================================================
  // SEARCH MODE
  //
  // Lets the meter reader look up the consumer by either their
  // account number or their meter number — some households only
  // have the meter number visible on-site.
  // ============================================================

  static const List<String> _searchModes = [
    'Account Number',
    'Meter Number',
  ];

  String _searchBy = _searchModes.first;

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = false;

  RateModel _currentRate = RateModel.defaultRate();

  Map<String, dynamic>? _consumer;

  double _previousReading = 0;
  double _consumption = 0;
  BillBreakdown? _breakdown;

  // ============================================================
  // LOCATION
  // ============================================================

  String? _selectedMunicipality;
  String? _selectedBarangay;

  late final List<String> _municipalities;

  List<String> _barangays = [];

  // Whether this meter reader's fixed branch (from their profile) is
  // still being fetched. The municipality is no longer picked by
  // hand here — it's always the reader's own assigned branch, and
  // only the barangay is selected within it.
  bool _branchLoading = true;

  // ============================================================
  // THEME
  // ============================================================

  static const Color _primaryOrange = Color(0xFFFF9800);

  static const Color _backgroundColor =
      Color(0xFFFFF8E7);

  static const Color _lightOrange =
      Color(0xFFFFF3E0);

  static const Color _green =
      Color(0xFF2E7D32);

  static const Color _lightGreen =
      Color(0xFFE8F5E9);

  // Strong ease-out — starts fast so the entrance feels responsive
  // rather than a generic linear/ease-in-out fade.
  static const Curve _easeOut = Cubic(0.23, 1, 0.32, 1);

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _searchButtonPressed = false;
  bool _submitButtonPressed = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _municipalities =
        getSorsogonSecondDistrictMunicipalities();

    _listenToBranch();

    _loadRate();

    _rateSub =
        _rateService.watchRate().listen((rate) {
      if (!mounted) return;

      setState(() {
        _currentRate = rate;
      });

      _computeBill(showError: false);
    });

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: _easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: _easeOut,
      ),
    );

    _entranceController.forward();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchValueController.dispose();
    _currentReadingController.dispose();
    _interestController.dispose();
    _adjustmentsController.dispose();

    _rateSub?.cancel();
    _branchSub?.cancel();
    _entranceController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD RATE
  // ============================================================

  Future<void> _loadRate() async {
    try {
      final rate =
          await _rateService.getCurrentRate();

      if (!mounted) return;

      setState(() {
        _currentRate = rate;
      });
    } catch (_) {
      // Keep default rate.
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(
    String message, {
    bool isError = true,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? Colors.red.shade700 : _green,
          behavior:
              SnackBarBehavior.floating,
          margin:
              const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ============================================================
  // LISTEN TO BRANCH
  //
  // The municipality is no longer picked by hand — it's always this
  // meter reader's own assigned branch, set in their profile. That
  // branch stays editable there, so this listens live (not a
  // one-off fetch) — if it's changed mid-session, this screen picks
  // it up immediately instead of showing a stale municipality.
  // ============================================================

  void _listenToBranch() {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      if (mounted) setState(() => _branchLoading = false);
      return;
    }

    _branchSub = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (doc) {
            if (!mounted) return;

            final municipality = doc.data()?['municipality']?.toString();

            final resolved =
                (municipality != null &&
                    municipality.isNotEmpty &&
                    _municipalities.contains(municipality))
                ? municipality
                : null;

            final changed = resolved != _selectedMunicipality;

            setState(() {
              _selectedMunicipality = resolved;
              _barangays = getBarangaysForMunicipality(_selectedMunicipality);
              _branchLoading = false;

              // The branch changed (e.g. reassigned from profile) —
              // clear anything scoped to the old municipality so
              // nothing stale (barangay, a loaded consumer) carries
              // over into the new one.
              if (changed) {
                _selectedBarangay = null;
                _consumer = null;
                _previousReading = 0;
                _consumption = 0;
                _breakdown = null;
                _searchValueController.clear();
                _currentReadingController.clear();
              }
            });
          },
          onError: (e) {
            if (!mounted) return;
            setState(() => _branchLoading = false);
          },
        );
  }

  // ============================================================
  // BARANGAY CHANGE
  // ============================================================

  void _onBarangayChanged(
    String? barangay,
  ) {
    setState(() {
      _selectedBarangay =
          barangay;

      _consumer = null;

      _previousReading = 0;
      _consumption = 0;
      _breakdown = null;

      _searchValueController.clear();
      _currentReadingController.clear();
    });
  }

  // ============================================================
  // SEARCH CONSUMER
  // ============================================================

  Future<void> _searchConsumer() async {
    final searchValue =
        _searchValueController.text.trim();

    final searchField = _searchBy == 'Meter Number'
        ? 'meterNumber'
        : 'accountNumber';

    final searchLabel = _searchBy == 'Meter Number'
        ? 'meter number'
        : 'account number';

    if (_selectedMunicipality == null) {
      _showSnackBar(
        "Your branch isn't set yet. Update your profile first.",
      );
      return;
    }

    if (_selectedBarangay == null) {
      _showSnackBar(
        "Please select a barangay first.",
      );
      return;
    }

    if (searchValue.isEmpty) {
      _showSnackBar(
        "Enter a consumer $searchLabel.",
      );
      return;
    }

    setState(() {
      _isLoading = true;

      _consumer = null;

      _previousReading = 0;
      _consumption = 0;
      _breakdown = null;
    });

    try {
      // Search by the chosen identifier first.
      //
      // Municipality and barangay are validated
      // after retrieving the consumer. This avoids
      // requiring a composite Firestore index.

      final consumerQuery =
          await _firestore
              .collection("users")
              .where(
                searchField,
                isEqualTo: searchValue,
              )
              .where(
                "user_type",
                isEqualTo: "consumer",
              )
              .limit(1)
              .get();

      if (consumerQuery.docs.isEmpty) {
        throw Exception(
          "No consumer found with $searchLabel $searchValue.",
        );
      }

      final consumerDoc =
          consumerQuery.docs.first;

      final consumerData =
          consumerDoc.data();

      // ----------------------------------------------------------
      // FIRESTORE LOCATION
      // ----------------------------------------------------------

      final firestoreMunicipality =
          _getStringValue(
        consumerData,
        [
          "municipality",
          "city",
          "municipalityCity",
        ],
      );

      final firestoreBarangay =
          _getStringValue(
        consumerData,
        [
          "barangay",
          "baranggay",
        ],
      );

      // ----------------------------------------------------------
      // CHECK MUNICIPALITY
      // ----------------------------------------------------------

      if (_normalizeLocation(
            firestoreMunicipality,
          ) !=
          _normalizeLocation(
            _selectedMunicipality,
          )) {
        throw Exception(
          "This account belongs to "
          "${firestoreMunicipality.isEmpty ? "another municipality" : firestoreMunicipality}, "
          "not $_selectedMunicipality.",
        );
      }

      // ----------------------------------------------------------
      // CHECK BARANGAY
      // ----------------------------------------------------------

      if (_normalizeLocation(
            firestoreBarangay,
          ) !=
          _normalizeLocation(
            _selectedBarangay,
          )) {
        throw Exception(
          "This account belongs to "
          "${firestoreBarangay.isEmpty ? "another barangay" : firestoreBarangay}, "
          "not $_selectedBarangay.",
        );
      }

      // ----------------------------------------------------------
      // GET LATEST READING
      // ----------------------------------------------------------

      final latestReading =
          await _firestore
              .collection("meter_readings")
              .where(
                "consumerId",
                isEqualTo:
                    consumerDoc.id,
              )
              .orderBy(
                "recordedAt",
                descending: true,
              )
              .limit(1)
              .get();

      double previous = 0;

      if (latestReading.docs.isNotEmpty) {
        final latestData =
            latestReading.docs.first.data();

        final value =
            latestData["currentReading"];

        if (value is num) {
          previous =
              value.toDouble();
        } else if (value is String) {
          previous =
              double.tryParse(value) ?? 0;
        }
      }

      final fullName =
          _getStringValue(
        consumerData,
        [
          "full_name",
          "fullName",
          "name",
          "consumerName",
        ],
      );

      final accountNumber =
          _getStringValue(
        consumerData,
        [
          "accountNumber",
          "accountNo",
          "account_number",
        ],
      );

      final meterNumber =
          _getStringValue(
        consumerData,
        [
          "meterNumber",
          "meterNo",
          "meter_number",
        ],
      );

      final province =
          _getStringValue(
        consumerData,
        [
          "province",
        ],
      );

      if (!mounted) return;

      setState(() {
        _consumer = {
          "uid": consumerDoc.id,
          ...consumerData,
          "full_name": fullName,
          "accountNumber": accountNumber.isEmpty &&
                  searchField == 'accountNumber'
              ? searchValue
              : accountNumber,
          "meterNumber": meterNumber.isEmpty &&
                  searchField == 'meterNumber'
              ? searchValue
              : meterNumber,
          "municipality":
              firestoreMunicipality,
          "barangay":
              firestoreBarangay,
          "province":
              province.isEmpty
                  ? sorsogonProvince
                  : province,
        };

        _previousReading =
            previous;
      });

      _showSnackBar(
        "Consumer found successfully.",
        isError: false,
      );
    } catch (e) {
      final message = e
          .toString()
          .replaceFirst(
            "Exception: ",
            "",
          );

      _showSnackBar(message);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // GET STRING
  // ============================================================

  String _getStringValue(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      final text =
          value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return "";
  }

  // ============================================================
  // NORMALIZE LOCATION
  // ============================================================

  String _normalizeLocation(
    String? value,
  ) {
    if (value == null) {
      return "";
    }

    return value
        .trim()
        .toLowerCase()
        .replaceAll(
          RegExp(r"\s+"),
          " ",
        );
  }

  // ============================================================
  // COMPUTE BILL
  // ============================================================

  double _parseNonNegative(String text) {
    final value = double.tryParse(text.trim());
    if (value == null || value < 0) return 0;
    return value;
  }

  void _computeBill({
    bool showError = true,
  }) {
    final text =
        _currentReadingController.text.trim();

    if (text.isEmpty) {
      if (!mounted) return;

      setState(() {
        _consumption = 0;
        _breakdown = null;
      });

      return;
    }

    final current =
        double.tryParse(text);

    if (current == null) {
      if (!mounted) return;

      setState(() {
        _consumption = 0;
        _breakdown = null;
      });

      return;
    }

    if (current < _previousReading) {
      if (!mounted) return;

      setState(() {
        _consumption = 0;
        _breakdown = null;
      });

      if (showError) {
        _showSnackBar(
          "Current reading cannot be lower than "
          "previous reading.",
        );
      }

      return;
    }

    final consumption =
        current - _previousReading;

    final breakdown = computeBillBreakdown(
      rate: _currentRate,
      consumption: consumption,
      interest: _parseNonNegative(_interestController.text),
      adjustments: _parseNonNegative(_adjustmentsController.text),
    );

    if (!mounted) return;

    setState(() {
      _consumption = consumption;
      _breakdown = breakdown;
    });
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _submitReading() async {
    if (_consumer == null) {
      _showSnackBar(
        "Search a consumer first.",
      );
      return;
    }

    if (_selectedMunicipality == null ||
        _selectedBarangay == null) {
      _showSnackBar(
        "Your branch isn't set yet, or no barangay is selected.",
      );
      return;
    }

    final currentReading =
        double.tryParse(
      _currentReadingController.text.trim(),
    );

    if (currentReading == null) {
      _showSnackBar(
        "Enter a valid meter reading.",
      );
      return;
    }

    if (currentReading <
        _previousReading) {
      _showSnackBar(
        "Current reading cannot be lower than "
        "previous reading.",
      );
      return;
    }

    final consumption =
        currentReading -
            _previousReading;

    final breakdown = computeBillBreakdown(
      rate: _currentRate,
      consumption: consumption,
      interest: _parseNonNegative(_interestController.text),
      adjustments: _parseNonNegative(_adjustmentsController.text),
    );

    final computedAmount = breakdown.totalAmount;

    final effectiveRate =
        consumption > 0 ? computedAmount / consumption : 0.0;

    setState(() {
      _isLoading = true;
    });

    try {
      final readingRef =
          _firestore
              .collection(
                "meter_readings",
              )
              .doc();

      final billRef =
          _firestore
              .collection(
                "bills",
              )
              .doc();

      final billingPeriod =
          DateFormat(
            "MMMM yyyy",
          ).format(
            DateTime.now(),
          );

      final meterReader =
          _auth.currentUser;

      final consumerId =
          _consumer!["uid"]
              .toString();

      final consumerName =
          _getStringValue(
        _consumer!,
        [
          "full_name",
          "fullName",
          "name",
          "consumerName",
        ],
      );

      final accountNumber =
          _getStringValue(
        _consumer!,
        [
          "accountNumber",
          "accountNo",
          "account_number",
        ],
      );

      final meterNumber =
          _getStringValue(
        _consumer!,
        [
          "meterNumber",
          "meterNo",
          "meter_number",
        ],
      );

      final municipality =
          _getStringValue(
        _consumer!,
        [
          "municipality",
          "city",
        ],
      );

      final barangay =
          _getStringValue(
        _consumer!,
        [
          "barangay",
          "baranggay",
        ],
      );

      final province =
          _getStringValue(
        _consumer!,
        [
          "province",
        ],
      );

      // ----------------------------------------------------------
      // METER READING MODEL
      // ----------------------------------------------------------

      final reading =
          MeterReadingModel(
        readingId:
            readingRef.id,

        consumerId:
            consumerId,

        consumerName:
            consumerName,

        accountNumber:
            accountNumber,

        previousReading:
            _previousReading,

        currentReading:
            currentReading,

        consumption:
            consumption,

        ratePerKwh:
            effectiveRate,

        computedAmount:
            computedAmount,

        breakdown:
            breakdown,

        billingPeriod:
            billingPeriod,

        status:
            "Billed",

        recordedBy:
            meterReader?.email ??
                "Meter Reader",
      );

      // ----------------------------------------------------------
      // RESOLVED LOCATION
      // ----------------------------------------------------------

      final resolvedMunicipality =
          municipality.isEmpty
              ? (_selectedMunicipality ?? "")
              : municipality;

      final resolvedBarangay =
          barangay.isEmpty
              ? (_selectedBarangay ?? "")
              : barangay;

      final resolvedProvince =
          province.isEmpty
              ? sorsogonProvince
              : province;

      final resolvedAddress =
          buildSorsogonAddress(
        municipality: resolvedMunicipality,
        barangay: resolvedBarangay,
      );

      // ----------------------------------------------------------
      // PAYMENT WINDOW
      //
      // Relative to the reading date: payment opens 4 days after
      // the reading, and is due 6 days after that payment start.
      // ----------------------------------------------------------

      final now = DateTime.now();

      final paymentStartDate = now.add(
        const Duration(days: 4),
      );

      final dueDate = paymentStartDate.add(
        const Duration(days: 6),
      );

      // ----------------------------------------------------------
      // SAVE READING + BILL TOGETHER
      //
      // The bill is posted directly for the consumer without a
      // separate teller verification step. The teller can still
      // edit the bill's paid/unpaid/cancelled status afterward.
      // ----------------------------------------------------------

      final batch = _firestore.batch();

      batch.set(readingRef, {
        ...reading.toMap(),
        // Stable identifier for "my recorded readings" filtering —
        // unlike `recordedBy` (email), this never breaks if the
        // meter reader's account email changes later.
        "recordedByUid": meterReader?.uid,
        "meterNumber": meterNumber,
        "barangay": resolvedBarangay,
        "municipality": resolvedMunicipality,
        "province": resolvedProvince,
        "address": resolvedAddress,
        "recordedAt": FieldValue.serverTimestamp(),
      });

      batch.set(billRef, {
        "billId": billRef.id,
        "consumerId": consumerId,
        "consumerName": consumerName,
        "accountNumber": accountNumber,
        "meterNumber": meterNumber,
        "barangay": resolvedBarangay,
        "municipality": resolvedMunicipality,
        "province": resolvedProvince,
        "address": resolvedAddress,
        "previousReading": _previousReading,
        "currentReading": currentReading,
        "consumption": consumption,
        "ratePerKwh": effectiveRate,
        "totalAmount": computedAmount,
        "breakdown": breakdown.toMap(),
        "billingPeriod": billingPeriod,
        "paymentStartDate": Timestamp.fromDate(paymentStartDate),
        "dueDate": Timestamp.fromDate(dueDate),
        "status": "unpaid",
        "generatedBy": meterReader?.email ?? "Meter Reader",
        "generatedAt": FieldValue.serverTimestamp(),
      });

      await batch.commit();

      _showSnackBar(
        "Meter reading submitted and bill posted successfully.",
        isError: false,
      );

      // Keep location filters selected.
      setState(() {
        _consumer = null;

        _previousReading = 0;
        _consumption = 0;
        _breakdown = null;

        _searchValueController.clear();
        _currentReadingController.clear();
        _interestController.text = '0';
        _adjustmentsController.text = '0';
      });
    } catch (e) {
      final message = e
          .toString()
          .replaceFirst(
            "Exception: ",
            "",
          );

      _showSnackBar(message);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    super.build(context);

    return Scaffold(
      backgroundColor:
          _backgroundColor,

      appBar: AppBar(
        elevation: 0,

        backgroundColor:
            _primaryOrange,

        foregroundColor:
            Colors.white,

        title:
            const Text(
          "Record Meter Reading",
        ),
      ),

      body:
          SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            30,
          ),

          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              // ==================================================
              // HEADER
              // ==================================================

              _buildHeaderCard(),

              const SizedBox(
                height: 24,
              ),

              // ==================================================
              // LOCATION SECTION
              // ==================================================

              const Text(
                "Consumer Location",
                style:
                    TextStyle(
                  fontSize: 23,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      Colors.black87,
                ),
              ),

              const SizedBox(
                height: 6,
              ),

              Text(
                "Select the household's barangay within your "
                "branch before searching the account.",
                style:
                    TextStyle(
                  fontSize: 14,
                  color:
                      Colors.grey.shade600,
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              _buildMunicipalityDropdown(),

              const SizedBox(
                height: 16,
              ),

              _buildBarangayDropdown(),

              const SizedBox(
                height: 24,
              ),

              // ==================================================
              // ACCOUNT SEARCH
              // ==================================================

              _buildAccountSearch(),

              const SizedBox(
                height: 24,
              ),

              // ==================================================
              // CONTENT
              // ==================================================

              if (_consumer == null)
                _buildEmptyState()
              else
                ..._buildReadingForm(),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER CARD
  // ============================================================

  Widget _buildHeaderCard() {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(20),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.16,
            ),
            blurRadius:
                24,
            offset:
                const Offset(
              0,
              12,
            ),
          ),
          BoxShadow(
            color:
                _primaryOrange.withValues(
              alpha: 0.08,
            ),
            blurRadius:
                40,
            offset:
                const Offset(
              0,
              20,
            ),
          ),
        ],
      ),

      child:
          Row(
        children: [
          Container(
            width: 52,
            height: 52,

            decoration:
                BoxDecoration(
              color:
                  _lightOrange,

              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),

            child:
                const Icon(
              Icons.speed_outlined,
              color:
                  _primaryOrange,
              size:
                  30,
            ),
          ),

          const SizedBox(
            width: 15,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  "Record Meter Reading",
                  style:
                      TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  "Submit a household meter reading. "
                  "A bill is posted to the consumer immediately.",
                  style:
                      TextStyle(
                    fontSize: 13,
                    color:
                        Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BRANCH DISPLAY (LOCKED)
  //
  // The municipality is no longer a dropdown — it's this meter
  // reader's own fixed branch, set once in their profile. Shown
  // here read-only so it's clear where the household search is
  // scoped to, without letting it be changed from this screen.
  // ============================================================

  Widget _buildMunicipalityDropdown() {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(16),

        border:
            Border.all(
          color:
              Colors.grey.shade200,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.025,
            ),
            blurRadius:
                6,
            offset:
                const Offset(
              0,
              3,
            ),
          ),
        ],
      ),

      child: Row(
        children: [
          Icon(
            Icons.location_city_outlined,
            color: _primaryOrange,
            size: 25,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: _branchLoading
                ? Text(
                    "Loading your branch...",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                    ),
                  )
                : Text(
                    _selectedMunicipality ??
                        "Branch not set — update your profile first",
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedMunicipality == null
                          ? Colors.red.shade600
                          : Colors.black87,
                    ),
                  ),
          ),

          Icon(
            Icons.lock_outline,
            color: Colors.grey.shade400,
            size: 18,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BARANGAY DROPDOWN
  // ============================================================

  Widget _buildBarangayDropdown() {
    final enabled =
        _selectedMunicipality != null;

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 5,
      ),

      decoration:
          BoxDecoration(
        color:
            enabled
                ? Colors.white
                : Colors.grey.shade100,

        borderRadius:
            BorderRadius.circular(16),

        border:
            Border.all(
          color:
              Colors.grey.shade200,
        ),

        boxShadow:
            enabled
                ? [
                    BoxShadow(
                      color:
                          Colors.black
                              .withValues(
                        alpha: 0.025,
                      ),
                      blurRadius:
                          6,
                      offset:
                          const Offset(
                        0,
                        3,
                      ),
                    ),
                  ]
                : null,
      ),

      child:
          DropdownButtonHideUnderline(
        child:
            DropdownButton<String>(
          value:
              _selectedBarangay,

          isExpanded:
              true,

          borderRadius:
              BorderRadius.circular(
            16,
          ),

          hint:
              Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color:
                    enabled
                        ? Colors.grey.shade700
                        : Colors.grey.shade400,
                size:
                    25,
              ),

              const SizedBox(
                width: 12,
              ),

              Text(
                enabled
                    ? "Select Barangay"
                    : "Set your branch in Profile first",

                style:
                    TextStyle(
                  fontSize: 16,
                  color:
                      enabled
                          ? Colors.black87
                          : Colors.grey.shade500,
                ),
              ),
            ],
          ),

          icon:
              Icon(
            Icons.keyboard_arrow_down_rounded,
            color:
                enabled
                    ? Colors.grey
                    : Colors.grey.shade400,
          ),

          items:
              _barangays.map(
            (barangay) {
              return DropdownMenuItem<String>(
                value:
                    barangay,

                child:
                    Text(
                  barangay,
                  style:
                      const TextStyle(
                    fontSize: 16,
                  ),
                ),
              );
            },
          ).toList(),

          onChanged:
              !enabled ||
                      _isLoading
                  ? null
                  : _onBarangayChanged,
        ),
      ),
    );
  }

  // ============================================================
  // ACCOUNT SEARCH
  // ============================================================

  Widget _buildAccountSearch() {
    final enabled =
        _selectedMunicipality != null &&
            _selectedBarangay != null;

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.16,
            ),
            blurRadius:
                24,
            offset:
                const Offset(
              0,
              12,
            ),
          ),
          BoxShadow(
            color:
                _primaryOrange.withValues(
              alpha: 0.08,
            ),
            blurRadius:
                40,
            offset:
                const Offset(
              0,
              20,
            ),
          ),
        ],
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Text(
            "Find Consumer",
            style:
                TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            enabled
                ? "Search a household within your branch."
                : "Select a barangay first.",

            style:
                TextStyle(
              fontSize: 12,
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          // ==================================================
          // SEARCH MODE TOGGLE
          // ==================================================

          Row(
            children: _searchModes.map((mode) {
              final selected = _searchBy == mode;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(mode),
                  selected: selected,
                  onSelected: (!enabled || _isLoading)
                      ? null
                      : (_) {
                          setState(() {
                            _searchBy = mode;
                            _searchValueController.clear();
                          });
                        },
                  selectedColor:
                      _primaryOrange.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: selected
                        ? _primaryOrange
                        : Colors.grey.shade700,
                    fontWeight: selected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12.5,
                  ),
                  side: BorderSide(
                    color: selected
                        ? _primaryOrange
                        : Colors.grey.shade300,
                  ),
                  backgroundColor: Colors.grey.shade50,
                ),
              );
            }).toList(),
          ),

          const SizedBox(
            height: 12,
          ),

          Row(
            children: [
              Expanded(
                child:
                    TextField(
                  controller:
                      _searchValueController,

                  enabled:
                      enabled &&
                      !_isLoading,

                  cursorColor:
                      _primaryOrange,

                  keyboardType:
                      TextInputType.text,

                  textInputAction:
                      TextInputAction.search,

                  onSubmitted: (_) {
                    if (enabled &&
                        !_isLoading) {
                      _searchConsumer();
                    }
                  },

                  decoration:
                      InputDecoration(
                    hintText:
                        enabled
                            ? (_searchBy == 'Meter Number'
                                ? "Enter meter number"
                                : "Enter account number")
                            : "Select location first",

                    prefixIcon:
                        Icon(
                      _searchBy == 'Meter Number'
                          ? Icons.speed_outlined
                          : Icons.badge_outlined,
                      color:
                          _primaryOrange,
                    ),

                    filled:
                        true,

                    fillColor:
                        enabled
                            ? Colors.grey.shade50
                            : Colors.grey.shade100,

                    contentPadding:
                        const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 16,
                    ),

                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                      borderSide:
                          BorderSide(
                        color:
                            Colors.grey.shade200,
                      ),
                    ),

                    enabledBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                      borderSide:
                          BorderSide(
                        color:
                            Colors.grey.shade200,
                      ),
                    ),

                    focusedBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                      borderSide:
                          const BorderSide(
                        color:
                            _primaryOrange,
                        width:
                            1.5,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Listener(
                onPointerDown: (_) {
                  if (!_isLoading && enabled) {
                    setState(
                      () => _searchButtonPressed = true,
                    );
                  }
                },
                onPointerUp: (_) => setState(
                  () => _searchButtonPressed = false,
                ),
                onPointerCancel: (_) => setState(
                  () => _searchButtonPressed = false,
                ),
                child: AnimatedScale(
                  scale:
                      _searchButtonPressed ? 0.97 : 1.0,
                  duration: const Duration(
                    milliseconds: 120,
                  ),
                  curve: Curves.easeOut,
                  child: SizedBox(
                height: 55,

                child:
                    ElevatedButton(
                  onPressed:
                      _isLoading ||
                              !enabled
                          ? null
                          : _searchConsumer,

                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        _primaryOrange,

                    disabledBackgroundColor:
                        Colors.grey.shade300,

                    foregroundColor:
                        Colors.white,

                    disabledForegroundColor:
                        Colors.grey.shade500,

                    elevation:
                        0,

                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 17,
                    ),

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),

                  child:
                      _isLoading
                          ? const SizedBox(
                              width: 21,
                              height: 21,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                                color:
                                    Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.search,
                              size:
                                  24,
                            ),
                ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    final locationReady =
        _selectedMunicipality != null &&
            _selectedBarangay != null;

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 35,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.16,
            ),
            blurRadius:
                24,
            offset:
                const Offset(
              0,
              12,
            ),
          ),
          BoxShadow(
            color:
                _primaryOrange.withValues(
              alpha: 0.08,
            ),
            blurRadius:
                40,
            offset:
                const Offset(
              0,
              20,
            ),
          ),
        ],
      ),

      child:
          Column(
        children: [
          Container(
            width:
                70,
            height:
                70,

            decoration:
                BoxDecoration(
              color:
                  _lightOrange,

              shape:
                  BoxShape.circle,
            ),

            child:
                Icon(
              locationReady
                  ? Icons.person_search_outlined
                  : Icons.location_searching,
              size:
                  36,
              color:
                  _primaryOrange,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          Text(
            locationReady
                ? "Ready to Search"
                : "Select Household Location",

            style:
                const TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            locationReady
                ? "Enter the consumer's account number "
                  "or meter number above to continue."
                : "Choose a barangay within your branch "
                  "before searching for a consumer.",

            textAlign:
                TextAlign.center,

            style:
                TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize:
                  14,
              height:
                  1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // READING FORM
  // ============================================================

  List<Widget> _buildReadingForm() {
    final name =
        _getStringValue(
      _consumer!,
      [
        "full_name",
        "fullName",
        "name",
        "consumerName",
      ],
    );

    final accountNumber =
        _getStringValue(
      _consumer!,
      [
        "accountNumber",
        "accountNo",
        "account_number",
      ],
    );

    final meterNumber =
        _getStringValue(
      _consumer!,
      [
        "meterNumber",
        "meterNo",
        "meter_number",
      ],
    );

    final barangay =
        _getStringValue(
      _consumer!,
      [
        "barangay",
        "baranggay",
      ],
    );

    final municipality =
        _getStringValue(
      _consumer!,
      [
        "municipality",
        "city",
      ],
    );

    final province =
        _getStringValue(
      _consumer!,
      [
        "province",
      ],
    );

    final currentText =
        _currentReadingController.text.trim();

    final parsedCurrent =
        double.tryParse(
          currentText,
        );

    return [
      // ========================================================
      // CONSUMER INFORMATION
      // ========================================================

      Container(
        width:
            double.infinity,

        padding:
            const EdgeInsets.all(20),

        decoration:
            BoxDecoration(
          color:
              Colors.white,

          borderRadius:
              BorderRadius.circular(
            24,
          ),

          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(
                alpha: 0.16,
              ),
              blurRadius:
                  24,
              offset:
                  const Offset(
                0,
                12,
              ),
            ),
            BoxShadow(
              color:
                  _primaryOrange.withValues(
                alpha: 0.08,
              ),
              blurRadius:
                  40,
              offset:
                  const Offset(
                0,
                20,
              ),
            ),
          ],
        ),

        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                Container(
                  width:
                      44,
                  height:
                      44,

                  decoration:
                      BoxDecoration(
                    color:
                        _lightOrange,

                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),

                  child:
                      const Icon(
                    Icons.person_outline,
                    color:
                        _primaryOrange,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                const Text(
                  "Consumer Information",
                  style:
                      TextStyle(
                    fontSize: 19,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            _buildInfoRow(
              "Name",
              name.isEmpty
                  ? "Not available"
                  : name,
            ),

            _buildInfoRow(
              "Account No.",
              accountNumber.isEmpty
                  ? "Not available"
                  : accountNumber,
            ),

            _buildInfoRow(
              "Meter No.",
              meterNumber.isEmpty
                  ? "Not available"
                  : meterNumber,
            ),

            _buildInfoRow(
              "Barangay",
              barangay.isEmpty
                  ? "Not available"
                  : barangay,
            ),

            _buildInfoRow(
              "Municipality",
              municipality.isEmpty
                  ? "Not available"
                  : municipality,
            ),

            _buildInfoRow(
              "Province",
              province.isEmpty
                  ? sorsogonProvince
                  : province,
            ),

            const SizedBox(
              height: 8,
            ),

            Container(
              width:
                  double.infinity,

              padding:
                  const EdgeInsets.all(
                14,
              ),

              decoration:
                  BoxDecoration(
                color:
                    _lightOrange,

                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
              ),

              child:
                  Row(
                children: [
                  const Icon(
                    Icons.speed_outlined,
                    color:
                        _primaryOrange,
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  const Text(
                    "Previous Reading",
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const Spacer(),

                  Text(
                    "${_previousReading.toStringAsFixed(2)} kWh",
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      const SizedBox(
        height: 24,
      ),

      // ========================================================
      // CURRENT READING
      // ========================================================

      const Text(
        "Current Meter Reading",
        style:
            TextStyle(
          fontSize: 23,
          fontWeight:
              FontWeight.bold,
        ),
      ),

      const SizedBox(
        height: 8,
      ),

      Text(
        "Enter the current reading shown on the household meter.",
        style:
            TextStyle(
          fontSize: 13,
          color:
              Colors.grey.shade600,
        ),
      ),

      const SizedBox(
        height: 12,
      ),

      Container(
        padding:
            const EdgeInsets.all(18),

        decoration:
            BoxDecoration(
          color:
              Colors.white,

          borderRadius:
              BorderRadius.circular(
            24,
          ),

          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(
                alpha: 0.16,
              ),
              blurRadius:
                  24,
              offset:
                  const Offset(
                0,
                12,
              ),
            ),
            BoxShadow(
              color:
                  _primaryOrange.withValues(
                alpha: 0.08,
              ),
              blurRadius:
                  40,
              offset:
                  const Offset(
                0,
                20,
              ),
            ),
          ],
        ),

        child:
            TextField(
          controller:
              _currentReadingController,

          enabled:
              !_isLoading,

          cursorColor:
              _primaryOrange,

          keyboardType:
              const TextInputType.numberWithOptions(
            decimal: true,
          ),

          onChanged: (_) {
            _computeBill(
              showError: false,
            );
          },

          decoration:
              InputDecoration(
            hintText:
                "Enter current reading",

            suffixText:
                "kWh",

            prefixIcon:
                const Icon(
              Icons.speed_outlined,
              color:
                  _primaryOrange,
            ),

            filled:
                true,

            fillColor:
                Colors.grey.shade50,

            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 17,
            ),

            border:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
              borderSide:
                  BorderSide(
                color:
                    Colors.grey.shade200,
              ),
            ),

            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
              borderSide:
                  BorderSide(
                color:
                    Colors.grey.shade200,
              ),
            ),

            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
              borderSide:
                  const BorderSide(
                color:
                    _primaryOrange,
                width:
                    1.5,
              ),
            ),
          ),
        ),
      ),

      const SizedBox(
        height: 24,
      ),

      // ========================================================
      // BILL COMPUTATION
      // ========================================================

      Container(
        width:
            double.infinity,

        padding:
            const EdgeInsets.all(20),

        decoration:
            BoxDecoration(
          color:
              Colors.white,

          borderRadius:
              BorderRadius.circular(
            24,
          ),

          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(
                alpha: 0.16,
              ),
              blurRadius:
                  24,
              offset:
                  const Offset(
                0,
                12,
              ),
            ),
            BoxShadow(
              color:
                  _primaryOrange.withValues(
                alpha: 0.08,
              ),
              blurRadius:
                  40,
              offset:
                  const Offset(
                0,
                20,
              ),
            ),
          ],
        ),

        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                Container(
                  width:
                      44,
                  height:
                      44,

                  decoration:
                      BoxDecoration(
                    color:
                        _lightOrange,

                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),

                  child:
                      const Icon(
                    Icons.receipt_long_outlined,
                    color:
                        _primaryOrange,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                const Text(
                  "Bill Computation",
                  style:
                      TextStyle(
                    fontSize: 19,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 20,
            ),

            _buildSummaryRow(
              "Previous Reading",
              "${_previousReading.toStringAsFixed(2)} kWh",
            ),

            _buildSummaryRow(
              "Current Reading",
              parsedCurrent == null
                  ? "0.00 kWh"
                  : "${parsedCurrent.toStringAsFixed(2)} kWh",
            ),

            _buildSummaryRow(
              "Consumption",
              "${_consumption.toStringAsFixed(2)} kWh",
            ),

            const SizedBox(
              height: 16,
            ),

            const Divider(),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // INTEREST / ADJUSTMENTS (manual, one-off amounts)
            // ==================================================

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _interestController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => _computeBill(showError: false),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: "Interest",
                      prefixText: "₱ ",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _adjustmentsController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => _computeBill(showError: false),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: "Adjustments",
                      prefixText: "₱ ",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // ITEMIZED BILL BREAKDOWN
            // ==================================================

            if (_breakdown != null)
              BillBreakdownView(
                breakdown: _breakdown!,
                previousReading: _previousReading,
                currentReading: parsedCurrent ?? _previousReading,
                consumption: _consumption,
                municipality: municipality.isNotEmpty
                    ? municipality
                    : (_selectedMunicipality ?? ''),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _lightOrange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      color: _primaryOrange,
                      size: 30,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Enter a current reading to see the itemized bill.",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // INFORMATION MESSAGE
            // ==================================================

            Container(
              width:
                  double.infinity,

              padding:
                  const EdgeInsets.all(
                14,
              ),

              decoration:
                  BoxDecoration(
                color:
                    _lightGreen,

                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
              ),

              child:
                  const Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Icon(
                    Icons.info_outline,
                    color:
                        _green,
                  ),

                  SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child:
                        Text(
                      "The bill will be posted to the consumer "
                      "immediately upon submission. The teller "
                      "can update its paid/unpaid status "
                      "afterward.",
                      style:
                          TextStyle(
                        color:
                            _green,
                        fontSize:
                            13,
                        height:
                            1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // ==================================================
            // SUBMIT BUTTON
            // ==================================================

            Listener(
              onPointerDown: (_) {
                if (!_isLoading) {
                  setState(
                    () => _submitButtonPressed = true,
                  );
                }
              },
              onPointerUp: (_) => setState(
                () => _submitButtonPressed = false,
              ),
              onPointerCancel: (_) => setState(
                () => _submitButtonPressed = false,
              ),
              child: AnimatedScale(
                scale:
                    _submitButtonPressed ? 0.97 : 1.0,
                duration: const Duration(
                  milliseconds: 120,
                ),
                curve: Curves.easeOut,
                child: SizedBox(
              width:
                  double.infinity,

              height:
                  54,

              child:
                  ElevatedButton.icon(
                onPressed:
                    _isLoading
                        ? null
                        : _submitReading,

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      _primaryOrange,

                  foregroundColor:
                      Colors.white,

                  disabledBackgroundColor:
                      Colors.grey.shade300,

                  elevation:
                      0,

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                ),

                icon:
                    _isLoading
                        ? const SizedBox(
                            width:
                                21,
                            height:
                                21,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.save_outlined,
                          ),

                label:
                    Text(
                  _isLoading
                      ? "Submitting..."
                      : "Submit Meter Reading",
                  style:
                      const TextStyle(
                    fontSize:
                        15,
                    fontWeight:
                        FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ============================================================
  // INFORMATION ROW
  // ============================================================

  Widget _buildInfoRow(
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),

      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          SizedBox(
            width:
                115,

            child:
                Text(
              "$title:",
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.w600,
                color:
                    Colors.grey.shade700,
              ),
            ),
          ),

          Expanded(
            child:
                Text(
              value,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY ROW
  // ============================================================

  Widget _buildSummaryRow(
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),

      child:
          Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,

        children: [
          Text(
            title,
            style:
                TextStyle(
              color:
                  Colors.grey.shade700,
              fontSize:
                  14,
            ),
          ),

          Text(
            value,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w600,
              fontSize:
                  14,
            ),
          ),
        ],
      ),
    );
  }
}