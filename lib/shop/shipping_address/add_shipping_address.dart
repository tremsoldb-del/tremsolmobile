import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddShippingAddressPage extends StatefulWidget {
  const AddShippingAddressPage({super.key});

  @override
  State<AddShippingAddressPage> createState() => _AddShippingAddressPageState();
}

class _AddShippingAddressPageState extends State<AddShippingAddressPage> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(); // NEW
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();

  bool isDefault = false;
  late final String userId;

  String? selectedRegion;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser!.uid;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose(); // NEW
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }

  // --- Phone validation helpers ---
  bool _isValidPhone(String input) {
    // Normalize (remove spaces, dashes, parentheses)
    final normalized = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // General E.164-style (optional +, 8–15 digits, cannot start with 0 after +)
    final e164ish = RegExp(r'^\+?[1-9]\d{7,14}$');

    // Ghana-friendly local format (e.g., 0XXXXXXXXX) – 10 digits starting with 0
    final ghLocal = RegExp(r'^0\d{9}$');

    // Ghana E.164 (+233XXXXXXXXX) – +233 followed by 9 digits
    final ghE164 = RegExp(r'^\+233\d{9}$');

    return e164ish.hasMatch(normalized) || ghLocal.hasMatch(normalized) || ghE164.hasMatch(normalized);
  }

  Future<void> _saveShippingAddress({required bool setAsDefault}) async {
    // Trim input values
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim(); // NEW
    final address = _addressController.text.trim();
    final city = _cityController.text.trim();
    final country = _countryController.text.trim();
    final zipCode = _zipCodeController.text.trim();

    // Validation checks
    if (fullName.isEmpty) {
      _showError("Full Name cannot be empty.");
      return;
    }
    if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(fullName)) {
      _showError("Full Name can only contain letters and spaces.");
      return;
    }

    // Phone REQUIRED + validated
    if (phone.isEmpty) {
      _showError("Phone Number is required.");
      return;
    }
    if (!_isValidPhone(phone)) {
      _showError("Enter a valid phone number (e.g., +233541234567 or 0541234567).");
      return;
    }

    if (address.isEmpty) {
      _showError("Address cannot be empty.");
      return;
    }

    if (city.isEmpty) {
      _showError("City cannot be empty.");
      return;
    }
    if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(city)) {
      _showError("City can only contain letters and spaces.");
      return;
    }

    if (selectedRegion == null) {
      _showError("Please select a region.");
      return;
    }

    if (country.isEmpty) {
      _showError("Country cannot be empty.");
      return;
    }
    if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(country)) {
      _showError("Country can only contain letters and spaces.");
      return;
    }

    if (zipCode.isNotEmpty && !RegExp(r"^[\d-]{4,10}$").hasMatch(zipCode)) {
      _showError("Enter a valid Zip Code (4-10 digits, hyphen allowed).");
      return;
    }

    try {
      // Add the document to the collection
      final docRef = await FirebaseFirestore.instance.collection('shippingaddress').add({
        'fullname': fullName,
        'phone': phone, // NEW
        'address': address,
        'city': city,
        'region': selectedRegion,
        'country': country,
        'zipcode': zipCode,
        'uid': userId,
        'isDefault': setAsDefault,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update the document to include the ID
      await FirebaseFirestore.instance.collection('shippingaddress').doc(docRef.id).update({
        'id': docRef.id,
      });

      // Set as default if selected
      if (setAsDefault) {
        await _setDefaultAddress(docRef.id);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Shipping address added successfully!")),
      );

      Navigator.pop(context);
    } catch (e) {
      // ignore: avoid_print
      print("Error adding address: $e");
      _showError("Error adding address. Please try again.");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _setDefaultAddress(String addressId) async {
    try {
      final query =
          await FirebaseFirestore.instance.collection('shippingaddress').where('uid', isEqualTo: userId).get();

      for (var doc in query.docs) {
        await doc.reference.update({'isDefault': false});
      }

      await FirebaseFirestore.instance.collection('shippingaddress').doc(addressId).update({'isDefault': true});
    } catch (e) {
      // ignore: avoid_print
      print("Error setting default address: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error setting default address.")),
      );
    }
  }

  Future<List<String>> _fetchRegions() async {
    final querySnapshot = await FirebaseFirestore.instance.collection('regions').get();

    // Extract all regions from the 'name' arrays in the documents
    List<String> regions = [];
    for (var doc in querySnapshot.docs) {
      List<dynamic>? names = doc['name'] as List<dynamic>?;
      if (names != null) {
        regions.addAll(names.cast<String>());
      }
    }
    return regions;
  }

  Widget _buildRegionDropdown() {
    return FutureBuilder<List<String>>(
      future: _fetchRegions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return const Text("Error loading regions.");
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text("No regions found.");
        }

        final regions = snapshot.data!;
        return DropdownButtonFormField<String>(
          initialValue: selectedRegion,
          onChanged: (value) {
            setState(() {
              selectedRegion = value!;
            });
          },
          items: regions.map((region) => DropdownMenuItem(value: region, child: Text(region))).toList(),
          decoration: InputDecoration(
            labelText: "Region",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleAddAddress() async {
    if (!isDefault) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Set as Default Address?"),
            content: const Text(
                "You have not set this address as your default shipping address. Do you want to set it as default?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("No"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("Yes"),
              ),
            ],
          );
        },
      );

      if (confirm == null) return;
      await _saveShippingAddress(setAsDefault: confirm);
    } else {
      await _saveShippingAddress(setAsDefault: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Shipping Address"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTextField("Full Name", _fullNameController, textInputType: TextInputType.name),
            const SizedBox(height: 16),
            _buildPhoneField(), // NEW
            const SizedBox(height: 16),
            _buildTextField("Address", _addressController, textInputType: TextInputType.streetAddress),
            const SizedBox(height: 16),
            _buildTextField("City", _cityController, textInputType: TextInputType.text),
            const SizedBox(height: 16),
            _buildRegionDropdown(),
            const SizedBox(height: 16),
            _buildTextField("Country", _countryController, textInputType: TextInputType.text),
            const SizedBox(height: 16),
            _buildTextField("Zip Code", _zipCodeController, textInputType: TextInputType.number),
            const SizedBox(height: 24),
            Row(
              children: [
                Checkbox(
                  value: isDefault,
                  onChanged: (value) => setState(() => isDefault = value ?? false),
                ),
                const Text("Use as the shipping address"),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _handleAddAddress,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text("Save Address", style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType? textInputType}) {
    return TextField(
      controller: controller,
      keyboardType: textInputType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
    );
  }

  // NEW: specialized phone field with helpful keyboard + input formatting
  Widget _buildPhoneField() {
    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s\(\)]')),
      ],
      decoration: InputDecoration(
        labelText: "Phone Number *",
        hintText: "+233541234567 or 0541234567",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
    );
  }
}
