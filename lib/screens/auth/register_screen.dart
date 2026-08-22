import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:soreconnect/data/sorsogon_address_data.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ============================================================
  // TEXT CONTROLLERS
  // ============================================================

  final TextEditingController _fullNameController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final TextEditingController _accountNumberController =
      TextEditingController();

  final TextEditingController _contactNumberController =
      TextEditingController();

  // ============================================================
  // ADDRESS SELECTION
  // ============================================================

  String? _selectedMunicipality;
  String? _selectedBarangay;

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _errorMessage;

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _accountNumberController.dispose();
    _contactNumberController.dispose();

    super.dispose();
  }

  // ============================================================
  // GET BARANGAYS FOR SELECTED MUNICIPALITY
  // ============================================================

  List<String> get _availableBarangays {
    if (_selectedMunicipality == null) {
      return [];
    }

    return getBarangaysForMunicipality(
      _selectedMunicipality,
    );
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<void> _register() async {
    // ------------------------------------------------------------
    // VALIDATE FULL NAME
    // ------------------------------------------------------------

    if (_fullNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = "Enter full name";
      });
      return;
    }

    // ------------------------------------------------------------
    // VALIDATE EMAIL
    // ------------------------------------------------------------

    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = "Enter email";
      });
      return;
    }

    if (!_emailController.text.trim().contains('@')) {
      setState(() {
        _errorMessage = "Enter a valid email";
      });
      return;
    }

    // ------------------------------------------------------------
    // VALIDATE ACCOUNT NUMBER
    // ------------------------------------------------------------

    if (_accountNumberController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = "Enter account number";
      });
      return;
    }

    // ------------------------------------------------------------
    // VALIDATE CONTACT NUMBER
    // ------------------------------------------------------------

    if (_contactNumberController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = "Enter contact number";
      });
      return;
    }

    // ------------------------------------------------------------
    // VALIDATE MUNICIPALITY
    // ------------------------------------------------------------

    if (_selectedMunicipality == null ||
        _selectedMunicipality!.isEmpty) {
      setState(() {
        _errorMessage = "Select your municipality";
      });
      return;
    }

    // ------------------------------------------------------------
    // VALIDATE BARANGAY
    // ------------------------------------------------------------

    if (_selectedBarangay == null ||
        _selectedBarangay!.isEmpty) {
      setState(() {
        _errorMessage = "Select your barangay";
      });
      return;
    }

    // ------------------------------------------------------------
    // VALIDATE PASSWORD
    // ------------------------------------------------------------

    if (_passwordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = "Enter password";
      });
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() {
        _errorMessage = "Password must be at least 6 characters";
      });
      return;
    }

    // ------------------------------------------------------------
    // VALIDATE CONFIRM PASSWORD
    // ------------------------------------------------------------

    if (_passwordController.text !=
        _confirmPasswordController.text) {
      setState(() {
        _errorMessage = "Passwords don't match";
      });
      return;
    }

    // ------------------------------------------------------------
    // START LOADING
    // ------------------------------------------------------------

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ==========================================================
      // STEP 1
      // CREATE FIREBASE AUTH ACCOUNT
      // ==========================================================

      final UserCredential userCredential =
          await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception(
          'Unable to create Firebase user.',
        );
      }

      debugPrint(
        "✅ User created: ${user.uid}",
      );

      // ==========================================================
      // BUILD COMPLETE ADDRESS
      // ==========================================================

      final String completeAddress =
          buildSorsogonAddress(
        municipality: _selectedMunicipality!,
        barangay: _selectedBarangay!,
      );

      // ==========================================================
      // STEP 2
      // CREATE FIRESTORE USER DOCUMENT
      // ==========================================================

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        // --------------------------------------------------------
        // USER IDENTIFICATION
        // --------------------------------------------------------

        'uid': user.uid,

        'full_name':
            _fullNameController.text.trim(),

        'email':
            _emailController.text.trim(),

        'user_type':
            'consumer',

        // --------------------------------------------------------
        // ACCOUNT INFORMATION
        // --------------------------------------------------------

        'accountNumber':
            _accountNumberController.text.trim(),

        'contactNumber':
            _contactNumberController.text.trim(),

        // --------------------------------------------------------
        // ADDRESS INFORMATION
        // --------------------------------------------------------

        'province':
            sorsogonProvince,

        'district':
            sorsogonSecondDistrict,

        'municipality':
            _selectedMunicipality,

        'barangay':
            _selectedBarangay,

        // Complete readable address
        'address':
            completeAddress,

        // --------------------------------------------------------
        // CREATED DATE
        // --------------------------------------------------------

        'created_at':
            DateTime.now().toIso8601String(),
      });

      debugPrint(
        "✅ Firestore document created",
      );

      debugPrint(
        "Province: $sorsogonProvince",
      );

      debugPrint(
        "District: $sorsogonSecondDistrict",
      );

      debugPrint(
        "Municipality: $_selectedMunicipality",
      );

      debugPrint(
        "Barangay: $_selectedBarangay",
      );

      debugPrint(
        "Address: $completeAddress",
      );

      // ==========================================================
      // SUCCESS
      // ==========================================================

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Registration successful! Please login.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(
        "❌ Auth Error: ${e.code}",
      );

      if (!mounted) return;

      if (e.code == 'email-already-in-use') {
        setState(() {
          _errorMessage =
              'Email already registered';
        });
      } else if (e.code == 'weak-password') {
        setState(() {
          _errorMessage =
              'Password is too weak';
        });
      } else if (e.code == 'invalid-email') {
        setState(() {
          _errorMessage =
              'Invalid email address';
        });
      } else {
        setState(() {
          _errorMessage =
              e.message ?? 'Registration failed';
        });
      }
    } catch (e) {
      debugPrint(
        "❌ Other Error: $e",
      );

      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Registration failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // TEXT FIELD DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: const Color(0xFFD50000),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFD50000),
          width: 2,
        ),
      ),
    );
  }

  // ============================================================
  // ADDRESS DROPDOWN
  // ============================================================

  Widget _addressDropdowns() {
    return Column(
      children: [
        // ========================================================
        // PROVINCE
        // ========================================================

        DropdownButtonFormField<String>(
          value: sorsogonProvince,
          decoration: _inputDecoration(
            label: 'Province',
            icon: Icons.location_on,
          ),
          items: [
            DropdownMenuItem<String>(
              value: sorsogonProvince,
              child: Text(
                sorsogonProvince,
              ),
            ),
          ],
          onChanged: null,
        ),

        const SizedBox(height: 15),

        // ========================================================
        // DISTRICT
        // ========================================================

        DropdownButtonFormField<String>(
          value: sorsogonSecondDistrict,
          decoration: _inputDecoration(
            label: 'District',
            icon: Icons.map,
          ),
          items: [
            DropdownMenuItem<String>(
              value: sorsogonSecondDistrict,
              child: Text(
                sorsogonSecondDistrict,
              ),
            ),
          ],
          onChanged: null,
        ),

        const SizedBox(height: 15),

        // ========================================================
        // MUNICIPALITY
        // ========================================================

        DropdownButtonFormField<String>(
          value: _selectedMunicipality,
          isExpanded: true,
          decoration: _inputDecoration(
            label: 'Municipality',
            icon: Icons.location_city,
          ),
          hint: const Text(
            'Select Municipality',
          ),
          items:
              getSorsogonSecondDistrictMunicipalities()
                  .map(
                    (municipality) =>
                        DropdownMenuItem<String>(
                      value: municipality,
                      child: Text(
                        municipality,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
          onChanged: _isLoading
              ? null
              : (value) {
                  setState(() {
                    _selectedMunicipality =
                        value;

                    // Reset barangay whenever
                    // municipality changes.
                    _selectedBarangay = null;

                    _errorMessage = null;
                  });
                },
        ),

        const SizedBox(height: 15),

        // ========================================================
        // BARANGAY
        // ========================================================

        DropdownButtonFormField<String>(
          value: _selectedBarangay,
          isExpanded: true,
          decoration: _inputDecoration(
            label: 'Barangay',
            icon: Icons.home,
          ),
          hint: Text(
            _selectedMunicipality == null
                ? 'Select municipality first'
                : 'Select Barangay',
          ),
          items: _availableBarangays
              .map(
                (barangay) =>
                    DropdownMenuItem<String>(
                  value: barangay,
                  child: Text(
                    barangay,
                    overflow:
                        TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged:
              _selectedMunicipality == null ||
                      _isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _selectedBarangay =
                            value;

                        _errorMessage = null;
                      });
                    },
        ),

        // ========================================================
        // SELECTED ADDRESS PREVIEW
        // ========================================================

        if (_selectedMunicipality != null &&
            _selectedBarangay != null) ...[
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(
                0xFFD50000,
              ).withOpacity(0.06),
              borderRadius:
                  BorderRadius.circular(12),
              border: Border.all(
                color: const Color(
                  0xFFD50000,
                ).withOpacity(0.15),
              ),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.home_outlined,
                  color:
                      Color(0xFFD50000),
                  size: 22,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Address',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              FontWeight.bold,
                          color:
                              Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        buildSorsogonAddress(
                          municipality:
                              _selectedMunicipality!,
                          barangay:
                              _selectedBarangay!,
                        ),
                        style:
                            const TextStyle(
                          fontSize: 14,
                          fontWeight:
                              FontWeight.w600,
                          color:
                              Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,

        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin:
                Alignment.topCenter,
            end:
                Alignment.bottomCenter,
            colors: [
              Color(0xFFD50000),
              Color(0xFFFFC107),
            ],
          ),
        ),

        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.all(20),

              child: Container(
                padding:
                    const EdgeInsets.all(25),

                decoration:
                    BoxDecoration(
                  color:
                      Colors.white.withOpacity(
                    0.95,
                  ),
                  borderRadius:
                      BorderRadius.circular(25),
                ),

                child: Column(
                  children: [
                    // ==================================================
                    // HEADER
                    // ==================================================

                    const Icon(
                      Icons.person_add,
                      size: 60,
                      color:
                          Color(0xFFD50000),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "CREATE ACCOUNT",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(0xFFD50000),
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'SORECONNECT Consumer Registration',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Colors.black54,
                      ),
                    ),

                    const SizedBox(
                      height: 25,
                    ),

                    // ==================================================
                    // FULL NAME
                    // ==================================================

                    TextField(
                      controller:
                          _fullNameController,
                      textCapitalization:
                          TextCapitalization.words,
                      decoration:
                          _inputDecoration(
                        label:
                            "Full Name",
                        icon:
                            Icons.person,
                      ),
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    // ==================================================
                    // EMAIL
                    // ==================================================

                    TextField(
                      controller:
                          _emailController,
                      keyboardType:
                          TextInputType
                              .emailAddress,
                      decoration:
                          _inputDecoration(
                        label:
                            "Email",
                        icon:
                            Icons.email,
                      ),
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    // ==================================================
                    // ACCOUNT NUMBER
                    // ==================================================

                    TextField(
                      controller:
                          _accountNumberController,
                      keyboardType:
                          TextInputType.number,
                      decoration:
                          _inputDecoration(
                        label:
                            "Account Number",
                        icon:
                            Icons.numbers,
                      ),
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    // ==================================================
                    // CONTACT NUMBER
                    // ==================================================

                    TextField(
                      controller:
                          _contactNumberController,
                      keyboardType:
                          TextInputType.phone,
                      decoration:
                          _inputDecoration(
                        label:
                            "Contact Number",
                        icon:
                            Icons.phone,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ==================================================
                    // ADDRESS SECTION
                    // ==================================================

                    Align(
                      alignment:
                          Alignment.centerLeft,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color:
                                Color(0xFFD50000),
                            size: 21,
                          ),

                          const SizedBox(
                            width: 7,
                          ),

                          const Text(
                            'ADDRESS',
                            style:
                                TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  Color(0xFFD50000),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    const Align(
                      alignment:
                          Alignment.centerLeft,
                      child: Text(
                        'Select your municipality and barangay in Sorsogon 2nd District.',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              Colors.black54,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ==================================================
                    // ADDRESS DROPDOWNS
                    // ==================================================

                    _addressDropdowns(),

                    const SizedBox(
                      height: 20,
                    ),

                    // ==================================================
                    // PASSWORD
                    // ==================================================

                    TextField(
                      controller:
                          _passwordController,
                      obscureText:
                          _obscurePassword,
                      decoration:
                          _inputDecoration(
                        label:
                            "Password",
                        icon:
                            Icons.lock,
                      ).copyWith(
                        suffixIcon:
                            IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons
                                    .visibility_off
                                : Icons
                                    .visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword =
                                  !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    // ==================================================
                    // CONFIRM PASSWORD
                    // ==================================================

                    TextField(
                      controller:
                          _confirmPasswordController,
                      obscureText:
                          _obscureConfirmPassword,
                      decoration:
                          _inputDecoration(
                        label:
                            "Confirm Password",
                        icon:
                            Icons.lock_outline,
                      ).copyWith(
                        suffixIcon:
                            IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons
                                    .visibility_off
                                : Icons
                                    .visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ==================================================
                    // ERROR MESSAGE
                    // ==================================================

                    if (_errorMessage != null)
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets
                                .all(12),
                        margin:
                            const EdgeInsets.only(
                          bottom: 10,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Colors.red
                              .withOpacity(
                            0.08,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Icon(
                              Icons
                                  .error_outline,
                              color:
                                  Colors.red,
                              size: 20,
                            ),

                            const SizedBox(
                              width: 8,
                            ),

                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.red,
                                  fontSize:
                                      13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ==================================================
                    // REGISTER BUTTON
                    // ==================================================

                    SizedBox(
                      width:
                          double.infinity,
                      height: 50,
                      child:
                          ElevatedButton(
                        onPressed:
                            _isLoading
                                ? null
                                : _register,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(
                            0xFFD50000,
                          ),
                          foregroundColor:
                              Colors.white,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(
                                  color:
                                      Colors.white,
                                  strokeWidth:
                                      2.5,
                                ),
                              )
                            : const Text(
                                "REGISTER",
                                style:
                                    TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    // ==================================================
                    // LOGIN
                    // ==================================================

                    TextButton(
                      onPressed:
                          _isLoading
                              ? null
                              : () =>
                                  Navigator.pop(
                                    context,
                                  ),
                      child:
                          const Text(
                        "Already have an account? Login",
                        style:
                            TextStyle(
                          color:
                              Color(0xFFD50000),
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}