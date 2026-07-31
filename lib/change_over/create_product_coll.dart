import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class InsertProductsPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String imageUrl =
      "https://drive.google.com/drive/folders/1MHWJNC-1dr9zekH6GYQSAHcatmbD7_cJ";
  final List<String> tags = ["Flash", "Weekly", "Trending", "Bulk", "Special"];

   InsertProductsPage({super.key});

  void insertProducts() async {
    var uuid = const Uuid();
    for (int i = 0; i < 10; i++) {
      String productId = uuid.v4();
      await _firestore.collection('products').doc(productId).set({
        "id": productId,
        "productname": "Sample Product $i",
        "productdescription": "Description for Sample Product $i",
        "productcategory": "Category $i",
        "rating": (i % 5) + 1,
        "productminquantity": 1,
        "cost_per_item": (10 + i).toString(),
        "productcustomers": [],
        "productstate": "Available",
        "productlocation": "Location $i",
        "createdAt": Timestamp.now(),
        "uid": uuid.v4(),
        "productsubcat": "Subcategory $i",
        "international_shipping": null,
        "productcompany": "Company $i",
        "product_sizes": ["S", "M", "L"],
        "supplier_name": "Supplier $i",
        "productsellingprice": (20 + i),
        "productdiscprice": (18 + i).toString(),
        "updatedAt": Timestamp.now(),
        "likes": [],
        "image": imageUrl,
        "images": [imageUrl],
        "delivery_days": 3,
        "tax": null,
        "delivery_date": Timestamp.now(),
        "commentcount": 0,
        "producttag": tags,
        "productquantity": 100 - (i * 5),
        "product_colors": ["Red", "Blue", "Green"],
        "local_shipping_fee": "5.00",
        "isPublish": true,
        "productdiscountper": "10%",
        "video_url": "https://example.com/video$i.mp4"
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insert Sample Products')),
      body: Center(
        child: ElevatedButton(
          onPressed: insertProducts,
          child: const Text('Insert Products'),
        ),
      ),
    );
  }
}
