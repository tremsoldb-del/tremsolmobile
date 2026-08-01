import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditShippingAddressPage extends StatefulWidget {
  final String addressId;

  const EditShippingAddressPage({
    super.key,
    required this.addressId,
  });

  @override
  State<EditShippingAddressPage> createState() =>
      _EditShippingAddressPageState();
}

class _EditShippingAddressPageState extends State<EditShippingAddressPage> {
  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _zipcodeController = TextEditingController();

  List<String> _regions = const [];
  String? _selectedRegion;
  String? _legacyRegion;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPageData();
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _zipcodeController.dispose();
    super.dispose();
  }

  String _normalizeRegionKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceFirst(RegExp(r'\s+region$'), '');
  }

  String _normalizePhone(String input) {
    return input.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  bool _isValidPhone(String input) {
    final normalized = _normalizePhone(input);
    final e164ish = RegExp(r'^\+?[1-9]\d{7,14}$');
    final ghLocal = RegExp(r'^0\d{9}$');
    final ghE164 = RegExp(r'^\+233\d{9}$');

    return e164ish.hasMatch(normalized) ||
        ghLocal.hasMatch(normalized) ||
        ghE164.hasMatch(normalized);
  }

  Future<List<String>> _fetchRegions() async {
    final doc = await FirebaseFirestore.instance
        .collection('regions')
        .doc('regions')
        .get();

    if (!doc.exists) {
      throw StateError(
        'The regions/regions document was not found in Firestore.',
      );
    }

    final data = doc.data() ?? <String, dynamic>{};
    final rawNames = data['name'];

    if (rawNames is! List) {
      throw StateError(
        'The regions/regions document must contain a name array.',
      );
    }

    final regions = <String>[];
    final seenKeys = <String>{};

    for (final value in rawNames) {
      final region = value.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
      final key = _normalizeRegionKey(region);

      if (region.isNotEmpty && key.isNotEmpty && seenKeys.add(key)) {
        regions.add(region);
      }
    }

    return regions;
  }

  Future<void> _loadPageData() async {
    try {
      final results = await Future.wait<dynamic>([
        FirebaseFirestore.instance
            .collection('shippingaddress')
            .doc(widget.addressId)
            .get(),
        _fetchRegions(),
      ]);

      final addressDoc =
          results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final regions = results[1] as List<String>;

      if (!addressDoc.exists) {
        throw StateError('Address not found.');
      }

      final data = addressDoc.data() ?? <String, dynamic>{};
      final savedRegion = (data['region'] ?? '').toString().trim();
      final savedRegionKey = (data['regionKey'] ?? '').toString().trim();
      final comparisonKey = savedRegionKey.isNotEmpty
          ? _normalizeRegionKey(savedRegionKey)
          : _normalizeRegionKey(savedRegion);

      String? canonicalRegion;
      for (final region in regions) {
        if (_normalizeRegionKey(region) == comparisonKey) {
          canonicalRegion = region;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _regions = regions;
        _selectedRegion = canonicalRegion;
        _legacyRegion = canonicalRegion == null && savedRegion.isNotEmpty
            ? savedRegion
            : null;

        _fullnameController.text = (data['fullname'] ?? '').toString();
        _phoneController.text = (data['phone'] ?? '').toString();
        _addressController.text = (data['address'] ?? '').toString();
        _cityController.text = (data['city'] ?? '').toString();
        _countryController.text = (data['country'] ?? '').toString();
        _zipcodeController.text = (data['zipcode'] ?? '').toString();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(_friendlyError(error));
    }
  }

  Future<void> _updateAddress() async {
    if (_isSaving) return;

    final fullName = _fullnameController.text.trim();
    final phone = _normalizePhone(_phoneController.text.trim());
    final address = _addressController.text.trim();
    final city = _cityController.text.trim();
    final region = _selectedRegion?.trim() ?? '';
    final country = _countryController.text.trim();
    final zipCode = _zipcodeController.text.trim();

    if (fullName.isEmpty) {
      _showError('Full Name cannot be empty.');
      return;
    }
    if (!RegExp(r"^[a-zA-ZÀ-ÿ'’.\-\s]+$").hasMatch(fullName)) {
      _showError(
        'Full Name can only contain letters, spaces, apostrophes and hyphens.',
      );
      return;
    }
    if (phone.isEmpty) {
      _showError('Phone Number is required.');
      return;
    }
    if (!_isValidPhone(phone)) {
      _showError(
        'Enter a valid phone number, such as +233541234567 or 0541234567.',
      );
      return;
    }
    if (address.isEmpty) {
      _showError('Address cannot be empty.');
      return;
    }
    if (city.isEmpty) {
      _showError('City cannot be empty.');
      return;
    }
    if (region.isEmpty) {
      _showError('Please select a valid region from the current region list.');
      return;
    }
    if (country.isEmpty) {
      _showError('Country cannot be empty.');
      return;
    }
    if (zipCode.isNotEmpty && !RegExp(r'^[\w\-\s]{3,12}$').hasMatch(zipCode)) {
      _showError('Enter a valid postal or zip code.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('shippingaddress')
          .doc(widget.addressId)
          .update({
        'fullname': fullName,
        'phone': phone,
        'address': address,
        'city': city,
        'region': region,
        'regionKey': _normalizeRegionKey(region),
        'country': country,
        'zipcode': zipCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address updated successfully.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showError('Could not update the address. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _friendlyError(Object error) {
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Shipping Address'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_legacyRegion != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'The saved region “$_legacyRegion” does not match the current '
                'region list. Please select the correct region before saving.',
                style: TextStyle(color: Colors.orange.shade900),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildTextField(
            'Full Name',
            _fullnameController,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            enabled: !_isSaving,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(
                RegExp(r'[0-9+\-\s\(\)]'),
              ),
            ],
            decoration: const InputDecoration(
              labelText: 'Phone Number *',
              hintText: '+233541234567 or 0541234567',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Address',
            _addressController,
            keyboardType: TextInputType.streetAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'City',
            _cityController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedRegion,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Region',
              border: OutlineInputBorder(),
            ),
            items: _regions
                .map(
                  (region) => DropdownMenuItem<String>(
                    value: region,
                    child: Text(region),
                  ),
                )
                .toList(),
            onChanged: _isSaving
                ? null
                : (value) {
                    setState(() {
                      _selectedRegion = value;
                      _legacyRegion = null;
                    });
                  },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Country',
            _countryController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Postal / Zip Code',
            _zipcodeController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _updateAddress,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      enabled: !_isSaving,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
