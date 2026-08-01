import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shop/service/regional_shipping_fee_service.dart';

class RegionalShippingFeesAdminPage extends StatefulWidget {
  const RegionalShippingFeesAdminPage({super.key});

  @override
  State<RegionalShippingFeesAdminPage> createState() =>
      _RegionalShippingFeesAdminPageState();
}

class _RegionalShippingFeesAdminPageState
    extends State<RegionalShippingFeesAdminPage> {
  final TextEditingController _applyToAllController = TextEditingController();
  final Map<String, TextEditingController> _feeControllers = {};

  List<String> _regions = const [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  double _legacyShippingFee = 0;

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  @override
  void dispose() {
    _applyToAllController.dispose();
    for (final controller in _feeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadConfiguration() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('regions')
            .doc('regions')
            .get(),
        FirebaseFirestore.instance
            .collection('settings')
            .doc(RegionalShippingFeeService.settingsDocument)
            .get(),
        FirebaseFirestore.instance
            .collection('settings')
            .doc('doc1')
            .get(),
      ]);

      final regionsDoc = results[0];
      final feesDoc = results[1];
      final legacyDoc = results[2];

      if (!regionsDoc.exists) {
        throw StateError(
          'The regions/regions document does not exist.',
        );
      }

      final rawRegionNames = regionsDoc.data()?['name'];
      if (rawRegionNames is! List) {
        throw StateError(
          'The regions/regions document must contain a name array.',
        );
      }

      final regions = <String>[];
      final seenKeys = <String>{};

      for (final value in rawRegionNames) {
        final label = value
            .toString()
            .trim()
            .replaceAll(RegExp(r'\s+'), ' ');
        final key = RegionalShippingFeeService.normalizeRegionKey(label);

        if (label.isNotEmpty && key.isNotEmpty && seenKeys.add(key)) {
          regions.add(label);
        }
      }

      if (regions.isEmpty) {
        throw StateError('No valid regions were found.');
      }

      final legacyFee = _parseAmount(legacyDoc.data()?['shipping_fee']) ?? 0;
      final configuredFees = _normalizeFeeMap(feesDoc.data()?['fees']);

      for (final controller in _feeControllers.values) {
        controller.dispose();
      }
      _feeControllers.clear();

      for (final region in regions) {
        final key = RegionalShippingFeeService.normalizeRegionKey(region);
        final amount = configuredFees[key] ?? legacyFee;
        _feeControllers[key] = TextEditingController(
          text: _formatEditableAmount(amount),
        );
      }

      if (!mounted) return;
      setState(() {
        _regions = regions;
        _legacyShippingFee = legacyFee;
        _applyToAllController.text = _formatEditableAmount(legacyFee);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = _friendlyError(error);
        _isLoading = false;
      });
    }
  }

  Map<String, double> _normalizeFeeMap(dynamic rawFees) {
    final fees = <String, double>{};
    if (rawFees is! Map) return fees;

    for (final entry in rawFees.entries) {
      final key = RegionalShippingFeeService.normalizeRegionKey(
        entry.key.toString(),
      );
      final amount = _parseAmount(entry.value);
      if (key.isNotEmpty && amount != null && amount >= 0) {
        fees[key] = amount;
      }
    }

    return fees;
  }

  double? _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(
        value.replaceAll(RegExp(r'[^0-9.\-]'), ''),
      );
    }
    return null;
  }

  String _formatEditableAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }
    return amount.toStringAsFixed(2);
  }

  String _friendlyError(Object error) {
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  void _applyAmountToAll() {
    final amount = _parseAmount(_applyToAllController.text);
    if (amount == null || amount < 0) {
      _showMessage(
        'Enter a valid non-negative amount to apply to all regions.',
        isError: true,
      );
      return;
    }

    final formatted = _formatEditableAmount(amount);
    for (final controller in _feeControllers.values) {
      controller.text = formatted;
    }

    _showMessage('The amount was applied to all regions. Tap Save to commit.');
  }

  void _restoreLegacyFeeForAll() {
    final formatted = _formatEditableAmount(_legacyShippingFee);
    _applyToAllController.text = formatted;
    for (final controller in _feeControllers.values) {
      controller.text = formatted;
    }

    _showMessage(
      'All fields now use the old global shipping fee. Tap Save to seed them.',
    );
  }

  Future<void> _saveRegionalFees() async {
    if (_isSaving) return;

    final fees = <String, double>{};
    final labels = <String, String>{};
    final invalidRegions = <String>[];

    for (final region in _regions) {
      final key = RegionalShippingFeeService.normalizeRegionKey(region);
      final controller = _feeControllers[key];
      final amount = _parseAmount(controller?.text);

      if (amount == null || amount < 0) {
        invalidRegions.add(region);
        continue;
      }

      fees[key] = amount;
      labels[key] = region;
    }

    if (invalidRegions.isNotEmpty) {
      _showMessage(
        'Enter a valid shipping fee for: ${invalidRegions.join(', ')}.',
        isError: true,
      );
      return;
    }

    if (fees.length != _regions.length) {
      _showMessage(
        'Every region must have a shipping fee before saving.',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc(RegionalShippingFeeService.settingsDocument)
          .set({
        'currency': 'GHS',
        'fees': fees,
        'regionLabels': labels,
        'regionCount': fees.length,
        'schemaVersion': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showMessage(
        'Regional shipping fees saved successfully for ${fees.length} regions.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Could not save regional shipping fees: ${_friendlyError(error)}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regional Shipping Fees'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _isSaving ? null : _loadConfiguration,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _isLoading || _loadError != null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveRegionalFees,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save Regional Fees',
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: const Color(0xFF002A5C),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadConfiguration,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFB7CCE8)),
          ),
          child: const Text(
            'Set the shipping fee charged for each of Ghana’s 16 regions. '
            'The checkout page reads the customer’s default-address region '
            'and applies the matching amount.',
            style: TextStyle(height: 1.4),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _applyToAllController,
          enabled: !_isSaving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            labelText: 'Amount to apply to all regions',
            prefixText: 'GHS ',
            border: const OutlineInputBorder(),
            helperText:
                'Old global fee: GHS ${_legacyShippingFee.toStringAsFixed(2)}',
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _applyAmountToAll,
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Apply to All'),
            ),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _restoreLegacyFeeForAll,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Seed with Old Fee'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          '${_regions.length} regions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),
        ..._regions.map(_buildRegionFeeField),
      ],
    );
  }

  Widget _buildRegionFeeField(String region) {
    final key = RegionalShippingFeeService.normalizeRegionKey(region);
    final controller = _feeControllers[key]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    region,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    key,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 135,
              child: TextField(
                controller: controller,
                enabled: !_isSaving,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,2}'),
                  ),
                ],
                textAlign: TextAlign.end,
                decoration: const InputDecoration(
                  prefixText: 'GHS ',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
