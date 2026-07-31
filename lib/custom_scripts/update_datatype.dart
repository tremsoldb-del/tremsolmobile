import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UpdateproductsellingpricePage extends StatefulWidget {
  const UpdateproductsellingpricePage({super.key});

  @override
  _UpdateproductsellingpricePageState createState() => _UpdateproductsellingpricePageState();
}

class _UpdateproductsellingpricePageState extends State<UpdateproductsellingpricePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isUpdating = false;

  Future<void> updateproductsellingprices() async {
    setState(() {
      _isUpdating = true;
    });

    try {
      QuerySnapshot querySnapshot =
          await _firestore.collection("products").get();

      for (var doc in querySnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        // Ensure createdAt exists and is a Timestamp
        if (data.containsKey('createdAt') && data['createdAt'] is Timestamp) {
          DateTime createdAt = (data['createdAt'] as Timestamp).toDate();

          // Check if the year is 2025
          if (createdAt.year == 2025) {
            var productsellingprice = data['productsellingprice'];

            // Convert only if productsellingprice is a String
            if (productsellingprice is String) {
              double? newPrice = double.tryParse(productsellingprice);

              if (newPrice != null) {
                await _firestore.collection("products").doc(doc.id).update({
                  'productsellingprice': newPrice,
                });
              }
            }
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Product prices updated successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating prices: $e")),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Update Product Prices")),
      body: Center(
        child: _isUpdating
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: updateproductsellingprices,
                child: const Text("Update Prices"),
              ),
      ),
    );
  }
}
