import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InsertCategoriesPage extends StatelessWidget {
  const InsertCategoriesPage({super.key});

  Future<void> insertCategories() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final FirebaseAuth auth = FirebaseAuth.instance;
    final String uid = auth.currentUser?.uid ?? 'default_uid';

    List<Map<String, dynamic>> categories = List.generate(12, (index) {
      DocumentReference docRef = firestore.collection('productscategory').doc();
      return {
        "id": docRef.id,
        "productscategory": "Category $index",
        "image":
            "https://fastly.picsum.photos/id/866/200/300.jpg?hmac=rcadCENKh4rD6MAp6V_ma-AyWv641M4iiOpe1RyFHeI", // Replace with actual image URLs
        "createdAt": FieldValue.serverTimestamp(),
        "isPublish": false,
        "uid": uid,
      };
    });

    WriteBatch batch = firestore.batch();
    for (var category in categories) {
      DocumentReference docRef =
          firestore.collection('productscategory').doc(category['id']);
      batch.set(docRef, category);
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insert Categories')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await insertCategories();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('12 categories inserted successfully')),
            );
          },
          child: const Text('Insert Categories'),
        ),
      ),
    );
  }
}
