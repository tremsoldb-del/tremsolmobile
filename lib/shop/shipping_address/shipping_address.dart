import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'add_shipping_address.dart';
import 'edit_shippingaddress.dart';

class ShippingAddressesPage extends StatefulWidget {
  const ShippingAddressesPage({super.key});

  @override
  State<ShippingAddressesPage> createState() => _ShippingAddressesPageState();
}

class _ShippingAddressesPageState extends State<ShippingAddressesPage> {
  late final String userId;
  String selectedAddressId = "";

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser!.uid;
  }

  Future<void> _setDefaultAddress(String addressId) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('shippingaddress')
          .where('uid', isEqualTo: userId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in query.docs) {
        batch.update(doc.reference, {'isDefault': doc.id == addressId});
      }
      await batch.commit();

      setState(() {
        selectedAddressId = addressId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default shipping address updated.')),
      );
    } catch (e) {
      // ignore: avoid_print
      print("Error setting default address: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to set default address.')),
      );
    }
  }

  Future<void> _callNumber(String? rawPhone) async {
    final phone = (rawPhone ?? '').trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number found for this address.')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch dialer.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Shipping Addresses"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shippingaddress')
            .where('uid', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No shipping addresses yet.'));
          }

       // Make sure this is strongly typed
final addresses = snapshot.data!.docs;

// Preselect the default address for the Radio UI
if (selectedAddressId.isEmpty) {
  // 1) filter all docs where isDefault == true
  final defaultDocs = addresses.where((d) {
    final data = d.data() as Map<String, dynamic>;
    return data['isDefault'] == true;
  }).toList();

  // 2) choose the first default if any; otherwise just use first address
  final def = defaultDocs.isNotEmpty ? defaultDocs.first : addresses.first;

  selectedAddressId = def.id;
}


          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final doc = addresses[index];
              final data = doc.data() as Map<String, dynamic>;
              final addressId = doc.id;

              final fullname = (data['fullname'] ?? '') as String;
              final address = (data['address'] ?? '') as String;
              final city = (data['city'] ?? '') as String;
              final region = (data['region'] ?? '') as String;
              final country = (data['country'] ?? '') as String;
              final zipcode = (data['zipcode'] ?? '') as String;
              final phone = (data['phone'] ?? '') as String;
              final isDefault = (data['isDefault'] ?? false) as bool;

              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    leading: Radio<String>(
                      value: addressId,
                      groupValue: selectedAddressId,
                      onChanged: (val) {
                        if (val != null && val != selectedAddressId) {
                          _setDefaultAddress(val);
                        }
                      },
                    ),
                    // If you prefer the original checkbox:
                    // leading: Checkbox(
                    //   value: isDefault,
                    //   onChanged: (value) {
                    //     if (value == true) _setDefaultAddress(addressId);
                    //   },
                    // ),

                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            fullname.isEmpty ? 'Unnamed' : fullname,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (isDefault)
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Chip(
                              label: Text('Default'),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$address, $city, $region, $country"
                            "${zipcode.isNotEmpty ? ' - $zipcode' : ''}",
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  phone.isEmpty ? '—' : phone,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                            /*  IconButton(
                                tooltip: 'Call',
                                icon: const Icon(Icons.call),
                                onPressed: () => _callNumber(phone),
                              ),*/
                            ],
                          ),
                        ],
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EditShippingAddressPage(addressId: addressId),
                          ),
                        );
                      },
                      child: const Text(
                        "Edit",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddShippingAddressPage(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
