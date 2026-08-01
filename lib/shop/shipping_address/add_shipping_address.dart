import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddShippingAddressPage extends StatefulWidget {
  const AddShippingAddressPage({super.key});

  @override
  State<AddShippingAddressPage> createState() =>
      _AddShippingAddressPageState();
}

class _AddShippingAddressPageState extends State<AddShippingAddressPage> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController =
      TextEditingController(text: 'Ghana');
  final TextEditingController _zipCodeController = TextEditingController();

  late final Future<List<String>> _regionsFuture;

  String? selectedRegion;
  bool isDefault = false;
  bool _isSaving = false;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _regionsFuture = _fetchRegions();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _zipCodeController.dispose();
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

  Future<bool> _userAlreadyHasAnAddress(String userId) async {
    final result = await FirebaseFirestore.instance
        .collection('shippingaddress')
        .where('uid', isEqualTo: userId)
        .limit(1)
        .get();

    return result.docs.isNotEmpty;
  }

  Future<void> _handleAddAddress() async {
    if (_isSaving) return;

    final user = _currentUser;
    if (user == null) {
      _showError('You need to be signed in to add a shipping address.');
      return;
    }

    var setAsDefault = isDefault;

    try {
      final hasExistingAddress = await _userAlreadyHasAnAddress(user.uid);
      if (!mounted) return;

      if (!hasExistingAddress) {
        setAsDefault = true;
      } else if (!setAsDefault) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Set as Default Address?'),
              content: const Text(
                'This address is not marked as your default shipping address. '
                'Would you like to make it your default?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Yes'),
                ),
              ],
            );
          },
        );

        if (confirm == null) return;
        setAsDefault = confirm;
      }

      await _saveShippingAddress(
        userId: user.uid,
        setAsDefault: setAsDefault,
      );
    } catch (error) {
      if (!mounted) return;
      _showError(_friendlyError(error));
    }
  }

  Future<void> _saveShippingAddress({
    required String userId,
    required bool setAsDefault,
  }) async {
    final fullName = _fullNameController.text.trim();
    final phone = _normalizePhone(_phoneController.text.trim());
    final address = _addressController.text.trim();
    final city = _cityController.text.trim();
    final region = selectedRegion?.trim() ?? '';
    final country = _countryController.text.trim();
    final zipCode = _zipCodeController.text.trim();

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
      _showError('Please select a region.');
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
      final firestore = FirebaseFirestore.instance;
      final addressRef = firestore.collection('shippingaddress').doc();
      final batch = firestore.batch();

      if (setAsDefault) {
        final currentAddresses = await firestore
            .collection('shippingaddress')
            .where('uid', isEqualTo: userId)
            .get();

        for (final doc in currentAddresses.docs) {
          batch.update(doc.reference, {'isDefault': false});
        }
      }

      batch.set(addressRef, {
        'id': addressRef.id,
        'fullname': fullName,
        'phone': phone,
        'address': address,
        'city': city,
        'region': region,
        'regionKey': _normalizeRegionKey(region),
        'country': country,
        'zipcode': zipCode,
        'uid': userId,
        'isDefault': setAsDefault,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shipping address added successfully.'),
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showError('Could not save the address. Please try again.');
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

  Widget _buildRegionDropdown() {
    return FutureBuilder<List<String>>(
      future: _regionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Region',
              border: OutlineInputBorder(),
              errorText: 'Could not load regions.',
            ),
            child: Text(
              _friendlyError(snapshot.error!),
              style: const TextStyle(fontSize: 13),
            ),
          );
        }

        final regions = snapshot.data ?? const <String>[];
        if (regions.isEmpty) {
          return const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Region',
              border: OutlineInputBorder(),
              errorText: 'No regions are configured.',
            ),
            child: SizedBox.shrink(),
          );
        }

        return DropdownButtonFormField<String>(
          initialValue: selectedRegion,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Region',
            border: OutlineInputBorder(),
          ),
          items: regions
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
                  setState(() => selectedRegion = value);
                },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Shipping Address'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField(
              'Full Name',
              _fullNameController,
              textInputType: TextInputType.name,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            _buildPhoneField(),
            const SizedBox(height: 16),
            _buildTextField(
              'Address',
              _addressController,
              textInputType: TextInputType.streetAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'City',
              _cityController,
              textInputType: TextInputType.text,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            _buildRegionDropdown(),
            const SizedBox(height: 16),
            _buildTextField(
              'Country',
              _countryController,
              textInputType: TextInputType.text,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Postal / Zip Code',
              _zipCodeController,
              textInputType: TextInputType.text,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: isDefault,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Use as my default shipping address'),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() => isDefault = value ?? false);
                    },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSaving ? null : _handleAddAddress,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save Address',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType? textInputType,
    TextInputAction? textInputAction,
  }) {
    return TextField(
      controller: controller,
      keyboardType: textInputType,
      textInputAction: textInputAction,
      enabled: !_isSaving,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      enabled: !_isSaving,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s\(\)]')),
      ],
      decoration: const InputDecoration(
        labelText: 'Phone Number *',
        hintText: '+233541234567 or 0541234567',
        border: OutlineInputBorder(),
      ),
    );
  }
}
