import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:soreconnect/models/rate_model.dart';
import 'package:soreconnect/services/rate_service.dart';

class RateManagementScreen extends StatefulWidget {
  const RateManagementScreen({super.key});

  @override
  State<RateManagementScreen> createState() => _RateManagementScreenState();
}

class _RateManagementScreenState extends State<RateManagementScreen> {
  final RateService _rateService = RateService();

  final Map<String, TextEditingController> _controllers = {
    for (final item in RateModel.lineItems) item.key: TextEditingController(),
  };

  bool _isLoading = true;
  bool _isUpdating = false;
  RateModel? _currentRate;
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

      _applyRateToControllers(rate);

      setState(() {
        _currentRate = rate;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _message = '❌ Unable to load current rates: $e';
      });
    }
  }

  void _applyRateToControllers(RateModel rate) {
    for (final item in RateModel.lineItems) {
      final value = rate.valueFor(item.key);
      _controllers[item.key]!.text =
          item.isFlat ? value.toStringAsFixed(2) : value.toStringAsFixed(4);
    }
  }

  // ============================================================
  // UPDATE RATES
  // ============================================================
  Future<void> _updateRates() async {
    final Map<String, double> values = {};

    for (final item in RateModel.lineItems) {
      final parsed =
          double.tryParse(_controllers[item.key]!.text.trim());

      if (parsed == null || parsed < 0) {
        setState(() {
          _message = 'Please enter a valid, non-negative value for '
              '"${item.label}"';
        });
        return;
      }

      values[item.key] = parsed;
    }

    setState(() {
      _isUpdating = true;
      _message = null;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;

      final updatedBy = user?.email ?? 'Director';

      final newRate = RateModel.fromValuesMap(
        values,
        updatedBy: updatedBy,
      );

      await _rateService.updateRate(newRate, updatedBy);

      if (!mounted) return;

      setState(() {
        _currentRate = newRate;
        _message = '✅ Rates updated successfully';
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
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ============================================================
  // SECTION HELPERS
  // ============================================================

  String _sectionLabel(RateSection section) {
    switch (section) {
      case RateSection.charges:
        return 'Charges';
      case RateSection.vat:
        return 'Value Added Tax';
      case RateSection.universal:
        return 'Universal Charges';
      case RateSection.other:
        return 'Other Charges';
      case RateSection.footer:
        return 'Other Fees';
    }
  }

  List<RateLineItemDef> _itemsFor(RateSection section) => RateModel.lineItems
      .where((item) => item.section == section)
      .toList();

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Electricity Rates'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==========================================
                    // HEADER CARD
                    // ==========================================
                    Card(
                      color: primaryColor.withValues(alpha: 0.1),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long,
                                size: 44, color: primaryColor),
                            const SizedBox(height: 10),
                            const Text(
                              'Itemized Billing Rates',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Each rate below is multiplied by kWh used '
                              '(current reading − previous reading) to '
                              'compute a consumer\'s bill, matching the '
                              'official Notice of Billing format.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                            if (_currentRate != null &&
                                _currentRate!.updatedBy.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Last updated by ${_currentRate!.updatedBy} '
                                'on ${DateFormat('MMM d, yyyy h:mm a').format(_currentRate!.updatedAt.toDate())}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    for (final section in RateSection.values)
                      _buildSection(section, primaryColor),

                    if (_message != null) ...[
                      const SizedBox(height: 8),
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
                    ],

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isUpdating ? null : _updateRates,
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'UPDATE RATES',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Rate changes only affect bills generated '
                              'after saving. Bills already issued keep '
                              'the rates that were in effect at the time.',
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

                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSection(RateSection section, Color primaryColor) {
    final items = _itemsFor(section);
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _sectionLabel(section),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in items) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _controllers[item.key],
                enabled: !_isUpdating,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  isDense: true,
                  prefixText: '₱ ',
                  labelText: item.label,
                  suffixText: item.isFlat ? 'flat / bill' : 'per kWh',
                  suffixStyle: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
