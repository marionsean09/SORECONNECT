import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:soreconnect/data/sorsogon_address_data.dart';
import 'package:soreconnect/services/announcement_service.dart';

class PostAnnouncementScreen extends StatefulWidget {
  const PostAnnouncementScreen({
    super.key,
    this.editAnnouncementId,
    this.editData,
  });

  // When both are set, this screen edits an existing announcement
  // instead of creating a new one.
  final String? editAnnouncementId;
  final Map<String, dynamic>? editData;

  bool get isEditing => editAnnouncementId != null && editData != null;

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

  List<String> _selectedMunicipalities = [];
  List<String> _selectedBarangays = [];

  List<String> get _municipalities {
    return getSorsogonSecondDistrictMunicipalities();
  }

  List<String> get _barangays {
    final barangaySet = <String>{};

    for (final municipality in _selectedMunicipalities) {
      barangaySet.addAll(
        getBarangaysForMunicipality(municipality),
      );
    }

    final barangayList = barangaySet.toList();
    barangayList.sort();

    return barangayList;
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
  // PHOTO
  // ============================================================

  final ImagePicker _imagePicker = ImagePicker();
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;

  // When editing, the announcement's current photo (if any), shown
  // until the director picks a new one or removes it.
  String? _existingImageBase64;
  bool _imageExplicitlyRemoved = false;

  // ============================================================
  // GENERAL STATE
  // ============================================================

  bool _isPosting = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    if (widget.isEditing) {
      _prefillFromEditData(widget.editData!);
    }
  }

  void _prefillFromEditData(Map<String, dynamic> data) {
    _titleController.text = (data['title'] ?? '').toString();
    _contentController.text = (data['content'] ?? '').toString();

    _selectedType = (data['type'] ?? 'advisory').toString();

    _coverageType = (data['coverageType'] ?? 'all').toString();

    _selectedMunicipalities = List<String>.from(
      (data['municipalities'] as List?)?.map((e) => e.toString()) ?? [],
    );

    _selectedBarangays = List<String>.from(
      (data['barangays'] as List?)?.map((e) => e.toString()) ?? [],
    );

    final scheduledDate = data['scheduledDate'];
    if (scheduledDate is Timestamp) {
      final dt = scheduledDate.toDate();
      _selectedStartDate = dt;
      _selectedStartTime = TimeOfDay.fromDateTime(dt);
    }

    final scheduledEndDate = data['scheduledEndDate'];
    if (scheduledEndDate is Timestamp) {
      final dt = scheduledEndDate.toDate();
      _selectedEndDate = dt;
      _selectedEndTime = TimeOfDay.fromDateTime(dt);
    }

    final disconnectionDate = data['disconnectionDate'];
    if (disconnectionDate is Timestamp) {
      final dt = disconnectionDate.toDate();
      _selectedDisconnectionDate = dt;
      _selectedDisconnectionTime = TimeOfDay.fromDateTime(dt);
    }

    final readingDate = data['readingDate'];
    if (readingDate is Timestamp) {
      _selectedReadingDate = readingDate.toDate();
    }

    final imageBase64 = data['imageBase64'];
    if (imageBase64 is String && imageBase64.isNotEmpty) {
      _existingImageBase64 = imageBase64;
    }
  }

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
      if (_selectedMunicipalities.isEmpty) {
        _showError(
          'Please select at least one municipality.',
        );
        return false;
      }

      return true;
    }

    if (_coverageType == 'barangay') {
      if (_selectedMunicipalities.isEmpty) {
        _showError(
          'Please select at least one municipality first.',
        );
        return false;
      }

      if (_selectedBarangays.isEmpty) {
        _showError(
          'Please select at least one barangay.',
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
        _selectedMunicipalities = [];
        _selectedBarangays = [];
      }

      if (value == 'municipality') {
        _selectedBarangays = [];
      }
    });
  }

  // ============================================================
  // MULTI-SELECT PICKER
  // ============================================================

  Future<List<String>> _showMultiSelectDialog({
    required String title,
    required List<String> options,
    required List<String> initiallySelected,
  }) async {
    final selected = Set<String>.from(initiallySelected);
    final searchController = TextEditingController();
    List<String> filtered = List<String>.from(options);

    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        isDense: true,
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          filtered = options
                              .where(
                                (o) => o
                                    .toLowerCase()
                                    .contains(value.toLowerCase()),
                              )
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 320,
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('No matches found.'),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final option = filtered[index];
                                final isSelected =
                                    selected.contains(option);

                                return CheckboxListTile(
                                  value: isSelected,
                                  dense: true,
                                  title: Text(option),
                                  onChanged: (checked) {
                                    setDialogState(() {
                                      if (checked == true) {
                                        selected.add(option);
                                      } else {
                                        selected.remove(option);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(selected.toList()),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );

    searchController.dispose();

    return result ?? initiallySelected;
  }

  Future<void> _pickMunicipalities() async {
    final result = await _showMultiSelectDialog(
      title: 'Select Municipalities',
      options: _municipalities,
      initiallySelected: _selectedMunicipalities,
    );

    setState(() {
      _selectedMunicipalities = result;

      final validBarangays = _barangays.toSet();

      _selectedBarangays = _selectedBarangays
          .where(validBarangays.contains)
          .toList();
    });
  }

  Future<void> _pickBarangays() async {
    if (_selectedMunicipalities.isEmpty) {
      _showError('Please select a municipality first.');
      return;
    }

    final result = await _showMultiSelectDialog(
      title: 'Select Barangays',
      options: _barangays,
      initiallySelected: _selectedBarangays,
    );

    setState(() {
      _selectedBarangays = result;
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
  // PHOTO PICKER
  // ============================================================

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 60,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        _pickedImage = image;
        _pickedImageBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text("Failed to pick image: $e"),
        ),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _pickedImage = null;
      _pickedImageBytes = null;

      if (_existingImageBase64 != null) {
        _existingImageBase64 = null;
        _imageExplicitlyRemoved = true;
      }
    });
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text("Take a photo"),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text("Choose from gallery"),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
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
  // MULTI-SELECT FIELD
  // ============================================================

  Widget _buildMultiSelectField({
    required String label,
    required IconData icon,
    required List<String> selectedValues,
    required VoidCallback onTap,
    required String emptyHint,
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
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: selectedValues.isEmpty
            ? Text(
                emptyHint,
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              )
            : Wrap(
                spacing: 6,
                runSpacing: 6,
                children: selectedValues.map((value) {
                  return Chip(
                    label: Text(
                      value,
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
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
  // PHOTO SECTION
  // ============================================================

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.image_outlined,
          title: 'Photo (optional)',
        ),

        const SizedBox(height: 12),

        if (_pickedImageBytes != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  _pickedImageBytes!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: _removeImage,
                  child: const CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.black54,
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          )
        else if (_existingImageBase64 != null &&
            _existingImageBase64!.isNotEmpty)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  base64Decode(_existingImageBase64!),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: _removeImage,
                  child: const CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.black54,
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          InkWell(
            onTap: _showImageSourceSheet,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              height: 90,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Add Image",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
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

          _buildMultiSelectField(
            label: 'Municipalities',
            icon: Icons.location_city,
            selectedValues: _selectedMunicipalities,
            emptyHint: 'Tap to select municipalities',
            onTap: _pickMunicipalities,
          ),
        ],

        if (_coverageType == 'barangay') ...[
          const SizedBox(height: 16),

          _buildMultiSelectField(
            label: 'Barangays',
            icon: Icons.home_work_outlined,
            selectedValues: _selectedBarangays,
            emptyHint: _selectedMunicipalities.isEmpty
                ? 'Select a municipality first'
                : 'Tap to select barangays',
            onTap: _pickBarangays,
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

  String _buildBarangayCoverageText() {
    if (_selectedMunicipalities.length == 1) {
      return '${_selectedBarangays.join(', ')}, '
          '${_selectedMunicipalities.first}, Sorsogon';
    }

    return '${_selectedBarangays.join(', ')} '
        '(${_selectedMunicipalities.join(', ')}), Sorsogon';
  }

  Widget _buildCoveragePreview() {
    String coverageText;

    if (_coverageType == 'all') {
      coverageText =
          'All areas within the Sorsogon 2nd District';
    } else if (_coverageType == 'municipality') {
      if (_selectedMunicipalities.isEmpty) {
        coverageText =
            'Select at least one municipality';
      } else {
        coverageText =
            '${_selectedMunicipalities.join(', ')}, Sorsogon';
      }
    } else {
      if (_selectedMunicipalities.isEmpty) {
        coverageText =
            'Select at least one municipality and barangay';
      } else if (_selectedBarangays.isEmpty) {
        coverageText =
            'Select at least one barangay';
      } else {
        coverageText = _buildBarangayCoverageText();
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

      List<String> municipalities = [];
      List<String> barangays = [];
      String? coveredArea;

      if (_coverageType == 'all') {
        coveredArea =
            'All areas within the Sorsogon 2nd District';
      } else if (_coverageType == 'municipality') {
        municipalities = _selectedMunicipalities;

        coveredArea =
            '${_selectedMunicipalities.join(', ')}, Sorsogon';
      } else {
        municipalities = _selectedMunicipalities;
        barangays = _selectedBarangays;

        coveredArea = _buildBarangayCoverageText();
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

        'municipalities': municipalities,

        'barangays': barangays,

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

      if (widget.isEditing) {
        await _announcementService.updateAnnouncement(
          announcementId: widget.editAnnouncementId!,
          title: announcementData['title'] as String,
          content: announcementData['content'] as String,
          type: announcementData['type'] as String,
          typeLabel: announcementData['typeLabel'] as String,
          coverageType: announcementData['coverageType'] as String,
          municipalities:
              announcementData['municipalities'] as List<String>,
          barangays: announcementData['barangays'] as List<String>,
          province: announcementData['province'] as String,
          district: announcementData['district'] as String,
          coveredArea: announcementData['coveredArea'] as String?,
          scheduledDate: scheduledDateTime,
          scheduledEndDate: scheduledEndDateTime,
          startTime: announcementData['startTime'] as String?,
          endTime: announcementData['endTime'] as String?,
          disconnectionDate: disconnectionDateTime,
          disconnectionTime:
              announcementData['disconnectionTime'] as String?,
          readingDate: readingDate,
          image: _pickedImage,
          removeImage: _imageExplicitlyRemoved,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pop(true);
        return;
      }

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
        municipalities:
            announcementData['municipalities'] as List<String>,
        barangays:
            announcementData['barangays'] as List<String>,
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
        image: _pickedImage,
      );

      // ========================================================
      // RESET FORM
      // ========================================================

      _titleController.clear();
      _contentController.clear();

      setState(() {
        _pickedImage = null;
        _pickedImageBytes = null;
        _selectedType = 'advisory';

        _coverageType = 'all';

        _selectedMunicipalities = [];
        _selectedBarangays = [];

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
            widget.isEditing
                ? 'Error updating announcement: $e'
                : 'Error posting announcement: $e',
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
        title: Text(
          widget.isEditing
              ? 'Edit Announcement'
              : 'Post Announcement',
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
              // PHOTO
              // ==================================================

              _buildPhotoSection(),

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
                      : Text(
                          widget.isEditing
                              ? 'UPDATE ANNOUNCEMENT'
                              : 'POST ANNOUNCEMENT',
                          style:
                              const TextStyle(
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
