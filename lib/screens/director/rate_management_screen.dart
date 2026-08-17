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

  Future<void> _loadCurrentRate() async {
    final rate = await _rateService.getCurrentRate();
    setState(() {
      _currentRate = rate;
      _rateController.text = rate.toString();
    });
  }

  Future<void> _updateRate() async {
    final newRate = double.tryParse(_rateController.text.trim());
    
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
      await _rateService.updateRate(newRate, user?.email ?? 'Director');
      
      setState(() {
        _currentRate = newRate;
        _message = '✅ Rate updated successfully to ₱${newRate.toStringAsFixed(2)} per kWh';
      });
      
    } catch (e) {
      setState(() {
        _message = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Electricity Rates'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.electric_bolt,
                      size: 48,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Current Electricity Rate',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₱${_currentRate.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const Text(
                      'per kilowatt-hour (kWh)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Update Rate',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter new rate per kWh (₱)',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rateController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
                hintText: 'e.g., 13.50',
              ),
            ),
            const SizedBox(height: 16),
            
            if (_message != null)
              Card(
                color: _message!.contains('✅') ? Colors.green.shade50 : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _message!.contains('✅') ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              height: 50,
                child: ElevatedButton(
                onPressed: _isUpdating ? null : _updateRate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: _isUpdating
                    ? const Text('UPDATING...')
                    : const Text('UPDATE RATE'),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Rate changes will affect all future bill calculations. Previous bills will not be affected.',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}