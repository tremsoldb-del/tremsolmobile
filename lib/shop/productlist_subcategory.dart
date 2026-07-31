import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'product_details_screen.dart';

class ProductListSubCatPage extends StatefulWidget {
  final String subcatName;
  final String subcatId;
  

  const ProductListSubCatPage({super.key, required this.subcatName, required this.subcatId});

  @override
  State<ProductListSubCatPage> createState() => _ProductListSubCatPageState();
}

class _ProductListSubCatPageState extends State<ProductListSubCatPage> {

  String _capitalizeFirstLetter(String input) {
    if (input.isEmpty) return ''; // Handle empty string case

    return input
        .split(' ')
        .where((word) => word.isNotEmpty) // Ensure empty words are removed
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.subcatName,
          style: const TextStyle(
              fontSize: 18,
              // fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        backgroundColor:
            const Color(0xFF002f6c), // Blue color to match branding
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('productsubcat', isEqualTo: widget.subcatId)
            .where('isPublish', isEqualTo: true)        // <- only published
             .orderBy('createdAt', descending: true) // Order by latest first
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = snapshot.data!.docs;
          if (products.isEmpty) {
            return const Center(
              child: Text(
                'No products found in this category.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2 / 3,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProductDetailsScreen(productId: product.id),
                      ),
                    );
                  },
                  child: _buildProductItem(
                    context,
                    product['productname'],
                    product['image'],
                    product['productsellingprice'],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadCurrencyData();
  }

  // Variables for currency data
  String? currencySymbol;

  double? exchangeRate;

 bool _currencyLoaded = false;

Future<void> _loadCurrencyData() async {
  final prefs = await SharedPreferences.getInstance();

  final base = prefs.getString('baseCurrency') ?? 'GHS';
  final selected = prefs.getString('selectedCurrency') ?? base;
  final rate = prefs.getDouble('conversionRate') ?? 1.0;

  setState(() {
    currencySymbol = selected;  // 👈 show user’s chosen currency code
    exchangeRate = rate;        // 👈 base → selected
    _currencyLoaded = true;
  });
}


  double _convertPrice(double price) {
    return exchangeRate != null ? price * exchangeRate! : price;
  }

  Widget _buildProductItem(BuildContext context, String productName,
      String imageUrl, num productsellingprice) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              height: 150,
              width: double.infinity,
              fit: BoxFit.contain,
              fadeInDuration: const Duration(milliseconds: 120),
              placeholder: (context, url) => Container(
                height: 150,
                color: Colors.grey.shade100,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 150,
                color: Colors.grey.shade100,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined, size: 42),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Product Name
        Text(
               _capitalizeFirstLetter(productName),
          
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 0),
        // Product Price with converted value and currency symbol
        Text(
          '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(productsellingprice.toDouble()))}',
         // '${currencySymbol ?? "\$"} ${_convertPrice(productsellingprice.toDouble()).toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
