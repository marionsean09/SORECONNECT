import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:soreconnect/models/meter_reading_model.dart';
import 'package:soreconnect/services/rate_service.dart';
import 'package:soreconnect/data/sorsogon_address_data.dart';

class MeterReadingScreen extends StatefulWidget {
  const MeterReadingScreen({super.key});

  @override
  State<MeterReadingScreen> createState() => _MeterReadingScreenState();
}

class _MeterReadingScreenState extends State<MeterReadingScreen> {
  // ============================================================
  // FIREBASE / SERVICES
  // ============================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RateService _rateService = RateService();

  StreamSubscription<double>? _rateSub;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _accountNumberController =
      TextEditingController();

  final TextEditingController _currentReadingController =
      TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = false;

  double _currentRate = 12.0;

  Map<String, dynamic>? _consumer;

  double _previousReading = 0;
  double _consumption = 0;
  double _computedAmount = 0;

  // ============================================================
  // LOCATION
  // ============================================================

  String? _selectedMunicipality;
  String? _selectedBarangay;

  late final List<String> _municipalities;

  List<String> _barangays = [];

  // ============================================================
  // THEME
  // ============================================================

  static const Color _primaryOrange = Color(0xFFFF9800);
  static const Color _darkOrange = Color(0xFFF57C00);

  static const Color _backgroundColor =
      Color(0xFFFFF8E7);

  static const Color _lightOrange =
      Color(0xFFFFF3E0);

  static const Color _green =
      Color(0xFF2E7D32);

  static const Color _lightGreen =
      Color(0xFFE8F5E9);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _municipalities =
        getSorsogonSecondDistrictMunicipalities();

    _loadRate();

    _rateSub =
        _rateService.watchRate().listen((rate) {
      if (!mounted) return;

      setState(() {
        _currentRate = rate;
      });

      _computeBill(showError: false);
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _accountNumberController.dispose();
    _currentReadingController.dispose();

    _rateSub?.cancel();

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
  // MUNICIPALITY CHANGE
  // ============================================================

  void _onMunicipalityChanged(
    String? municipality,
  ) {
    setState(() {
      _selectedMunicipality =
          municipality;

      _selectedBarangay = null;

      _barangays =
          getBarangaysForMunicipality(
        municipality,
      );

      _consumer = null;

      _previousReading = 0;
      _consumption = 0;
      _computedAmount = 0;

      _accountNumberController.clear();
      _currentReadingController.clear();
    });
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
      _computedAmount = 0;

      _accountNumberController.clear();
      _currentReadingController.clear();
    });
  }

  // ============================================================
  // SEARCH CONSUMER
  // ============================================================

  Future<void> _searchConsumer() async {
    final account =
        _accountNumberController.text.trim();

    if (_selectedMunicipality == null) {
      _showSnackBar(
        "Please select a municipality first.",
      );
      return;
    }

    if (_selectedBarangay == null) {
      _showSnackBar(
        "Please select a barangay first.",
      );
      return;
    }

    if (account.isEmpty) {
      _showSnackBar(
        "Enter a consumer account number.",
      );
      return;
    }

    setState(() {
      _isLoading = true;

      _consumer = null;

      _previousReading = 0;
      _consumption = 0;
      _computedAmount = 0;
    });

    try {
      // Search account number first.
      //
      // Municipality and barangay are validated
      // after retrieving the consumer. This avoids
      // requiring a composite Firestore index.

      final consumerQuery =
          await _firestore
              .collection("users")
              .where(
                "accountNumber",
                isEqualTo: account,
              )
              .where(
                "user_type",
                isEqualTo: "consumer",
              )
              .limit(1)
              .get();

      if (consumerQuery.docs.isEmpty) {
        throw Exception(
          "No consumer found with account number $account.",
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
          "accountNumber":
              accountNumber.isEmpty
                  ? account
                  : accountNumber,
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

  void _computeBill({
    bool showError = true,
  }) {
    final text =
        _currentReadingController.text.trim();

    if (text.isEmpty) {
      if (!mounted) return;

      setState(() {
        _consumption = 0;
        _computedAmount = 0;
      });

      return;
    }

    final current =
        double.tryParse(text);

    if (current == null) {
      if (!mounted) return;

      setState(() {
        _consumption = 0;
        _computedAmount = 0;
      });

      return;
    }

    if (current < _previousReading) {
      if (!mounted) return;

      setState(() {
        _consumption = 0;
        _computedAmount = 0;
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

    final amount =
        consumption * _currentRate;

    if (!mounted) return;

    setState(() {
      _consumption = consumption;
      _computedAmount = amount;
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
        "Please select the municipality and barangay first.",
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

    final computedAmount =
        consumption * _currentRate;

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
            _currentRate,

        computedAmount:
            computedAmount,

        billingPeriod:
            billingPeriod,

        status:
            "Pending",

        recordedBy:
            meterReader?.email ??
                "Meter Reader",
      );

      // ----------------------------------------------------------
      // SAVE
      // ----------------------------------------------------------

      await readingRef.set({
        ...reading.toMap(),

        "barangay":
            barangay.isEmpty
                ? _selectedBarangay
                : barangay,

        "municipality":
            municipality.isEmpty
                ? _selectedMunicipality
                : municipality,

        "province":
            province.isEmpty
                ? sorsogonProvince
                : province,

        "address":
            buildSorsogonAddress(
          municipality:
              municipality.isEmpty
                  ? (_selectedMunicipality ??
                      "")
                  : municipality,
          barangay:
              barangay.isEmpty
                  ? (_selectedBarangay ??
                      "")
                  : barangay,
        ),

        "recordedAt":
            FieldValue.serverTimestamp(),
      });

      _showSnackBar(
        "Meter reading submitted successfully.\n"
        "Waiting for Teller verification.",
        isError: false,
      );

      // Keep location filters selected.
      setState(() {
        _consumer = null;

        _previousReading = 0;
        _consumption = 0;
        _computedAmount = 0;

        _accountNumberController.clear();
        _currentReadingController.clear();
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
          style: TextStyle(
            fontWeight:
                FontWeight.w600,
          ),
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
                      Colors.black,
                ),
              ),

              const SizedBox(
                height: 6,
              ),

              Text(
                "Select the household location before searching "
                "the account.",
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
                height: 14,
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
            BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.05,
            ),
            blurRadius:
                12,
            offset:
                const Offset(
              0,
              5,
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
                15,
              ),
            ),

            child:
                const Icon(
              Icons.speed,
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
                  "Submit a household meter reading "
                  "for teller verification.",
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
  // MUNICIPALITY DROPDOWN
  // ============================================================

  Widget _buildMunicipalityDropdown() {
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
            Colors.white,

        borderRadius:
            BorderRadius.circular(18),

        border:
            Border.all(
          color:
              Colors.grey.shade300,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.025,
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

      child:
          DropdownButtonHideUnderline(
        child:
            DropdownButton<String>(
          value:
              _selectedMunicipality,

          isExpanded:
              true,

          borderRadius:
              BorderRadius.circular(
            16,
          ),

          hint:
              const Row(
            children: [
              Icon(
                Icons.location_city,
                color:
                    _primaryOrange,
                size:
                    25,
              ),

              SizedBox(
                width: 12,
              ),

              Text(
                "All Municipalities",
                style:
                    TextStyle(
                  fontSize: 16,
                  color:
                      Colors.black87,
                ),
              ),
            ],
          ),

          icon:
              const Icon(
            Icons.keyboard_arrow_down_rounded,
            color:
                Colors.grey,
          ),

          items:
              _municipalities.map(
            (municipality) {
              return DropdownMenuItem<String>(
                value:
                    municipality,

                child:
                    Text(
                  municipality,
                  style:
                      const TextStyle(
                    fontSize: 16,
                  ),
                ),
              );
            },
          ).toList(),

          onChanged:
              _isLoading
                  ? null
                  : _onMunicipalityChanged,
        ),
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
            BorderRadius.circular(18),

        border:
            Border.all(
          color:
              Colors.grey.shade300,
        ),

        boxShadow:
            enabled
                ? [
                    BoxShadow(
                      color:
                          Colors.black
                              .withOpacity(
                        0.025,
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
                Icons.location_on,
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
                    : "Select Municipality First",

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
            BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.05,
            ),
            blurRadius:
                10,
            offset:
                const Offset(
              0,
              4,
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
            "Consumer Account Number",
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
                ? "Search a household within the selected location."
                : "Select municipality and barangay first.",

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

          Row(
            children: [
              Expanded(
                child:
                    TextField(
                  controller:
                      _accountNumberController,

                  enabled:
                      enabled &&
                      !_isLoading,

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
                            ? "Enter account number"
                            : "Select location first",

                    prefixIcon:
                        const Icon(
                      Icons.badge_outlined,
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
                        14,
                      ),
                      borderSide:
                          BorderSide(
                        color:
                            Colors.grey.shade300,
                      ),
                    ),

                    enabledBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                      borderSide:
                          BorderSide(
                        color:
                            Colors.grey.shade300,
                      ),
                    ),

                    focusedBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                      borderSide:
                          const BorderSide(
                        color:
                            _primaryOrange,
                        width:
                            2,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              SizedBox(
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
                        14,
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
            BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.04,
            ),
            blurRadius:
                10,
            offset:
                const Offset(
              0,
              4,
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
                  ? Icons.person_search
                  : Icons.location_searching,
              size:
                  36,
              color:
                  _primaryOrange,
            ),
          ),

          const SizedBox(
            height: 15,
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
                ? "Enter the consumer account number "
                  "above to continue."
                : "Choose a municipality and barangay "
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
            20,
          ),

          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(
                0.05,
              ),
              blurRadius:
                  10,
              offset:
                  const Offset(
                0,
                4,
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
                      12,
                    ),
                  ),

                  child:
                      const Icon(
                    Icons.person,
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
              height: 18,
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
                  12,
                ),
              ),

              child:
                  Row(
                children: [
                  const Icon(
                    Icons.speed,
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
        height: 22,
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
            20,
          ),

          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(
                0.04,
              ),
              blurRadius:
                  10,
              offset:
                  const Offset(
                0,
                4,
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
              Icons.speed,
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
                14,
              ),
              borderSide:
                  BorderSide(
                color:
                    Colors.grey.shade300,
              ),
            ),

            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              borderSide:
                  BorderSide(
                color:
                    Colors.grey.shade300,
              ),
            ),

            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              borderSide:
                  const BorderSide(
                color:
                    _primaryOrange,
                width:
                    2,
              ),
            ),
          ),
        ),
      ),

      const SizedBox(
        height: 22,
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
            20,
          ),

          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(
                0.05,
              ),
              blurRadius:
                  10,
              offset:
                  const Offset(
                0,
                4,
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
                      12,
                    ),
                  ),

                  child:
                      const Icon(
                    Icons.receipt_long,
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
              "Rate per kWh",
              "₱${_currentRate.toStringAsFixed(2)}",
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
              height: 15,
            ),

            const Divider(),

            const SizedBox(
              height: 15,
            ),

            // ==================================================
            // ESTIMATED BILL
            // ==================================================

            Container(
              width:
                  double.infinity,

              padding:
                  const EdgeInsets.all(
                16,
              ),

              decoration:
                  BoxDecoration(
                color:
                    _lightOrange,

                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
              ),

              child:
                  Row(
                children: [
                  const Icon(
                    Icons.payments_outlined,
                    color:
                        _primaryOrange,
                    size:
                        30,
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  const Expanded(
                    child:
                        Text(
                      "Estimated Bill",
                      style:
                          TextStyle(
                        fontSize:
                            16,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),

                  Text(
                    "₱${_computedAmount.toStringAsFixed(2)}",
                    style:
                        const TextStyle(
                      fontSize:
                          22,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          _darkOrange,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 18,
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
                  14,
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
                      "The meter reading will be reviewed "
                      "by the teller before the official bill "
                      "is generated.",
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

            SizedBox(
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
                      15,
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