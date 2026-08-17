import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  Future<void> _register() async {
    // Validation
    if (_fullNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Enter full name");
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Enter email");
      return;
    }
    if (!_emailController.text.contains('@')) {
      setState(() => _errorMessage = "Enter valid email");
      return;
    }
    if (_accountNumberController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Enter account number");
      return;
    }
    if (_contactNumberController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Enter contact number");
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Enter address");
      return;
    }
    if (_passwordController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Enter password");
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = "Password must be 6+ characters");
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = "Passwords don't match");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // STEP 1: Create user in Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      print("✅ User created: ${userCredential.user!.uid}");

      // STEP 2: Create document in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'uid': userCredential.user!.uid,
            'full_name': _fullNameController.text.trim(),
            'email': _emailController.text.trim(),
            'user_type': 'consumer',
            'accountNumber': _accountNumberController.text.trim(),
            'contactNumber': _contactNumberController.text.trim(),
            'address': _addressController.text.trim(),
            'created_at': DateTime.now().toIso8601String(),
          });

      print("✅ Firestore document created");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful! Please login.')),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      print("❌ Auth Error: ${e.code}");
      if (e.code == 'email-already-in-use') {
        setState(() => _errorMessage = 'Email already registered');
      } else if (e.code == 'weak-password') {
        setState(() => _errorMessage = 'Password too weak');
      } else {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      print("❌ Other Error: $e");
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFD50000),
              Color(0xFFFFC107),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.person_add, size: 60, color: Color(0xFFD50000)),
                    const SizedBox(height: 10),
                    const Text(
                      "CREATE ACCOUNT",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFD50000)),
                    ),
                    const SizedBox(height: 25),
                    
                    TextField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: "Full Name",
                        prefixIcon: const Icon(Icons.person, color: Color(0xFFD50000)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Email",
                        prefixIcon: const Icon(Icons.email, color: Color(0xFFD50000)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    TextField(
                      controller: _accountNumberController,
                      decoration: InputDecoration(
                        labelText: "Account Number",
                        prefixIcon: const Icon(Icons.numbers, color: Color(0xFFD50000)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    TextField(
                      controller: _contactNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "Contact Number",
                        prefixIcon: const Icon(Icons.phone, color: Color(0xFFD50000)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    TextField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: "Address",
                        prefixIcon: const Icon(Icons.home, color: Color(0xFFD50000)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(Icons.lock, color: Color(0xFFD50000)),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: "Confirm Password",
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFD50000)),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    if (_errorMessage != null)
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 10),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD50000),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("REGISTER", style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Already have an account? Login", style: TextStyle(color: Color(0xFFD50000))),
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