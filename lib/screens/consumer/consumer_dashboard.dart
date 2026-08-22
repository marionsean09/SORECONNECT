import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:soreconnect/screens/consumer/consumer_bill_screen.dart';
import 'package:soreconnect/screens/consumer/consumer_report_screen.dart';
import 'package:soreconnect/screens/complaints/submit_complaint_screen.dart';
import 'package:soreconnect/screens/announcements/view_announcements_screen.dart';
import 'package:soreconnect/screens/auth/login_screen.dart';

class ConsumerDashboard extends StatefulWidget {
  const ConsumerDashboard({super.key});

  @override
  State<ConsumerDashboard> createState() => _ConsumerDashboardState();
}

class _ConsumerDashboardState extends State<ConsumerDashboard> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  // ================================================================
  // PROFILE CONTROLLERS
  // ================================================================

  final TextEditingController _fullNameController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _accountNumberController =
      TextEditingController();

  final TextEditingController _contactNumberController =
      TextEditingController();

  final TextEditingController _addressController =
      TextEditingController();

  bool _profileExpanded = false;
  bool _editingProfile = false;
  bool _savingProfile = false;

  bool _profileLoaded = false;

  // ================================================================
  // LOGOUT
  // ================================================================

  Future<void> _logout(BuildContext context) async {
    await _auth.signOut();

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
    }
  }

  // ================================================================
  // MONTH NAME
  // ================================================================

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

  // ================================================================
  // AMOUNT
  // ================================================================

  double _getAmount(Map<String, dynamic> data) {
    final value = data['totalAmount'];

    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  // ================================================================
  // PAID STATUS
  // ================================================================

  bool _isPaid(Map<String, dynamic> data) {
    final status =
        data['status']?.toString().toLowerCase().trim() ?? '';

    return status == 'paid';
  }

  // ================================================================
  // LOAD PROFILE
  // ================================================================

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final document = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!document.exists) {
        // Use Firebase Auth email as fallback.
        _fullNameController.text = '';
        _emailController.text = user.email ?? '';
        _accountNumberController.text = '';
        _contactNumberController.text = '';
        _addressController.text = '';

        if (mounted) {
          setState(() {
            _profileLoaded = true;
          });
        }

        return;
      }

      final data = document.data() ?? {};

      _fullNameController.text =
          data['full_name']?.toString() ?? '';

      _emailController.text =
          data['email']?.toString() ??
              user.email ??
              '';

      _accountNumberController.text =
          data['accountNumber']?.toString() ?? '';

      _contactNumberController.text =
          data['contactNumber']?.toString() ?? '';

      _addressController.text =
          data['address']?.toString() ?? '';

      if (mounted) {
        setState(() {
          _profileLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to load profile information.\n$e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ================================================================
  // SAVE PROFILE
  // ================================================================

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    // Basic validation
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

    if (_addressController.text.trim().isEmpty) {
      _showMessage(
        'Address is required.',
        Colors.red,
      );
      return;
    }

    setState(() {
      _savingProfile = true;
    });

    try {
      final newEmail =
          _emailController.text.trim();

      final oldEmail =
          user.email?.trim() ?? '';

      // ============================================================
      // UPDATE FIRESTORE PROFILE
      // ============================================================

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'full_name':
            _fullNameController.text.trim(),

        'email':
            newEmail,

        'accountNumber':
            _accountNumberController.text.trim(),

        'contactNumber':
            _contactNumberController.text.trim(),

        'address':
            _addressController.text.trim(),

        'uid':
            user.uid,

        'user_type':
            'consumer',
      });

      // ============================================================
      // UPDATE FIREBASE AUTH EMAIL
      // ============================================================
      //
      // Firebase may require recent authentication when
      // changing an email address.
      //
      // We only attempt this if the email was actually changed.
      // ============================================================

      if (newEmail.isNotEmpty &&
          newEmail != oldEmail) {
        try {
          await user.verifyBeforeUpdateEmail(
            newEmail,
          );
        } on FirebaseAuthException catch (e) {
          if (mounted) {
            setState(() {
              _savingProfile = false;
            });
          }

          _showMessage(
            e.message ??
                'Firebase requires recent authentication before changing the email.',
            Colors.red,
          );

          return;
        }
      }

      if (mounted) {
        setState(() {
          _editingProfile = false;
          _savingProfile = false;
        });
      }

      _showMessage(
        newEmail != oldEmail
            ? 'Profile saved. Please verify your new email address.'
            : 'Profile information updated successfully.',
        Colors.green,
      );
    } catch (e) {
      debugPrint('Error saving profile: $e');

      if (mounted) {
        setState(() {
          _savingProfile = false;
        });
      }

      _showMessage(
        'Unable to save profile information.\n$e',
        Colors.red,
      );
    }
  }

  // ================================================================
  // MESSAGE
  // ================================================================

  void _showMessage(
    String message,
    Color color,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ================================================================
  // PROFILE FIELD
  // ================================================================

  Widget _profileField({
    required String label,
    required String value,
    required IconData icon,
    TextEditingController? controller,
    bool enabled = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: enabled,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: value,
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF1B5E20),
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
                BorderRadius.circular(12),
            borderSide:
                BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
            borderSide:
                BorderSide(
              color: Colors.grey.shade200,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
            borderSide:
                const BorderSide(
              color: Color(0xFF1B5E20),
              width: 1.5,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
            borderSide:
                BorderSide(
              color: Colors.grey.shade200,
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // PROFILE DROPDOWN
  // ================================================================

  Widget _profileDropdown(User user) {
    if (!_profileLoaded) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF1B5E20),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration:
          const Duration(milliseconds: 250),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE1A533),
            Color(0xFFEAAA08),
          ],
        ),
        borderRadius:
            BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEAAA08)
                .withOpacity(0.20),
            blurRadius: 15,
            offset:
                const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          // ==========================================================
          // CLICKABLE HEADER
          // ==========================================================

          InkWell(
            borderRadius:
                BorderRadius.circular(20),
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
                        const EdgeInsets.all(12),
                    decoration:
                        BoxDecoration(
                      color: Colors.white
                          .withOpacity(0.16),
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                    child:
                        const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
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

                        const SizedBox(height: 4),

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

                  // ==================================================
                  // DROPDOWN ARROW
                  // ==================================================

                  AnimatedRotation(
                    turns:
                        _profileExpanded
                            ? 0.5
                            : 0,
                    duration:
                        const Duration(
                      milliseconds: 250,
                    ),
                    child:
                        const Icon(
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

          // ==========================================================
          // EXPANDED PROFILE
          // ==========================================================

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
                    const EdgeInsets.all(16),
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    17,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // =================================================
                    // PROFILE TITLE
                    // =================================================

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .account_circle_outlined,
                          color:
                              Color(0xFF1B5E20),
                          size: 22,
                        ),

                        const SizedBox(width: 8),

                        const Expanded(
                          child: Text(
                            'Personal Information',
                            style:
                                TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  Color(0xFF1B5E20),
                            ),
                          ),
                        ),

                        if (!_editingProfile)
                          IconButton(
                            tooltip:
                                'Edit Profile',
                            onPressed: () {
                              setState(() {
                                _editingProfile =
                                    true;
                              });
                            },
                            icon:
                                const Icon(
                              Icons.edit_outlined,
                              color:
                                  Color(0xFF1B5E20),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // =================================================
                    // FULL NAME
                    // =================================================

                    _profileField(
                      label: 'Full Name',
                      value:
                          _fullNameController.text,
                      controller:
                          _fullNameController,
                      icon:
                          Icons.person_outline,
                      enabled:
                          _editingProfile,
                    ),

                    // =================================================
                    // EMAIL
                    // =================================================

                    _profileField(
                      label: 'Email',
                      value:
                          _emailController.text,
                      controller:
                          _emailController,
                      icon:
                          Icons.email_outlined,
                      enabled:
                          _editingProfile,
                    ),

                    // =================================================
                    // ACCOUNT NUMBER
                    // =================================================

                    _profileField(
                      label:
                          'Account Number',
                      value:
                          _accountNumberController
                              .text,
                      controller:
                          _accountNumberController,
                      icon:
                          Icons
                              .confirmation_number_outlined,
                      enabled:
                          _editingProfile,
                    ),

                    // =================================================
                    // CONTACT NUMBER
                    // =================================================

                    _profileField(
                      label:
                          'Contact Number',
                      value:
                          _contactNumberController
                              .text,
                      controller:
                          _contactNumberController,
                      icon:
                          Icons.phone_outlined,
                      enabled:
                          _editingProfile,
                    ),

                    // =================================================
                    // ADDRESS
                    // =================================================

                    _profileField(
                      label: 'Address',
                      value:
                          _addressController.text,
                      controller:
                          _addressController,
                      icon:
                          Icons.home_outlined,
                      enabled:
                          _editingProfile,
                    ),

                    // =================================================
                    // USER TYPE
                    // =================================================

                    Container(
                      width:
                          double.infinity,
                      margin:
                          const EdgeInsets.only(
                        bottom: 12,
                      ),
                      padding:
                          const EdgeInsets.symmetric(
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
                            BorderRadius.circular(
                          12,
                        ),
                        border:
                            Border.all(
                          color:
                              Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons
                                .verified_user_outlined,
                            color:
                                Color(0xFF1B5E20),
                            size: 21,
                          ),

                          const SizedBox(
                            width: 12,
                          ),

                          const Text(
                            'Account Type',
                            style:
                                TextStyle(
                              fontSize: 12,
                              color:
                                  Colors.black54,
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
                              color:
                                  const Color(
                                0xFF1B5E20,
                              ).withOpacity(
                                0.10,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                20,
                              ),
                            ),
                            child:
                                const Text(
                              'CONSUMER',
                              style:
                                  TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    Color(
                                  0xFF1B5E20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // =================================================
                    // EDIT BUTTONS
                    // =================================================

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
                                            setState(() {
                                              _editingProfile =
                                                  false;
                                            });
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
                                  color:
                                      Colors.grey.shade400,
                                ),
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    12,
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
                                    const Color(
                                  0xFF1B5E20,
                                ),
                                foregroundColor:
                                    Colors.white,
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
                                    12,
                                  ),
                                ),
                              ),
                              child:
                                  _savingProfile
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth:
                                                2,
                                            color: Colors
                                                .white,
                                          ),
                                        )
                                      : const Text(
                                          'Save Changes',
                                          style:
                                              TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                            ),
                          ),
                        ],
                      ),

                    // =================================================
                    // UID INFORMATION
                    // =================================================

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
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            fontSize: 10,
                            color:
                                Colors.black38,
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

  // ================================================================
  // GET BILLS
  // ================================================================

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

  // ================================================================
  // GET COMPLAINTS
  // ================================================================

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

  // ================================================================
  // SUMMARY CARD
  // ================================================================

  Widget _summaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset:
                const Offset(0, 5),
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
                  color.withOpacity(0.10),
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 27,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        Colors.black54,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  value,
                  style:
                      TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.bold,
                    color: color,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  subtitle,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    color:
                        Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // MONTH SELECTOR
  // ================================================================

  Widget _monthSelector() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 3,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),
      child:
          DropdownButtonHideUnderline(
        child:
            DropdownButton<int>(
          value: selectedMonth,
          isExpanded: true,
          icon:
              const Icon(
            Icons.keyboard_arrow_down,
            color:
                Color(0xFF1B5E20),
          ),
          items:
              List.generate(
            12,
            (index) {
              final month =
                  index + 1;

              return DropdownMenuItem<int>(
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
          onChanged:
              (value) {
            if (value == null) {
              return;
            }

            setState(() {
              selectedMonth =
                  value;
            });
          },
        ),
      ),
    );
  }

  // ================================================================
  // SMALL AMOUNT
  // ================================================================

  Widget _smallAmount({
    required String title,
    required double amount,
    required Color color,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(13),
      decoration:
          BoxDecoration(
        color:
            color.withOpacity(0.07),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.w600,
              color: color,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            '₱${amount.toStringAsFixed(2)}',
            style:
                TextStyle(
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

  // ================================================================
  // MONTHLY BILLING HISTORY
  // ================================================================

  Widget _monthlyBillingHistory(
    List<Map<String, dynamic>> bills,
  ) {
    final Map<String, Map<String, double>>
        monthly = {};

    for (final bill in bills) {
      final billingPeriod =
          bill['billingPeriod']
                  ?.toString() ??
              '';

      if (billingPeriod.isEmpty) {
        continue;
      }

      final amount =
          _getAmount(bill);

      monthly.putIfAbsent(
        billingPeriod,
        () => {
          'paid': 0,
          'unpaid': 0,
        },
      );

      if (_isPaid(bill)) {
        monthly[billingPeriod]!['paid'] =
            (monthly[billingPeriod]![
                        'paid'] ??
                    0) +
                amount;
      } else {
        monthly[billingPeriod]!['unpaid'] =
            (monthly[billingPeriod]![
                        'unpaid'] ??
                    0) +
                amount;
      }
    }

    if (monthly.isEmpty) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(25),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(18),
        ),
        child:
            const Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 45,
              color: Colors.black26,
            ),
            SizedBox(height: 10),
            Text(
              'No billing history available.',
              style: TextStyle(
                color: Colors.black54,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final entries =
        monthly.entries.toList();

    entries.sort(
      (a, b) {
        final aParts =
            a.key.split(' ');
        final bParts =
            b.key.split(' ');

        final aYear =
            int.tryParse(
                  aParts.last,
                ) ??
                0;

        final bYear =
            int.tryParse(
                  bParts.last,
                ) ??
                0;

        if (aYear != bYear) {
          return bYear.compareTo(
            aYear,
          );
        }

        const months = {
          'January': 1,
          'February': 2,
          'March': 3,
          'April': 4,
          'May': 5,
          'June': 6,
          'July': 7,
          'August': 8,
          'September': 9,
          'October': 10,
          'November': 11,
          'December': 12,
        };

        final aMonth =
            months[aParts.first] ??
                0;

        final bMonth =
            months[bParts.first] ??
                0;

        return bMonth.compareTo(
          aMonth,
        );
      },
    );

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.05,
            ),
            blurRadius: 12,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Billing History',
            style:
                TextStyle(
              fontSize: 17,
              fontWeight:
                  FontWeight.bold,
              color:
                  Color(0xFF1B5E20),
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Paid and unpaid bills by billing period',
            style:
                TextStyle(
              fontSize: 12,
              color:
                  Colors.black54,
            ),
          ),

          const SizedBox(height: 16),

          ...entries.map(
            (entry) {
              final paid =
                  entry.value['paid'] ??
                      0;

              final unpaid =
                  entry.value['unpaid'] ??
                      0;

              return Container(
                margin:
                    const EdgeInsets.only(
                  bottom: 12,
                ),
                padding:
                    const EdgeInsets.all(
                  14,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFF8F9F8,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          size: 20,
                          color:
                              Color(0xFF1B5E20),
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        Expanded(
                          child:
                              Text(
                            entry.key,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child:
                              _smallAmount(
                            title:
                                'Paid',
                            amount:
                                paid,
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
                                'Unpaid',
                            amount:
                                unpaid,
                            color:
                                Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ================================================================
  // INIT
  // ================================================================

  @override
  void initState() {
    super.initState();

    _loadProfile();
  }

  // ================================================================
  // DISPOSE
  // ================================================================

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _accountNumberController.dispose();
    _contactNumberController.dispose();
    _addressController.dispose();

    super.dispose();
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final user =
        _auth.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F7F5),

      // ============================================================
      // APP BAR
      // ============================================================

      appBar: AppBar(
        title: const Text(
          'Consumer Dashboard',
          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        backgroundColor:
            Theme.of(context)
                .primaryColor,
        foregroundColor:
            Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon:
                const Icon(
              Icons.logout,
            ),
            onPressed:
                () => _logout(
              context,
            ),
          ),
        ],
      ),

      // ============================================================
      // BODY
      // ============================================================

      body: SafeArea(
        child:
            StreamBuilder<
                QuerySnapshot<
                    Map<String, dynamic>>>(
          stream:
              _getBills(
            user.uid,
          ),
          builder:
              (
            context,
            billSnapshot,
          ) {
            if (billSnapshot
                .hasError) {
              return Center(
                child:
                    Padding(
                  padding:
                      const EdgeInsets
                          .all(
                    25,
                  ),
                  child:
                      Text(
                    'Unable to load bills.\n\n'
                    '${billSnapshot.error}',
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      color:
                          Colors.red,
                    ),
                  ),
                ),
              );
            }

            if (billSnapshot
                    .connectionState ==
                ConnectionState
                    .waiting) {
              return const Center(
                child:
                    CircularProgressIndicator(),
              );
            }

            final bills =
                billSnapshot
                        .data
                        ?.docs
                        .map(
                          (doc) =>
                              doc.data(),
                        )
                        .toList() ??
                    [];

            // ======================================================
            // TOTALS
            // ======================================================

            double totalPaid = 0;
            double totalUnpaid = 0;

            double monthlyPaid = 0;
            double monthlyUnpaid = 0;

            final selectedPeriod =
                '${_monthName(selectedMonth)} '
                '$selectedYear';

            for (final bill
                in bills) {
              final amount =
                  _getAmount(
                bill,
              );

              final paid =
                  _isPaid(
                bill,
              );

              if (paid) {
                totalPaid +=
                    amount;
              } else {
                totalUnpaid +=
                    amount;
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
                }
              }
            }

            // ======================================================
            // COMPLAINTS
            // ======================================================

            return StreamBuilder<
                QuerySnapshot<
                    Map<String, dynamic>>>(
              stream:
                  _getComplaints(
                user.uid,
              ),
              builder:
                  (
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
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      // ==================================================
                      // CLICKABLE PROFILE DROPDOWN
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
                              FontWeight.bold,
                          color:
                              Color(0xFF1B5E20),
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      const Text(
                        'Overview of your electricity account',
                        style:
                            TextStyle(
                          fontSize: 12,
                          color:
                              Colors.black54,
                        ),
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      // ==================================================
                      // REMAINING DUE
                      // ==================================================

                      _summaryCard(
                        title:
                            'Remaining Due',
                        value:
                            '₱${totalUnpaid.toStringAsFixed(2)}',
                        subtitle:
                            'Total unpaid balance',
                        icon:
                            Icons.account_balance_wallet,
                        color:
                            Colors.red,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      // ==================================================
                      // TOTAL PAID
                      // ==================================================

                      _summaryCard(
                        title:
                            'Total Paid',
                        value:
                            '₱${totalPaid.toStringAsFixed(2)}',
                        subtitle:
                            'Total payments made',
                        icon:
                            Icons.check_circle_outline,
                        color:
                            Colors.green,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      // ==================================================
                      // COMPLAINTS
                      // ==================================================

                      _summaryCard(
                        title:
                            'My Complaints',
                        value:
                            complaintCount
                                .toString(),
                        subtitle:
                            'Total complaints submitted',
                        icon:
                            Icons.report_problem_outlined,
                        color:
                            const Color(
                          0xFFDAA520,
                        ),
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
                              FontWeight.bold,
                          color:
                              Color(0xFF1B5E20),
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      const Text(
                        'Filter your billing activity by month',
                        style:
                            TextStyle(
                          fontSize: 12,
                          color:
                              Colors.black54,
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
                      // SELECTED MONTH
                      // ==================================================

                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets
                                .all(
                          18,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              Colors.white,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            18,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors
                                  .black
                                  .withOpacity(
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
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              selectedPeriod,
                              style:
                                  const TextStyle(
                                fontSize:
                                    16,
                                fontWeight:
                                    FontWeight
                                        .bold,
                                color:
                                    Color(
                                  0xFF1B5E20,
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 14,
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
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 28,
                      ),

                      // ==================================================
                      // BILLING HISTORY
                      // ==================================================

                      _monthlyBillingHistory(
                        bills,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),

      // ============================================================
      // BOTTOM NAVIGATION
      // ============================================================

      bottomNavigationBar:
          BottomNavigationBar(
        type:
            BottomNavigationBarType.fixed,
        currentIndex: 0,
        selectedItemColor:
            const Color(0xFF1B5E20),
        unselectedItemColor:
            Colors.grey,
        onTap:
            (index) {
          final destinations = [
            const ConsumerDashboard(),
            const ConsumerBillScreen(),
            const ConsumerReportScreen(),
            const SubmitComplaintScreen(),
            const ViewAnnouncementsScreen(),
          ];

          if (index != 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) =>
                        destinations[index],
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon:
                Icon(
              Icons.home_outlined,
            ),
            activeIcon:
                Icon(
              Icons.home,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon:
                Icon(
              Icons.receipt_long_outlined,
            ),
            activeIcon:
                Icon(
              Icons.receipt_long,
            ),
            label: 'Bills',
          ),
          BottomNavigationBarItem(
            icon:
                Icon(
              Icons.pie_chart_outline,
            ),
            activeIcon:
                Icon(
              Icons.pie_chart,
            ),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon:
                Icon(
              Icons.report_problem_outlined,
            ),
            activeIcon:
                Icon(
              Icons.report_problem,
            ),
            label: 'Complaints',
          ),
          BottomNavigationBarItem(
            icon:
                Icon(
              Icons.campaign_outlined,
            ),
            activeIcon:
                Icon(
              Icons.campaign,
            ),
            label: 'News',
          ),
        ],
      ),
    );
  }
}