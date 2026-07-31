import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PromoCodeCreatorPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sample data for the promo codes
  final List<Map<String, dynamic>> promoCodes = [
    {
      "code": "TESTPAY",
      "discountType": "percentage",
      "value": 99.5,
      "expiryDate": DateTime(2025, 12, 31),
      "usageLimit": 100,
      "usagePerUser": 100,
      "minOrderValue": 1.0,
      "isActive": true,
      "usersUsed": {},
    },
   /* {
      "code": "PAY10",
      "discountType": "fixed",
      "value": 10.0,
      "expiryDate": DateTime(2025, 6, 30),
      "usageLimit": 50,
      "usagePerUser": 1,
      "minOrderValue": 2.0,
      "isActive": true,
      "usersUsed": {},
    },*/
  ];

   PromoCodeCreatorPage({super.key});

  // Function to add promo codes to Firestore
  Future<void> addPromoCodes() async {
    final promoCodesCollection = _firestore.collection('promo_codes');
    for (var promoCode in promoCodes) {
      await promoCodesCollection.doc(promoCode['code']).set({
        "code": promoCode["code"],
        "discountType": promoCode["discountType"],
        "value": promoCode["value"],
        "expiryDate": promoCode["expiryDate"],
        "usageLimit": promoCode["usageLimit"],
        "usagePerUser": promoCode["usagePerUser"],
        "minOrderValue": promoCode["minOrderValue"],
        "isActive": promoCode["isActive"],
        "usersUsed": promoCode["usersUsed"],
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promo Code Creator'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await addPromoCodes();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Promo codes added to Firestore!')),
            );
          },
          child: const Text('Create Promo Codes'),
        ),
      ),
    );
  }
}
