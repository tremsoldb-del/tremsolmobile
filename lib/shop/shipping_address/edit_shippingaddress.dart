import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  late final TextEditingController _fullnameController;
  late final TextEditingController _phoneController;   // NEW
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _regionController;
  late final TextEditingController _countryController;
  late final TextEditingController _zipcodeController;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fullnameController = TextEditingController();
    _phoneController = TextEditingController();        // NEW
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _regionController = TextEditingController();
    _countryController = TextEditingController();
    _zipcodeController = TextEditingController();
    _fetchAddressData();
  }

  // --- Phone validation helpers (same logic as Add page) ---
  bool _isValidPhone(String input) {
    // Normalize (remove spaces, dashes, parentheses)
    final normalized = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // General E.164-like (optional +, 8–15 digits, cannot start with 0 after +)
    final e164ish = RegExp(r'^\+?[1-9]\d{7,14}$');

    // Ghana local format (0XXXXXXXXX) – 10 digits starting with 0
    final ghLocal = RegExp(r'^0\d{9}$');

    // Ghana E.164 (+233XXXXXXXXX) – +233 followed by 9 digits
    final ghE164 = RegExp(r'^\+233\d{9}$');

    return e164ish.hasMatch(normalized) ||
        ghLocal.hasMatch(normalized) ||
        ghE164.hasMatch(normalized);
  }

  Future<void> _fetchAddressData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shippingaddress')
          .doc(widget.addressId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _fullnameController.text = data['fullname'] ?? '';
          _phoneController.text = data['phone'] ?? '';         // NEW
          _addressController.text = data['address'] ?? '';
          _cityController.text = data['city'] ?? '';
          _regionController.text = data['region'] ?? '';
          _countryController.text = data['country'] ?? '';
          _zipcodeController.text = data['zipcode'] ?? '';
          isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Address not found!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      // ignore: avoid_print
      print("Error fetching address: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error fetching address data.")),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _showRegionPicker() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('regions')
          .doc('regions')
          .get();

      if (doc.exists) {
        final List<dynamic> regionList = doc['name'] ?? [];
        if (regionList.isNotEmpty) {
          // ignore: use_build_context_synchronously
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text("Select Region"),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: regionList.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(regionList[index]),
                        onTap: () {
                          setState(() {
                            _regionController.text = regionList[index];
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              );
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No regions available!")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Regions data not found!")),
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print("Error fetching regions: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error fetching regions.")),
      );
    }
  }

  Future<void> _updateAddress() async {
    // Trim input values
    final fullName = _fullnameController.text.trim();
    final phone = _phoneController.text.trim();                 // NEW
    final address = _addressController.text.trim();
    final city = _cityController.text.trim();
    final region = _regionController.text.trim();
    final country = _countryController.text.trim();
    final zipCode = _zipcodeController.text.trim();

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
      _showError(
          "Enter a valid phone number (e.g., +233541234567 or 0541234567).");
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

    if (region.isEmpty) {
      _showError("Region cannot be empty.");
      return;
    }
    if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(region)) {
      _showError("Region can only contain letters and spaces.");
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
      await FirebaseFirestore.instance
          .collection('shippingaddress')
          .doc(widget.addressId)
          .update({
        'fullname': fullName,
        'phone': phone,                // NEW
        'address': address,
        'city': city,
        'region': region,
        'country': country,
        'zipcode': zipCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Address updated successfully!")),
      );

      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    } catch (e) {
      // ignore: avoid_print
      print("Error updating address: $e");
      _showError("Error updating address. Please try again.");
    }
  }

  // Function to display error messages
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _phoneController.dispose();        // NEW
    _addressController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _countryController.dispose();
    _zipcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Shipping Address"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _fullnameController,
              decoration: const InputDecoration(labelText: "Full Name"),
              textInputAction: TextInputAction.next,
            ),
            // NEW: phone field (required)
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(
                  RegExp(r'[0-9+\-\s\(\)]'),
                ),
              ],
              decoration: const InputDecoration(
                labelText: "Phone Number *",
                hintText: "+233541234567 or 0541234567",
              ),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: "Address"),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: "City"),
              textInputAction: TextInputAction.next,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _regionController,
                    decoration: const InputDecoration(labelText: "Region"),
                    readOnly: true,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _showRegionPicker,
                  tooltip: "Pick Region",
                ),
              ],
            ),
            TextField(
              controller: _countryController,
              decoration: const InputDecoration(labelText: "Country"),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _zipcodeController,
              decoration: const InputDecoration(labelText: "Zipcode"),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateAddress,
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}
