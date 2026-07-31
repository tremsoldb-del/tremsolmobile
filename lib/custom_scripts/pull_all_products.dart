import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  _ProductsPageState createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  int selectedYear = DateTime.now().year; // Default to current year
  List<int> years = List.generate(10, (index) => DateTime.now().year - index);

  Stream<QuerySnapshot> getProductsByYear(int year) {
    return FirebaseFirestore.instance
        .collection('products')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(year, 1, 1)))
        .where('createdAt',
            isLessThan: Timestamp.fromDate(DateTime(year + 1, 1, 1)))
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Products from $selectedYear")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<int>(
              value: selectedYear,
              onChanged: (int? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedYear = newValue;
                  });
                }
              },
              items: years.map((year) {
                return DropdownMenuItem<int>(
                  value: year,
                  child: Text(year.toString()),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getProductsByYear(selectedYear),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                      child: Text("No products found for $selectedYear"));
                }
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['productname'] ?? 'Unnamed Product'),
                      subtitle: Text("Price: ${data['productsellingprice'] ?? 'N/A'}"),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailsPage(
                              productId: doc.id, // Pass the document ID
                              product: data,
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProductDetailsPage extends StatelessWidget {
  final String productId;
  final Map<String, dynamic> product;

  const ProductDetailsPage({super.key, required this.productId, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(product['productname'] ?? 'Product Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            ListTile(
              title: const Text("Document ID"),
              subtitle: Text(productId), // Display the document ID
            ),
            ...product.entries.map((entry) {
              return ListTile(
                title: Text(entry.key),
                subtitle: Text(entry.value.toString()),
              );
            }),
          ],
        ),
      ),
    );
  }
}
