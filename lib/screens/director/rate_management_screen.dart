import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soreconnect/services/rate_service.dart';

class RateManagementScreen extends StatefulWidget {
  const RateManagementScreen({super.key});

  @override
  State<RateManagementScreen> createState() => _RateManagementScreenState();
}

class _RateManagementScreenState extends State<RateManagementScreen> {
  final RateService _rateService = RateService();
  final TextEditingController _rateController = TextEditingController();

  bool _isUpdating = false;
  double _currentRate = 12.0;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadCurrentRate();
  }

  // ============================================================
  // LOAD CURRENT RATE
  // ============================================================
  Future<void> _loadCurrentRate() async {
    try {
      final rate = await _rateService.getCurrentRate();

      if (!mounted) return;

      setState(() {
        _currentRate = rate;
        _rateController.text = rate.toStringAsFixed(2);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _message = '❌ Unable to load current rate: $e';
      });
    }
  }

  // ============================================================
  // UPDATE RATE
  // ============================================================
  Future<void> _updateRate() async {
    final newRate = double.tryParse(
      _rateController.text.trim(),
    );

    // Validate rate
    if (newRate == null || newRate <= 0) {
      setState(() {
        _message = 'Please enter a valid rate greater than 0';
      });
      return;
    }

    setState(() {
      _isUpdating = true;
      _message = null;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;

      await _rateService.updateRate(
        newRate,
        user?.email ?? 'Director',
      );

      if (!mounted) return;

      setState(() {
        _currentRate = newRate;
        _rateController.text = newRate.toStringAsFixed(2);

        _message =
            '✅ Rate updated successfully to ₱${newRate.toStringAsFixed(2)} per kWh';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _message = '❌ Error: $e';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Electricity Rates',
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),

      // ============================================================
      // SCROLLABLE BODY
      // ============================================================
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ======================================================
              // CURRENT RATE CARD
              // ======================================================
              Card(
                color: primaryColor.withOpacity(0.1),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Electricity Icon
                      Icon(
                        Icons.electric_bolt,
                        size: 48,
                        color: primaryColor,
                      ),

                      const SizedBox(height: 12),

                      // Title
                      const Text(
                        'Current Electricity Rate',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Current Rate
                      Text(
                        '₱${_currentRate.toStringAsFixed(2)}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),

                      const SizedBox(height: 2),

                      // Unit
                      const Text(
                        'per kilowatt-hour (kWh)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ======================================================
              // UPDATE RATE TITLE
              // ======================================================
              const Text(
                'Update Rate',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Enter new rate per kWh (₱)',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 12),

              // ======================================================
              // RATE INPUT
              // ======================================================
              TextField(
                controller: _rateController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                enabled: !_isUpdating,
                decoration: const InputDecoration(
                  prefixText: '₱ ',
                  prefixStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 13.50',
                  labelText: 'Rate per kWh',
                ),
              ),

              const SizedBox(height: 16),

              // ======================================================
              // MESSAGE
              // ======================================================
              if (_message != null)
                Card(
                  elevation: 0,
                  color: _message!.contains('✅')
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _message!.contains('✅')
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: _message!.contains('✅')
                              ? Colors.green
                              : Colors.red,
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: Text(
                            _message!,
                            style: TextStyle(
                              color: _message!.contains('✅')
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // ======================================================
              // UPDATE BUTTON
              // ======================================================
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUpdating ? null : _updateRate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isUpdating
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'UPDATE RATE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // ======================================================
              // INFORMATION BOX
              // ======================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.shade100,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        'Rate changes will affect all future bill '
                        'calculations. Previous bills will not be affected.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Extra bottom spacing
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}