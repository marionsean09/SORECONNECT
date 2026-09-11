import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:soreconnect/data/sorsogon_address_data.dart';
import 'package:soreconnect/services/announcement_service.dart';

class PostAnnouncementScreen extends StatefulWidget {
  const PostAnnouncementScreen({super.key});

  @override
  State<PostAnnouncementScreen> createState() =>
      _PostAnnouncementScreenState();
}

class _PostAnnouncementScreenState
    extends State<PostAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();

  final AnnouncementService _announcementService =
      AnnouncementService();

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  // ============================================================
  // ANNOUNCEMENT TYPE
  // ============================================================

  String _selectedType = 'advisory';

  final List<Map<String, String>> _announcementTypes = [
    {
      'value': 'power_interruption',
      'label': 'Power Interruption',
    },
    {
      'value': 'disconnection',
      'label': 'Disconnection Notice',
    },
    {
      'value': 'meter_reading',
      'label': 'Meter Reading Schedule',
    },
    {
      'value': 'payment_reminder',
      'label': 'Payment Reminder',
    },
    {
      'value': 'advisory',
      'label': 'Advisory',
    },
    {
      'value': 'news',
      'label': 'News',
    },
    {
      'value': 'general',
      'label': 'General Announcement',
    },
  ];

  // ============================================================
  // COVERAGE
  // ============================================================

  String _coverageType = 'all';

  String? _selectedMunicipality;
  String? _selectedBarangay;

  List<String> get _municipalities {
    return getSorsogonSecondDistrictMunicipalities();
  }

  List<String> get _barangays {
    return getBarangaysForMunicipality(
      _selectedMunicipality,
    );
  }

  // ============================================================
  // POWER INTERRUPTION
  // ============================================================

  DateTime _selectedStartDate = DateTime.now();
  TimeOfDay _selectedStartTime = TimeOfDay.now();

  DateTime _selectedEndDate = DateTime.now();
  TimeOfDay _selectedEndTime = TimeOfDay.now();

  // ============================================================
  // DISCONNECTION
  // ============================================================

  DateTime _selectedDisconnectionDate = DateTime.now();
  TimeOfDay _selectedDisconnectionTime = TimeOfDay.now();

  // ============================================================
  // METER READING
  // ============================================================

  DateTime _selectedReadingDate = DateTime.now();

  // ============================================================
  // GENERAL STATE
  // ============================================================

  bool _isPosting = false;

  // ============================================================
  // HELPERS
  // ============================================================

  bool get _isPowerInterruption {
    return _selectedType == 'power_interruption';
  }

  bool get _isDisconnection {
    return _selectedType == 'disconnection';
  }

  bool get _isMeterReading {
    return _selectedType == 'meter_reading';
  }

  DateTime _combineDateAndTime(
    DateTime date,
    TimeOfDay time,
  ) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  String _getTypeLabel() {
    final type = _announcementTypes.firstWhere(
      (item) => item['value'] == _selectedType,
      orElse: () => {
        'value': '',
        'label': 'Announcement',
      },
    );

    return type['label'] ?? 'Announcement';
  }

  // ============================================================
  // COVERAGE VALIDATION
  // ============================================================

  bool _validateCoverage() {
    if (_coverageType == 'all') {
      return true;
    }

    if (_coverageType == 'municipality') {
      if (_selectedMunicipality == null ||
          _selectedMunicipality!.isEmpty) {
        _showError(
          'Please select a municipality.',
        );
        return false;
      }

      return true;
    }

    if (_coverageType == 'barangay') {
      if (_selectedMunicipality == null ||
          _selectedMunicipality!.isEmpty) {
        _showError(
          'Please select a municipality first.',
        );
        return false;
      }

      if (_selectedBarangay == null ||
          _selectedBarangay!.isEmpty) {
        _showError(
          'Please select a barangay.',
        );
        return false;
      }

      return true;
    }

    return true;
  }

  // ============================================================
  // SELECT COVERAGE TYPE
  // ============================================================

  void _changeCoverageType(String? value) {
    if (value == null) return;

    setState(() {
      _coverageType = value;

      if (value == 'all') {
        _selectedMunicipality = null;
        _selectedBarangay = null;
      }

      if (value == 'municipality') {
        _selectedBarangay = null;
      }
    });
  }

  // ============================================================
  // START DATE
  // ============================================================

  Future<void> _selectStartDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (pickedDate == null) return;

    setState(() {
      _selectedStartDate = pickedDate;

      if (_selectedEndDate.isBefore(pickedDate)) {
        _selectedEndDate = pickedDate;
      }
    });
  }

  // ============================================================
  // START TIME
  // ============================================================

  Future<void> _selectStartTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime,
    );

    if (pickedTime == null) return;

    setState(() {
      _selectedStartTime = pickedTime;
    });
  }

  // ============================================================
  // END DATE
  // ============================================================

  Future<void> _selectEndDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate.isBefore(
        _selectedStartDate,
      )
          ? _selectedStartDate
          : _selectedEndDate,
      firstDate: _selectedStartDate,
      lastDate: DateTime(2030),
    );

    if (pickedDate == null) return;

    setState(() {
      _selectedEndDate = pickedDate;
    });
  }

  // ============================================================
  // END TIME
  // ============================================================

  Future<void> _selectEndTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime,
    );

    if (pickedTime == null) return;

    setState(() {
      _selectedEndTime = pickedTime;
    });
  }

  // ============================================================
  // DISCONNECTION DATE
  // ============================================================

  Future<void> _selectDisconnectionDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDisconnectionDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (pickedDate == null) return;

    setState(() {
      _selectedDisconnectionDate = pickedDate;
    });
  }

  // ============================================================
  // DISCONNECTION TIME
  // ============================================================

  Future<void> _selectDisconnectionTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedDisconnectionTime,
    );

    if (pickedTime == null) return;

    setState(() {
      _selectedDisconnectionTime = pickedTime;
    });
  }

  // ============================================================
  // READING DATE
  // ============================================================

  Future<void> _selectReadingDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedReadingDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (pickedDate == null) return;

    setState(() {
      _selectedReadingDate = pickedDate;
    });
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ============================================================
  // DATE FIELD
  // ============================================================

  Widget _buildDateField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          suffixIcon: Icon(icon),
        ),
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // COVERAGE SECTION
  // ============================================================

  Widget _buildCoverageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.location_on_outlined,
          title: 'Covered Area',
        ),

        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          initialValue: _coverageType,
          decoration: InputDecoration(
            labelText: 'Coverage',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(
              Icons.public,
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: 'all',
              child: Text(
                'All Areas',
              ),
            ),
            DropdownMenuItem(
              value: 'municipality',
              child: Text(
                'Municipality',
              ),
            ),
            DropdownMenuItem(
              value: 'barangay',
              child: Text(
                'Barangay',
              ),
            ),
          ],
          onChanged: _changeCoverageType,
        ),

        if (_coverageType != 'all') ...[
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            initialValue: _selectedMunicipality,
            decoration: InputDecoration(
              labelText: 'Municipality',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(
                Icons.location_city,
              ),
            ),
            items: _municipalities.map(
              (municipality) {
                return DropdownMenuItem<String>(
                  value: municipality,
                  child: Text(
                    municipality,
                  ),
                );
              },
            ).toList(),
            onChanged: (value) {
              setState(() {
                _selectedMunicipality = value;
                _selectedBarangay = null;
              });
            },
          ),
        ],

        if (_coverageType == 'barangay') ...[
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            initialValue: _selectedBarangay,
            decoration: InputDecoration(
              labelText: 'Barangay',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(
                Icons.home_work_outlined,
              ),
            ),
            items: _barangays.map(
              (barangay) {
                return DropdownMenuItem<String>(
                  value: barangay,
                  child: Text(
                    barangay,
                  ),
                );
              },
            ).toList(),
            onChanged: _selectedMunicipality == null
                ? null
                : (value) {
                    setState(() {
                      _selectedBarangay = value;
                    });
                  },
          ),
        ],

        const SizedBox(height: 12),

        _buildCoveragePreview(),
      ],
    );
  }

  // ============================================================
  // COVERAGE PREVIEW
  // ============================================================

  Widget _buildCoveragePreview() {
    String coverageText;

    if (_coverageType == 'all') {
      coverageText =
          'All areas within the Sorsogon 2nd District';
    } else if (_coverageType == 'municipality') {
      if (_selectedMunicipality == null) {
        coverageText =
            'Select a municipality';
      } else {
        coverageText =
            '$_selectedMunicipality, Sorsogon';
      }
    } else {
      if (_selectedMunicipality == null) {
        coverageText =
            'Select a municipality and barangay';
      } else if (_selectedBarangay == null) {
        coverageText =
            'Select a barangay';
      } else {
        coverageText = buildSorsogonAddress(
          municipality: _selectedMunicipality!,
          barangay: _selectedBarangay!,
        );
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .primaryColor
            .withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context)
              .primaryColor
              .withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.place,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Announcement will apply to:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  coverageText,
                  style: TextStyle(
                    color:
                        Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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
  // POWER INTERRUPTION SECTION
  // ============================================================

  Widget _buildPowerInterruptionSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.power_off,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Power Interruption Schedule',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildDateField(
            label: 'Starting Date',
            value: DateFormat(
              'MMMM dd, yyyy',
            ).format(_selectedStartDate),
            icon: Icons.calendar_today,
            onTap: _selectStartDate,
          ),

          const SizedBox(height: 16),

          _buildDateField(
            label: 'Starting Time',
            value: _selectedStartTime.format(context),
            icon: Icons.access_time,
            onTap: _selectStartTime,
          ),

          const SizedBox(height: 16),

          _buildDateField(
            label: 'Ending Date',
            value: DateFormat(
              'MMMM dd, yyyy',
            ).format(_selectedEndDate),
            icon: Icons.event_available,
            onTap: _selectEndDate,
          ),

          const SizedBox(height: 16),

          _buildDateField(
            label: 'Ending Time',
            value: _selectedEndTime.format(context),
            icon: Icons.access_time_filled,
            onTap: _selectEndTime,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISCONNECTION SECTION
  // ============================================================

  Widget _buildDisconnectionSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.power_settings_new,
                color: Colors.red,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Disconnection Schedule',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildDateField(
            label: 'Disconnection Date',
            value: DateFormat(
              'MMMM dd, yyyy',
            ).format(_selectedDisconnectionDate),
            icon: Icons.calendar_month,
            onTap: _selectDisconnectionDate,
          ),

          const SizedBox(height: 16),

          _buildDateField(
            label: 'Disconnection Time',
            value: _selectedDisconnectionTime.format(
              context,
            ),
            icon: Icons.access_time,
            onTap: _selectDisconnectionTime,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // METER READING SECTION
  // ============================================================

  Widget _buildMeterReadingSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.speed,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Meter Reading Schedule',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildDateField(
            label: 'Reading Date',
            value: DateFormat(
              'MMMM dd, yyyy',
            ).format(_selectedReadingDate),
            icon: Icons.calendar_today,
            onTap: _selectReadingDate,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // POST ANNOUNCEMENT
  // ============================================================

  Future<void> _postAnnouncement() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_validateCoverage()) {
      return;
    }

    // ==========================================================
    // POWER INTERRUPTION VALIDATION
    // ==========================================================

    DateTime? scheduledDateTime;
    DateTime? scheduledEndDateTime;

    if (_isPowerInterruption) {
      scheduledDateTime = _combineDateAndTime(
        _selectedStartDate,
        _selectedStartTime,
      );

      scheduledEndDateTime = _combineDateAndTime(
        _selectedEndDate,
        _selectedEndTime,
      );

      if (!scheduledEndDateTime.isAfter(
        scheduledDateTime,
      )) {
        _showError(
          'The ending time must be later than the starting time.',
        );
        return;
      }
    }

    // ==========================================================
    // DISCONNECTION DATE/TIME
    // ==========================================================

    DateTime? disconnectionDateTime;

    if (_isDisconnection) {
      disconnectionDateTime = _combineDateAndTime(
        _selectedDisconnectionDate,
        _selectedDisconnectionTime,
      );
    }

    // ==========================================================
    // METER READING DATE
    // ==========================================================

    DateTime? readingDate;

    if (_isMeterReading) {
      readingDate = DateTime(
        _selectedReadingDate.year,
        _selectedReadingDate.month,
        _selectedReadingDate.day,
      );
    }

    setState(() {
      _isPosting = true;
    });

    try {
      // ========================================================
      // COVERAGE DATA
      // ========================================================

      String? municipality;
      String? barangay;
      String? coveredArea;

      if (_coverageType == 'all') {
        municipality = null;
        barangay = null;
        coveredArea =
            'All areas within the Sorsogon 2nd District';
      } else if (_coverageType == 'municipality') {
        municipality = _selectedMunicipality;
        barangay = null;

        coveredArea =
            '$_selectedMunicipality, Sorsogon';
      } else {
        municipality = _selectedMunicipality;
        barangay = _selectedBarangay;

        if (municipality != null &&
            barangay != null) {
          coveredArea = buildSorsogonAddress(
            municipality: municipality,
            barangay: barangay,
          );
        }
      }

      // ========================================================
      // FIRESTORE DATA
      // ========================================================

      final Map<String, dynamic> announcementData = {
        // ------------------------------------------------------
        // BASIC ANNOUNCEMENT INFORMATION
        // ------------------------------------------------------

        'title': _titleController.text.trim(),

        'content': _contentController.text.trim(),

        'type': _selectedType,

        'typeLabel': _getTypeLabel(),

        'postedBy':
            FirebaseAuth.instance.currentUser?.uid,

        'datePosted':
            FieldValue.serverTimestamp(),

        // ------------------------------------------------------
        // COVERAGE
        // ------------------------------------------------------

        'coverageType': _coverageType,

        'municipality': municipality,

        'barangay': barangay,

        'province': sorsogonProvince,

        'district': sorsogonSecondDistrict,

        'coveredArea': coveredArea,

        // ------------------------------------------------------
        // POWER INTERRUPTION
        // ------------------------------------------------------

        'scheduledDate':
            scheduledDateTime != null
                ? Timestamp.fromDate(
                    scheduledDateTime,
                  )
                : null,

        'scheduledEndDate':
            scheduledEndDateTime != null
                ? Timestamp.fromDate(
                    scheduledEndDateTime,
                  )
                : null,

        'startTime':
            scheduledDateTime != null
                ? DateFormat(
                    'hh:mm a',
                  ).format(scheduledDateTime)
                : null,

        'endTime':
            scheduledEndDateTime != null
                ? DateFormat(
                    'hh:mm a',
                  ).format(
                    scheduledEndDateTime,
                  )
                : null,

        // ------------------------------------------------------
        // DISCONNECTION
        // ------------------------------------------------------

        'disconnectionDate':
            disconnectionDateTime != null
                ? Timestamp.fromDate(
                    disconnectionDateTime,
                  )
                : null,

        'disconnectionTime':
            disconnectionDateTime != null
                ? DateFormat(
                    'hh:mm a',
                  ).format(
                    disconnectionDateTime,
                  )
                : null,

        // ------------------------------------------------------
        // METER READING
        // ------------------------------------------------------

        'readingDate':
            readingDate != null
                ? Timestamp.fromDate(
                    readingDate,
                  )
                : null,

        // ------------------------------------------------------
        // STATUS
        // ------------------------------------------------------

        'status': 'active',
      };

      // ========================================================
      // SAVE THROUGH ANNOUNCEMENT SERVICE
      // ========================================================

      await _announcementService.postAnnouncement(
        title: announcementData['title'] as String,
        content: announcementData['content'] as String,
        type: announcementData['type'] as String,
        typeLabel:
            announcementData['typeLabel'] as String,
        postedBy:
            announcementData['postedBy'] as String?,
        coverageType:
            announcementData['coverageType'] as String,
        municipality:
            announcementData['municipality'] as String?,
        barangay:
            announcementData['barangay'] as String?,
        province:
            announcementData['province'] as String,
        district:
            announcementData['district'] as String,
        coveredArea:
            announcementData['coveredArea'] as String?,
        scheduledDate:
            scheduledDateTime,
        scheduledEndDate:
            scheduledEndDateTime,
        startTime:
            announcementData['startTime'] as String?,
        endTime:
            announcementData['endTime'] as String?,
        disconnectionDate:
            disconnectionDateTime,
        disconnectionTime:
            announcementData['disconnectionTime']
                as String?,
        readingDate:
            readingDate,
        status:
            announcementData['status'] as String,
      );

      // ========================================================
      // RESET FORM
      // ========================================================

      _titleController.clear();
      _contentController.clear();

      setState(() {
        _selectedType = 'advisory';

        _coverageType = 'all';

        _selectedMunicipality = null;
        _selectedBarangay = null;

        _selectedStartDate =
            DateTime.now();

        _selectedStartTime =
            TimeOfDay.now();

        _selectedEndDate =
            DateTime.now();

        _selectedEndTime =
            TimeOfDay.now();

        _selectedDisconnectionDate =
            DateTime.now();

        _selectedDisconnectionTime =
            TimeOfDay.now();

        _selectedReadingDate =
            DateTime.now();
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Announcement posted successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Error posting announcement: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bool isPower =
        _selectedType ==
            'power_interruption';

    final bool isDisconnection =
        _selectedType ==
            'disconnection';

    final bool isMeterReading =
        _selectedType ==
            'meter_reading';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Post Announcement',
        ),
        backgroundColor:
            Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Form(
          key: _formKey,

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              // ==================================================
              // ANNOUNCEMENT TYPE
              // ==================================================

              DropdownButtonFormField<String>(
                initialValue: _selectedType,

                decoration: InputDecoration(
                  labelText:
                      'Announcement Type',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  prefixIcon: const Icon(
                    Icons.category_outlined,
                  ),
                ),

                items:
                    _announcementTypes
                        .map(
                  (type) {
                    return DropdownMenuItem<
                        String>(
                      value:
                          type['value'],
                      child: Text(
                        type['label']!,
                      ),
                    );
                  },
                ).toList(),

                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedType =
                        value;
                  });
                },
              ),

              const SizedBox(height: 16),

              // ==================================================
              // TITLE
              // ==================================================

              TextFormField(
                controller:
                    _titleController,

                decoration:
                    InputDecoration(
                  labelText: 'Title',
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),
                  prefixIcon:
                      const Icon(
                    Icons.title,
                  ),
                ),

                validator: (value) {
                  if (value == null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Enter announcement title';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ==================================================
              // CONTENT
              // ==================================================

              TextFormField(
                controller:
                    _contentController,

                maxLines: 5,

                decoration:
                    InputDecoration(
                  labelText: 'Content',
                  alignLabelWithHint:
                      true,

                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),

                  prefixIcon:
                      const Padding(
                    padding:
                        EdgeInsets.only(
                      bottom: 70,
                    ),
                    child: Icon(
                      Icons
                          .description_outlined,
                    ),
                  ),
                ),

                validator: (value) {
                  if (value == null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Enter announcement content';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 28),

              // ==================================================
              // COVERED AREA
              // ==================================================

              _buildCoverageSection(),

              const SizedBox(height: 28),

              // ==================================================
              // POWER INTERRUPTION
              // ==================================================

              if (isPower)
                _buildPowerInterruptionSection(),

              // ==================================================
              // DISCONNECTION
              // ==================================================

              if (isDisconnection)
                _buildDisconnectionSection(),

              // ==================================================
              // METER READING
              // ==================================================

              if (isMeterReading)
                _buildMeterReadingSection(),

              const SizedBox(height: 28),

              // ==================================================
              // POST BUTTON
              // ==================================================

              SizedBox(
                width: double.infinity,
                height: 52,

                child:
                    ElevatedButton(
                  onPressed: _isPosting
                      ? null
                      : _postAnnouncement,

                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        Theme.of(
                      context,
                    ).primaryColor,

                    foregroundColor:
                        Colors.white,

                    elevation: 0,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                  ),

                  child: _isPosting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child:
                              CircularProgressIndicator(
                            color:
                                Colors.white,
                            strokeWidth:
                                2,
                          ),
                        )
                      : const Text(
                          'POST ANNOUNCEMENT',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
