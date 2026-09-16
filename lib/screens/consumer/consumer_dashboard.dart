import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:soreconnect/data/sorsogon_address_data.dart';

import 'package:soreconnect/screens/consumer/consumer_bill_screen.dart';
import 'package:soreconnect/screens/complaints/submit_complaint_screen.dart';
import 'package:soreconnect/screens/announcements/view_announcements_screen.dart';
import 'package:soreconnect/screens/auth/login_screen.dart';
import 'package:soreconnect/screens/auth/verify_email_screen.dart';

class ConsumerDashboard extends StatefulWidget {
  const ConsumerDashboard({super.key});

  @override
  State<ConsumerDashboard> createState() => _ConsumerDashboardState();
}

class _ConsumerDashboardState extends State<ConsumerDashboard> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  // ============================================================
  // THEME COLORS
  // ============================================================

  static const orange = Color(0xFFFFA000);
  static const background = Color(0xFFF5F7F5);

  // ============================================================
  // PROFILE CONTROLLERS
  // ============================================================

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _contactNumberController = TextEditingController();

  // ============================================================
  // ADDRESS
  // ============================================================

  String? _selectedMunicipality;
  String? _selectedBarangay;

  // ============================================================
  // PROFILE STATE
  // ============================================================

  bool _profileExpanded = false;
  bool _editingProfile = false;
  bool _savingProfile = false;
  bool _profileLoaded = false;
  bool _saveButtonPressed = false;

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    await _auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (_) => false,
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _monthName(int month) {
    const months = [
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

    return months[month - 1];
  }

  double _getAmount(Map<String, dynamic> data) {
    final value = data['totalAmount'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  bool _isPaid(Map<String, dynamic> data) {
    return data['status']
            ?.toString()
            .toLowerCase()
            .trim() ==
        'paid';
  }

  bool _isCancelled(Map<String, dynamic> data) {
    final status = data['status']
        ?.toString()
        .toLowerCase()
        .trim();

    return status == 'cancelled' || status == 'canceled';
  }

  DateTime? _getDueDate(Map<String, dynamic> data) {
    final value = data['dueDate'];

    if (value is Timestamp) return value.toDate();

    return null;
  }

  DateTime? _getPaymentStartDate(Map<String, dynamic> data) {
    final value = data['paymentStartDate'];

    if (value is Timestamp) return value.toDate();

    return null;
  }

  void _showMessage(
    String message,
    Color color,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // ADDRESS HELPERS
  // ============================================================

  List<String> get _municipalities {
    return getSorsogonSecondDistrictMunicipalities();
  }

  List<String> get _barangays {
    return getBarangaysForMunicipality(
      _selectedMunicipality,
    );
  }

  // ============================================================
  // BUILD COMPLETE ADDRESS
  // ============================================================

  String _buildAddress() {
    if (_selectedMunicipality == null ||
        _selectedBarangay == null) {
      return '';
    }

    return buildSorsogonAddress(
      municipality: _selectedMunicipality!,
      barangay: _selectedBarangay!,
    );
  }

  // ============================================================
  // LOAD PROFILE
  // ============================================================

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;

    if (user == null) return;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};

      _fullNameController.text =
          data['full_name']?.toString() ?? '';

      // Firebase Auth's email is the source of truth for the
      // actual sign-in email — Firestore's copy is only a cache
      // and can briefly lag behind right after an email change.
      _emailController.text =
          user.email?.trim().isNotEmpty == true
              ? user.email!
              : (data['email']?.toString() ?? '');

      _accountNumberController.text =
          data['accountNumber']?.toString() ?? '';

      _contactNumberController.text =
          data['contactNumber']?.toString() ?? '';

      // ========================================================
      // LOAD MUNICIPALITY
      // ========================================================

      String? municipality =
          data['municipality']?.toString();

      if (municipality != null &&
          !_municipalities.contains(municipality)) {
        municipality = null;
      }

      // ========================================================
      // LOAD BARANGAY
      // ========================================================

      String? barangay =
          data['barangay']?.toString();

      if (municipality != null) {
        final availableBarangays =
            getBarangaysForMunicipality(
          municipality,
        );

        if (!availableBarangays.contains(barangay)) {
          barangay = null;
        }
      } else {
        barangay = null;
      }

      // ========================================================
      // FALLBACK:
      // TRY TO READ OLD ADDRESS FIELD
      // ========================================================

      if (municipality == null ||
          barangay == null) {
        final oldAddress =
            data['address']?.toString() ?? '';

        _parseOldAddress(oldAddress);

        municipality ??= _selectedMunicipality;

        barangay ??= _selectedBarangay;
      }

      if (mounted) {
        setState(() {
          _selectedMunicipality = municipality;
          _selectedBarangay = barangay;
          _profileLoaded = true;
        });
      }
    } catch (e) {
      debugPrint(
        'Error loading profile: $e',
      );

      if (!mounted) return;

      setState(() {
        _profileLoaded = true;
      });

      _showMessage(
        'Unable to load profile information.',
        Colors.red,
      );
    }
  }

  // ============================================================
  // PARSE OLD ADDRESS
  // ============================================================

  void _parseOldAddress(String address) {
    if (address.trim().isEmpty) {
      return;
    }

    final parts = address
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.length < 2) {
      return;
    }

    final possibleBarangay = parts[0];
    final possibleMunicipality = parts[1];

    if (_municipalities.contains(
      possibleMunicipality,
    )) {
      final barangays =
          getBarangaysForMunicipality(
        possibleMunicipality,
      );

      if (barangays.contains(
        possibleBarangay,
      )) {
        _selectedMunicipality =
            possibleMunicipality;

        _selectedBarangay =
            possibleBarangay;
      }
    }
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;

    if (user == null) return;

    // ========================================================
    // BASIC VALIDATION
    // ========================================================

    if (_fullNameController.text.trim().isEmpty) {
      _showMessage(
        'Full name is required.',
        Colors.red,
      );
      return;
    }

    if (_accountNumberController.text.trim().isEmpty) {
      _showMessage(
        'Account number is required.',
        Colors.red,
      );
      return;
    }

    if (_contactNumberController.text.trim().isEmpty) {
      _showMessage(
        'Contact number is required.',
        Colors.red,
      );
      return;
    }

    // ========================================================
    // ADDRESS VALIDATION
    // ========================================================

    if (_selectedMunicipality == null) {
      _showMessage(
        'Please select your municipality.',
        Colors.red,
      );
      return;
    }

    if (_selectedBarangay == null) {
      _showMessage(
        'Please select your barangay.',
        Colors.red,
      );
      return;
    }

    if (!isValidSorsogonSecondDistrictMunicipality(
      _selectedMunicipality!,
    )) {
      _showMessage(
        'Selected municipality is not part of Sorsogon 2nd District.',
        Colors.red,
      );
      return;
    }

    if (!isValidBarangayForMunicipality(
      municipality: _selectedMunicipality!,
      barangay: _selectedBarangay!,
    )) {
      _showMessage(
        'Selected barangay does not belong to the selected municipality.',
        Colors.red,
      );
      return;
    }

    final address = _buildAddress();

    if (address.isEmpty) {
      _showMessage(
        'Please complete your address.',
        Colors.red,
      );
      return;
    }

    final newEmail = _emailController.text.trim();

    if (newEmail.isEmpty) {
      _showMessage(
        'Email is required.',
        Colors.red,
      );
      return;
    }

    if (!newEmail.contains('@')) {
      _showMessage(
        'Enter a valid email address.',
        Colors.red,
      );
      return;
    }

    final currentAuthEmail = user.email ?? '';

    final emailChanged =
        newEmail.toLowerCase() !=
            currentAuthEmail.toLowerCase();

    setState(() {
      _savingProfile = true;
    });

    // ==========================================================
    // UPDATE SIGN-IN EMAIL (IF CHANGED)
    //
    // Firebase sends a confirmation link to the NEW address —
    // the sign-in email only actually changes once the user taps
    // it, so Firestore keeps the CURRENT (still-valid) email
    // until then.
    // ==========================================================

    if (emailChanged) {
      try {
        await user.verifyBeforeUpdateEmail(newEmail);
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;

        setState(() {
          _savingProfile = false;
        });

        String message;

        switch (e.code) {
          case 'requires-recent-login':
            message =
                'Please log out and log back in before '
                'changing your email.';
            break;
          case 'email-already-in-use':
            message =
                'That email is already used by another account.';
            break;
          case 'invalid-email':
            message = 'Enter a valid email address.';
            break;
          default:
            message =
                e.message ?? 'Unable to update email.';
        }

        _showMessage(message, Colors.red);
        return;
      }

      // Keep the field showing the still-current email until the
      // consumer confirms the change via the link.
      _emailController.text = currentAuthEmail;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'full_name':
              _fullNameController.text.trim(),

          'email': currentAuthEmail,

          'accountNumber':
              _accountNumberController.text.trim(),

          'contactNumber':
              _contactNumberController.text.trim(),

          // ==================================================
          // NEW STRUCTURED ADDRESS
          // ==================================================

          'province': sorsogonProvince,

          'district': sorsogonSecondDistrict,

          'municipality':
              _selectedMunicipality,

          'barangay':
              _selectedBarangay,

          // ==================================================
          // COMPLETE READABLE ADDRESS
          // ==================================================

          'address': address,

          'uid': user.uid,

          'user_type': 'consumer',

          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _editingProfile = false;
        _savingProfile = false;
      });

      if (emailChanged) {
        _showMessage(
          'Profile updated. Confirm your new email to finish '
          'the change.',
          Colors.green,
        );

        // Once the consumer confirms the new email on that screen,
        // it syncs Firestore itself, signs out, and sends them to
        // Login — this only returns here if they back out without
        // confirming.
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                VerifyEmailScreen(pendingEmail: newEmail),
          ),
        );

        await _loadProfile();
      } else {
        _showMessage(
          'Profile updated successfully.',
          Colors.green,
        );
      }
    } catch (e) {
      debugPrint(
        'Error saving profile: $e',
      );

      if (!mounted) return;

      setState(() {
        _savingProfile = false;
      });

      _showMessage(
        'Unable to update profile information.',
        Colors.red,
      );
    }
  }

  // ============================================================
  // PROFILE FIELD
  // ============================================================

  Widget _profileField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool enabled = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: orange,
            size: 21,
          ),
          filled: true,
          fillColor: enabled
              ? Colors.white
              : const Color(0xFFF5F7F5),
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),
          disabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),
          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(16),
            borderSide:
                const BorderSide(
              color: orange,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ADDRESS DROPDOWN FIELD
  // ============================================================

  Widget _addressDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
    bool enabled = true,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      decoration: BoxDecoration(
        color: enabled
            ? Colors.white
            : const Color(0xFFF5F7F5),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: orange,
          ),
          hint: Row(
            children: [
              Icon(
                icon,
                color: orange,
                size: 21,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          selectedItemBuilder:
              (context) {
            return items.map(
              (item) {
                return Row(
                  children: [
                    Icon(
                      icon,
                      color: orange,
                      size: 21,
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child: Text(
                        item,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 14,
                          fontWeight:
                              FontWeight.w500,
                          color:
                              Colors.black87,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ).toList();
          },
          items: items.map(
            (item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style:
                      const TextStyle(
                    fontSize: 14,
                  ),
                ),
              );
            },
          ).toList(),
          onChanged:
              enabled ? onChanged : null,
        ),
      ),
    );
  }

  // ============================================================
  // ADDRESS SECTION
  // ============================================================

  Widget _addressSection() {
    final address =
        _buildAddress();

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        // ======================================================
        // MUNICIPALITY
        // ======================================================

        _addressDropdown(
          label: 'Select Municipality',
          icon: Icons.location_city_outlined,
          value: _selectedMunicipality,
          items: _municipalities,
          enabled: _editingProfile,
          onChanged: (value) {
            setState(() {
              _selectedMunicipality = value;

              // Reset barangay whenever
              // municipality changes.
              _selectedBarangay = null;
            });
          },
        ),

        // ======================================================
        // BARANGAY
        // ======================================================

        _addressDropdown(
          label: _selectedMunicipality == null
              ? 'Select municipality first'
              : 'Select Barangay',
          icon: Icons.location_on_outlined,
          value: _selectedBarangay,
          items: _barangays,
          enabled:
              _editingProfile &&
              _selectedMunicipality != null,
          onChanged: (value) {
            setState(() {
              _selectedBarangay = value;
            });
          },
        ),

        // ======================================================
        // ADDRESS PREVIEW
        // ======================================================

        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(
            bottom: 12,
          ),
          padding:
              const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7F5),
            borderRadius:
                BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.home_outlined,
                color: orange,
                size: 21,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete Address',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address.isNotEmpty
                          ? address
                          : 'Select municipality and barangay',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w500,
                        color: address.isNotEmpty
                            ? Colors.black87
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PROFILE DROPDOWN
  // ============================================================

  Widget _profileDropdown(User user) {
    if (!_profileLoaded) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(
          20,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(24),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: orange,
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration:
          const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: double.infinity,
      decoration: BoxDecoration(
        color: orange,
        borderRadius:
            BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: .12,
            ),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color:
                orange.withValues(alpha: .25),
            blurRadius: 15,
            offset:
                const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          // ======================================================
          // PROFILE HEADER
          // ======================================================

          InkWell(
            borderRadius:
                BorderRadius.circular(24),
            onTap: () {
              setState(() {
                _profileExpanded =
                    !_profileExpanded;

                if (!_profileExpanded) {
                  _editingProfile = false;
                }
              });
            },
            child: Padding(
              padding:
                  const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.white
                          .withValues(alpha: .18),
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(
                    width: 14,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          _fullNameController
                                  .text
                                  .trim()
                                  .isNotEmpty
                              ? _fullNameController
                                  .text
                                  .trim()
                              : 'Consumer',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          _accountNumberController
                                  .text
                                  .trim()
                                  .isNotEmpty
                              ? 'Account No. ${_accountNumberController.text.trim()}'
                              : 'CONSUMER ACCOUNT',
                          style:
                              const TextStyle(
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w600,
                            color:
                                Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns:
                        _profileExpanded
                            ? .5
                            : 0,
                    duration:
                        const Duration(
                      milliseconds: 250,
                    ),
                    child: const Icon(
                      Icons
                          .keyboard_arrow_down,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ======================================================
          // PROFILE DETAILS
          // ======================================================

          if (_profileExpanded)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.fromLTRB(
                18,
                4,
                18,
                18,
              ),
              child: Container(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    // ==================================================
                    // HEADER
                    // ==================================================

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .account_circle_outlined,
                          color: Colors.black87,
                          size: 22,
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        const Expanded(
                          child: Text(
                            'Personal Information',
                            style:
                                TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight
                                      .bold,
                              color:
                                  Colors.black87,
                            ),
                          ),
                        ),
                        if (!_editingProfile)
                          IconButton(
                            tooltip:
                                'Edit Profile',
                            splashRadius: 20,
                            onPressed: () {
                              setState(
                                () =>
                                    _editingProfile =
                                        true,
                              );
                            },
                            icon:
                                const Icon(
                              Icons
                                  .edit_outlined,
                              color:
                                  Colors.black87,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    // ==================================================
                    // EMAIL
                    // ==================================================

                    _profileField(
                      label: 'Email',
                      icon:
                          Icons.email_outlined,
                      controller:
                          _emailController,
                      enabled:
                          _editingProfile,
                      keyboardType:
                          TextInputType.emailAddress,
                    ),

                    // ==================================================
                    // FULL NAME
                    // ==================================================

                    _profileField(
                      label: 'Full Name',
                      icon:
                          Icons.person_outline,
                      controller:
                          _fullNameController,
                      enabled:
                          _editingProfile,
                    ),

                    // ==================================================
                    // ACCOUNT NUMBER
                    // ==================================================

                    _profileField(
                      label: 'Account Number',
                      icon: Icons
                          .confirmation_number_outlined,
                      controller:
                          _accountNumberController,
                      enabled:
                          _editingProfile,
                    ),

                    // ==================================================
                    // CONTACT NUMBER
                    // ==================================================

                    _profileField(
                      label: 'Contact Number',
                      icon:
                          Icons.phone_outlined,
                      controller:
                          _contactNumberController,
                      enabled:
                          _editingProfile,
                      keyboardType:
                          TextInputType.phone,
                    ),

                    // ==================================================
                    // ADDRESS
                    // ==================================================

                    const SizedBox(
                      height: 2,
                    ),

                    Text(
                      'Address',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    // MUNICIPALITY + BARANGAY
                    _addressSection(),

                    // ==================================================
                    // ACCOUNT TYPE
                    // ==================================================

                    Container(
                      width: double.infinity,
                      margin:
                          const EdgeInsets.only(
                        bottom: 12,
                      ),
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFF5F7F5,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          16,
                        ),
                        border: Border.all(
                          color: Colors
                              .grey
                              .shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons
                                .verified_user_outlined,
                            color: Color(
                              0xFF03C70D,
                            ),
                            size: 21,
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Text(
                            'Account Type',
                            style:
                                TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  FontWeight
                                      .w500,
                              color: Colors
                                  .grey
                                  .shade600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration:
                                BoxDecoration(
                              color: orange
                                  .withValues(
                                alpha: .12,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                16,
                              ),
                            ),
                            child:
                                const Text(
                              'CONSUMER',
                              style:
                                  TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight
                                        .bold,
                                color:
                                    orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ==================================================
                    // SAVE / CANCEL
                    // ==================================================

                    if (_editingProfile)
                      Row(
                        children: [
                          Expanded(
                            child:
                                OutlinedButton(
                              onPressed:
                                  _savingProfile
                                      ? null
                                      : () async {
                                          await _loadProfile();

                                          if (mounted) {
                                            setState(
                                              () =>
                                                  _editingProfile =
                                                      false,
                                            );
                                          }
                                        },
                              style:
                                  OutlinedButton
                                      .styleFrom(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  vertical: 13,
                                ),
                                side:
                                    BorderSide(
                                  color: Colors
                                      .grey
                                      .shade400,
                                ),
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    16,
                                  ),
                                ),
                              ),
                              child:
                                  const Text(
                                'Cancel',
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Listener(
                              onPointerDown: (_) {
                                if (!_savingProfile) {
                                  setState(
                                    () =>
                                        _saveButtonPressed =
                                            true,
                                  );
                                }
                              },
                              onPointerUp: (_) =>
                                  setState(
                                () =>
                                    _saveButtonPressed =
                                        false,
                              ),
                              onPointerCancel: (_) =>
                                  setState(
                                () =>
                                    _saveButtonPressed =
                                        false,
                              ),
                              child: AnimatedScale(
                                scale:
                                    _saveButtonPressed
                                        ? 0.97
                                        : 1.0,
                                duration:
                                    const Duration(
                                  milliseconds: 120,
                                ),
                                curve:
                                    Curves.easeOut,
                                child:
                                    ElevatedButton(
                              onPressed:
                                  _savingProfile
                                      ? null
                                      : _saveProfile,
                              style:
                                  ElevatedButton
                                      .styleFrom(
                                backgroundColor:
                                    orange,
                                foregroundColor:
                                    Colors.white,
                                elevation: 0,
                                shadowColor:
                                    Colors
                                        .transparent,
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  vertical: 13,
                                ),
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    16,
                                  ),
                                ),
                              ),
                              child:
                                  _savingProfile
                                      ? const SizedBox(
                                          height:
                                              20,
                                          width:
                                              20,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth:
                                                2,
                                            color:
                                                Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Save Changes',
                                          style:
                                              TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                            letterSpacing:
                                                0.3,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                    // ==================================================
                    // FIREBASE UID
                    // ==================================================

                    if (!_editingProfile)
                      Padding(
                        padding:
                            const EdgeInsets.only(
                          top: 5,
                        ),
                        child: Text(
                          'Firebase UID: ${user.uid}',
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              TextStyle(
                            fontSize: 10,
                            color:
                                Colors.grey.shade400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // FIRESTORE STREAMS
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> _getBills(
    String consumerId,
  ) {
    return _firestore
        .collection('bills')
        .where(
          'consumerId',
          isEqualTo: consumerId,
        )
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getComplaints(
    String consumerId,
  ) {
    return _firestore
        .collection('complaints')
        .where(
          'consumerId',
          isEqualTo: consumerId,
        )
        .snapshots();
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget _summaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: .05),
            blurRadius: 16,
            offset:
                const Offset(0, 6),
          ),
          BoxShadow(
            color:
                color.withValues(alpha: .10),
            blurRadius: 24,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration:
                BoxDecoration(
              color:
                  color.withValues(alpha: .10),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 27,
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        Colors.grey.shade600,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  subtitle,
                  style:
                      TextStyle(
                    fontSize: 11,
                    color:
                        Colors.grey.shade500,
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
  // MONTH SELECTOR
  // ============================================================

  Widget _monthSelector() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child:
          DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedMonth,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: orange,
          ),
          items: List.generate(
            12,
            (index) {
              final month = index + 1;

              return DropdownMenuItem(
                value: month,
                child: Text(
                  '${_monthName(month)} $selectedYear',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              );
            },
          ),
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              selectedMonth = value;
            });
          },
        ),
      ),
    );
  }

  // ============================================================
  // SMALL AMOUNT
  // ============================================================

  Widget _smallAmount({
    required String title,
    required double amount,
    required Color color,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: .07),
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            '₱${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _accountNumberController.dispose();
    _contactNumberController.dispose();

    super.dispose();
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _openScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    return Scaffold(
      backgroundColor: background,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          'Consumer Dashboard',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        backgroundColor: orange,
        foregroundColor:
            Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon:
                const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SafeArea(
        child: StreamBuilder<
            QuerySnapshot<
                Map<String, dynamic>>>(
          stream: _getBills(
            user.uid,
          ),
          builder:
              (context, billSnapshot) {
            if (billSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding:
                      const EdgeInsets
                          .all(25),
                  child: Text(
                    'Unable to load bills.\n\n'
                    '${billSnapshot.error}',
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ),
              );
            }

            if (billSnapshot
                    .connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child:
                    CircularProgressIndicator(
                  color: orange,
                ),
              );
            }

            final bills =
                billSnapshot.data?.docs
                        .map(
                          (doc) =>
                              doc.data(),
                        )
                        .toList() ??
                    [];

            // ==================================================
            // ACCOUNT TOTALS
            // ==================================================

            double totalPaid = 0;
            double totalUnpaid = 0;

            // ==================================================
            // MONTHLY TOTALS
            // ==================================================

            double monthlyPaid = 0;
            double monthlyUnpaid = 0;
            DateTime? monthlyDueDate;
            DateTime? monthlyPaymentStart;

            final selectedPeriod =
                '${_monthName(selectedMonth)} $selectedYear';

            for (final bill in bills) {
              // Cancelled bills are excluded from every total —
              // they are void and nothing is owed on them.
              if (_isCancelled(bill)) {
                continue;
              }

              final amount =
                  _getAmount(bill);

              final paid =
                  _isPaid(bill);

              if (paid) {
                totalPaid += amount;
              } else {
                totalUnpaid += amount;
              }

              final period =
                  bill['billingPeriod']
                          ?.toString()
                          .trim() ??
                      '';

              if (period ==
                  selectedPeriod) {
                if (paid) {
                  monthlyPaid +=
                      amount;
                } else {
                  monthlyUnpaid +=
                      amount;

                  final dueDate =
                      _getDueDate(bill);

                  if (dueDate != null &&
                      (monthlyDueDate == null ||
                          dueDate.isBefore(
                            monthlyDueDate,
                          ))) {
                    monthlyDueDate = dueDate;
                    monthlyPaymentStart =
                        _getPaymentStartDate(bill);
                  }
                }
              }
            }

            return StreamBuilder<
                QuerySnapshot<
                    Map<String,
                        dynamic>>>(
              stream:
                  _getComplaints(
                user.uid,
              ),
              builder: (
                context,
                complaintSnapshot,
              ) {
                final complaintCount =
                    complaintSnapshot
                            .data
                            ?.docs
                            .length ??
                        0;

                return SingleChildScrollView(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    20,
                    20,
                    20,
                    30,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      // ==================================================
                      // PROFILE
                      // ==================================================

                      _profileDropdown(
                        user,
                      ),

                      const SizedBox(
                        height: 25,
                      ),

                      // ==================================================
                      // ACCOUNT SUMMARY
                      // ==================================================

                      const Text(
                        'Account Summary',
                        style:
                            TextStyle(
                          fontSize: 19,
                          fontWeight:
                              FontWeight
                                  .bold,
                          color:
                              Colors.black87,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        'Overview of your electricity account',
                        style:
                            TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w500,
                          color:
                              Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      _summaryCard(
                        title:
                            'Remaining Due',
                        value:
                            '₱${totalUnpaid.toStringAsFixed(2)}',
                        subtitle:
                            'Total unpaid balance',
                        icon: Icons
                            .account_balance_wallet,
                        color:
                            Colors.red,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      _summaryCard(
                        title:
                            'Total Paid',
                        value:
                            '₱${totalPaid.toStringAsFixed(2)}',
                        subtitle:
                            'Total payments made',
                        icon: Icons
                            .check_circle_outline,
                        color:
                            Colors.green,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      _summaryCard(
                        title:
                            'My Complaints',
                        value:
                            complaintCount
                                .toString(),
                        subtitle:
                            'Total complaints submitted',
                        icon: Icons
                            .report_problem_outlined,
                        color: orange,
                      ),

                      const SizedBox(
                        height: 28,
                      ),

                      // ==================================================
                      // MONTHLY SUMMARY
                      // ==================================================

                      const Text(
                        'Monthly Summary',
                        style:
                            TextStyle(
                          fontSize: 19,
                          fontWeight:
                              FontWeight
                                  .bold,
                          color:
                              Colors.black87,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        'View your billing summary for a selected month',
                        style:
                            TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w500,
                          color:
                              Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      _monthSelector(),

                      const SizedBox(
                        height: 15,
                      ),

                      // ==================================================
                      // MONTHLY CARD
                      // ==================================================

                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets
                                .all(18),
                        decoration:
                            BoxDecoration(
                          color:
                              Colors.white,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            24,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors
                                  .black
                                  .withValues(
                                alpha: .05,
                              ),
                              blurRadius:
                                  16,
                              offset:
                                  const Offset(
                                0,
                                6,
                              ),
                            ),
                            BoxShadow(
                              color: orange
                                  .withValues(
                                alpha: .08,
                              ),
                              blurRadius:
                                  24,
                              offset:
                                  const Offset(
                                0,
                                10,
                              ),
                            ),
                          ],
                        ),
                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        orange.withValues(
                                      alpha: .12,
                                    ),
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      16,
                                    ),
                                  ),
                                  child:
                                      const Icon(
                                    Icons
                                        .calendar_month_outlined,
                                    color:
                                        orange,
                                    size:
                                        23,
                                  ),
                                ),
                                const SizedBox(
                                  width: 12,
                                ),
                                Expanded(
                                  child:
                                      Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Text(
                                        'Billing Period',
                                        style:
                                            TextStyle(
                                          fontSize:
                                              11,
                                          color:
                                              Colors.grey.shade600,
                                          fontWeight:
                                              FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(
                                        height:
                                            3,
                                      ),
                                      Text(
                                        selectedPeriod,
                                        style:
                                            const TextStyle(
                                          fontSize:
                                              16,
                                          fontWeight:
                                              FontWeight.bold,
                                          color:
                                              orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child:
                                      _smallAmount(
                                    title:
                                        'Paid This Month',
                                    amount:
                                        monthlyPaid,
                                    color:
                                        Colors.green,
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Expanded(
                                  child:
                                      _smallAmount(
                                    title:
                                        'Unpaid This Month',
                                    amount:
                                        monthlyUnpaid,
                                    color:
                                        Colors.red,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 14,
                            ),

                            Container(
                              width:
                                  double.infinity,
                              padding:
                                  const EdgeInsets
                                      .all(
                                14,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    orange.withValues(
                                  alpha: .07,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  16,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons
                                        .account_balance_wallet_outlined,
                                    color:
                                        orange,
                                    size:
                                        22,
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  Expanded(
                                    child:
                                        Text(
                                      'Monthly Total',
                                      style:
                                          TextStyle(
                                        fontSize:
                                            12,
                                        fontWeight:
                                            FontWeight.w600,
                                        color:
                                            Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '₱${(monthlyPaid + monthlyUnpaid).toStringAsFixed(2)}',
                                    style:
                                        const TextStyle(
                                      fontSize:
                                          17,
                                      fontWeight:
                                          FontWeight.bold,
                                      color:
                                          orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (monthlyUnpaid >
                                0) ...[
                              const SizedBox(
                                height: 14,
                              ),

                              Container(
                                width:
                                    double.infinity,
                                padding:
                                    const EdgeInsets
                                        .all(
                                  14,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color: Colors
                                      .red
                                      .withValues(
                                    alpha: .07,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    16,
                                  ),
                                ),
                                child:
                                    Row(
                                  children: [
                                    const Icon(
                                      Icons
                                          .payments_outlined,
                                      color:
                                          Colors.red,
                                      size:
                                          22,
                                    ),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    Expanded(
                                      child:
                                          Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Text(
                                            'Amount Due',
                                            style:
                                                TextStyle(
                                              fontSize:
                                                  12,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color:
                                                  Colors.grey.shade600,
                                            ),
                                          ),
                                          if (monthlyPaymentStart !=
                                              null) ...[
                                            const SizedBox(
                                              height:
                                                  2,
                                            ),
                                            Text(
                                              'Payable from '
                                              '${DateFormat('MMM dd, yyyy').format(monthlyPaymentStart)}',
                                              style:
                                                  TextStyle(
                                                fontSize:
                                                    11,
                                                color:
                                                    Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                          if (monthlyDueDate !=
                                              null) ...[
                                            const SizedBox(
                                              height:
                                                  2,
                                            ),
                                            Text(
                                              'Due '
                                              '${DateFormat('MMM dd, yyyy').format(monthlyDueDate)}',
                                              style:
                                                  TextStyle(
                                                fontSize:
                                                    11,
                                                color:
                                                    Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₱${monthlyUnpaid.toStringAsFixed(2)}',
                                      style:
                                          const TextStyle(
                                        fontSize:
                                            17,
                                        fontWeight:
                                            FontWeight.bold,
                                        color:
                                            Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            if (monthlyPaid ==
                                    0 &&
                                monthlyUnpaid ==
                                    0)
                              Padding(
                                padding:
                                    const EdgeInsets
                                        .only(
                                  top: 14,
                                ),
                                child:
                                    Container(
                                  width:
                                      double.infinity,
                                  padding:
                                      const EdgeInsets
                                          .all(
                                    13,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        const Color(
                                      0xFFF8F8F8,
                                    ),
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      16,
                                    ),
                                  ),
                                  child:
                                      Row(
                                    children: [
                                      Icon(
                                        Icons
                                            .info_outline,
                                        color:
                                            Colors.grey.shade500,
                                        size:
                                            20,
                                      ),
                                      const SizedBox(
                                        width:
                                            9,
                                      ),
                                      Expanded(
                                        child:
                                            Text(
                                          'No billing records found for this month.',
                                          style:
                                              TextStyle(
                                            fontSize:
                                                11,
                                            fontWeight:
                                                FontWeight.w500,
                                            color:
                                                Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),

      // ========================================================
      // BOTTOM NAVIGATION
      // ========================================================

      bottomNavigationBar:
          BottomNavigationBar(
        type:
            BottomNavigationBarType.fixed,
        currentIndex: 0,
        selectedItemColor:
            orange,
        unselectedItemColor:
            Colors.grey,
        onTap: (index) {
          if (index == 0) {
            return;
          }

          switch (index) {
            case 1:
              _openScreen(
                const ConsumerBillScreen(),
              );
              break;

            case 2:
              _openScreen(
                const SubmitComplaintScreen(),
              );
              break;

            case 3:
              _openScreen(
                const ViewAnnouncementsScreen(),
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon:
                Icon(Icons.home_outlined),
            activeIcon:
                Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.receipt_long_outlined,
            ),
            activeIcon: Icon(
              Icons.receipt_long,
            ),
            label: 'Bills',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.report_problem_outlined,
            ),
            activeIcon: Icon(
              Icons.report_problem,
            ),
            label: 'Complaints',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.campaign_outlined,
            ),
            activeIcon: Icon(
              Icons.campaign,
            ),
            label: 'News',
          ),
        ],
      ),
    );
  }
}