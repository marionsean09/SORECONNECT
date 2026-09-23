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

  // Director-added charges and subsidies, on top of the fixed
  // fields above. Kept in local state until "UPDATE RATES" is
  // pressed, same as every other field on this screen.
  List<CustomRateLineItem> _customItems = [];
  final Map<String, TextEditingController> _customControllers = {};

  // Keys of fixed `RateModel.lineItems` the director removed. Soft
  // delete: the field's stored value is untouched, it's just left
  // out of the bill and hidden here behind a "Removed" chip until
  // restored.
  Set<String> _disabledKeys = {};

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

    for (final controller in _customControllers.values) {
      controller.dispose();
    }
    _customControllers.clear();
    _customItems = List.of(rate.customLineItems);
    for (final item in _customItems) {
      _customControllers[item.id] = TextEditingController(
        text: item.isFlat
            ? item.rate.toStringAsFixed(2)
            : item.rate.toStringAsFixed(4),
      );
    }

    _disabledKeys = Set.of(rate.disabledKeys);
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

    final List<CustomRateLineItem> updatedCustomItems = [];
    for (final item in _customItems) {
      final parsed =
          double.tryParse(_customControllers[item.id]!.text.trim());

      if (parsed == null || parsed < 0) {
        setState(() {
          _message = 'Please enter a valid, non-negative value for '
              '"${item.label}"';
        });
        return;
      }

      updatedCustomItems.add(item.copyWith(rate: parsed));
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
        customLineItems: updatedCustomItems,
        disabledKeys: _disabledKeys,
      );

      await _rateService.updateRate(newRate, updatedBy);

      if (!mounted) return;

      setState(() {
        _currentRate = newRate;
        _customItems = updatedCustomItems;
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
    for (final controller in _customControllers.values) {
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

  List<CustomRateLineItem> _customChargesFor(RateSection section) =>
      _customItems
          .where((item) => item.section == section && !item.isSubsidy)
          .toList();

  List<CustomRateLineItem> get _subsidies =>
      _customItems.where((item) => item.isSubsidy).toList();

  // ============================================================
  // ADD / REMOVE CUSTOM CHARGES & SUBSIDIES
  // ============================================================

  Future<void> _showAddItemDialog({
    required String title,
    required String helperText,
    required RateSection section,
    required bool isSubsidy,
    required Color accentColor,
  }) async {
    final labelController = TextEditingController();
    final rateController = TextEditingController();
    final isFlat = section == RateSection.footer;
    String? errorText;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      helperText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: labelController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Name',
                        hintText:
                            isSubsidy ? 'e.g. PWD Subsidy' : 'e.g. Franchise Tax',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rateController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixText: '₱ ',
                        labelText: 'Rate',
                        suffixText: isFlat ? 'flat / bill' : 'per kWh',
                        suffixStyle: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    final label = labelController.text.trim();
                    final rate = double.tryParse(rateController.text.trim());

                    if (label.isEmpty) {
                      setDialogState(() => errorText =
                          'Enter a name for this ${isSubsidy ? 'subsidy' : 'charge'}.');
                      return;
                    }
                    if (rate == null || rate < 0) {
                      setDialogState(
                          () => errorText = 'Enter a valid, non-negative rate.');
                      return;
                    }

                    Navigator.of(dialogContext)
                        .pop({'label': label, 'rate': rate.toString()});
                  },
                  child: Text(isSubsidy ? 'Add Subsidy' : 'Add Charge'),
                ),
              ],
            );
          },
        );
      },
    );

    labelController.dispose();
    rateController.dispose();

    if (result == null || !mounted) return;

    final newItem = CustomRateLineItem(
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
      label: result['label']!,
      section: section,
      rate: double.parse(result['rate']!),
      isFlat: isFlat,
      isSubsidy: isSubsidy,
    );

    setState(() {
      _customItems.add(newItem);
      _customControllers[newItem.id] = TextEditingController(
        text: newItem.isFlat
            ? newItem.rate.toStringAsFixed(2)
            : newItem.rate.toStringAsFixed(4),
      );
    });
  }

  Future<void> _confirmDeleteCustomItem(CustomRateLineItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Remove this item?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '"${item.label}" will stop applying to bills generated after you '
          'save. Bills already issued keep it as it was.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _customItems.removeWhere((c) => c.id == item.id);
      _customControllers.remove(item.id)?.dispose();
    });
  }

  Future<void> _confirmDeleteFixedItem(RateLineItemDef item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Remove this rate?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '"${item.label}" will stop applying to bills generated after you '
          'save. Its stored value is kept, so you can restore it later from '
          'the "Removed" list. Bills already issued keep it as it was.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _disabledKeys.add(item.key);
    });
  }

  void _restoreFixedItem(RateLineItemDef item) {
    setState(() {
      _disabledKeys.remove(item.key);
    });
  }

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
                              'official Notice of Billing format. Use '
                              '"Add Charge" or "Add Subsidy" under any '
                              'section to introduce a new one.',
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
    final allItems = _itemsFor(section);
    final activeItems =
        allItems.where((item) => !_disabledKeys.contains(item.key)).toList();
    final removedItems =
        allItems.where((item) => _disabledKeys.contains(item.key)).toList();
    final customCharges = _customChargesFor(section);
    final subsidies =
        section == RateSection.other ? _subsidies : const <CustomRateLineItem>[];

    if (allItems.isEmpty && customCharges.isEmpty && subsidies.isEmpty) {
      return const SizedBox.shrink();
    }

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
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: const Cubic(0.23, 1, 0.32, 1),
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in activeItems)
                  _buildRateFieldRow(
                    fieldKey: ValueKey('fixed_${item.key}'),
                    controller: _controllers[item.key]!,
                    label: item.label,
                    isFlat: item.isFlat,
                    onDelete: () => _confirmDeleteFixedItem(item),
                  ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: const Cubic(0.23, 1, 0.32, 1),
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in customCharges)
                  _buildCustomItemRow(item, primaryColor),
              ],
            ),
          ),
          _buildAddButton(
            label: 'Add Charge',
            color: primaryColor,
            onPressed: () => _showAddItemDialog(
              title: 'Add Charge · ${_sectionLabel(section)}',
              helperText: section == RateSection.footer
                  ? 'A one-time flat fee added once per bill, same as Insurance.'
                  : 'Multiplied by kWh used, same as the rates above.',
              section: section,
              isSubsidy: false,
              accentColor: primaryColor,
            ),
          ),
          if (removedItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Removed — tap to restore',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in removedItems)
                  Chip(
                    label: Text(item.label, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.grey.shade100,
                    side: BorderSide(color: Colors.grey.shade300),
                    deleteIcon: Icon(Icons.replay, size: 16, color: primaryColor),
                    onDeleted:
                        _isUpdating ? null : () => _restoreFixedItem(item),
                  ),
              ],
            ),
          ],

          if (section == RateSection.other) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade300, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.volunteer_activism_outlined,
                    size: 16, color: Colors.green.shade700),
                const SizedBox(width: 6),
                Text(
                  'Subsidies',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Deducted from the total bill, on top of Senior Citizen Subs '
              'above.',
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: const Cubic(0.23, 1, 0.32, 1),
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in subsidies)
                    _buildCustomItemRow(item, Colors.green.shade700),
                ],
              ),
            ),
            _buildAddButton(
              label: 'Add Subsidy',
              color: Colors.green.shade700,
              onPressed: () => _showAddItemDialog(
                title: 'Add Subsidy',
                helperText: 'Deducted from the bill total, multiplied by '
                    'kWh used just like Senior Citizen Subs.',
                section: RateSection.other,
                isSubsidy: true,
                accentColor: Colors.green.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _isUpdating ? null : onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(Icons.add_circle_outline, size: 18, color: color),
        label: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomItemRow(CustomRateLineItem item, Color accentColor) {
    return _buildRateFieldRow(
      fieldKey: ValueKey(item.id),
      controller: _customControllers[item.id]!,
      label: item.label,
      isFlat: item.isFlat,
      isSubsidy: item.isSubsidy,
      onDelete: () => _confirmDeleteCustomItem(item),
    );
  }

  // Shared row for both fixed and director-added charges/subsidies:
  // a rate TextField plus a delete affordance. New rows fade + slide
  // in; AnimatedSize around the caller's list handles the collapse
  // when one is removed.
  Widget _buildRateFieldRow({
    required Key fieldKey,
    required TextEditingController controller,
    required String label,
    required bool isFlat,
    bool isSubsidy = false,
    required VoidCallback onDelete,
  }) {
    return TweenAnimationBuilder<double>(
      key: fieldKey,
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: const Cubic(0.23, 1, 0.32, 1),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 8),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !_isUpdating,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  isDense: true,
                  prefixText: isSubsidy ? '− ₱ ' : '₱ ',
                  labelText: label,
                  suffixText: isFlat ? 'flat / bill' : 'per kWh',
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
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Remove $label',
              onPressed: _isUpdating ? null : onDelete,
              icon: Icon(Icons.delete_outline,
                  color: Colors.red.shade400, size: 20),
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}
