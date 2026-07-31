import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'fashion_detail_page.dart';

class FashionVerticalListPage extends StatelessWidget {
  final String selectedFashionId;
  final List<QueryDocumentSnapshot> fashions;

  const FashionVerticalListPage({
    super.key,
    required this.selectedFashionId,
    required this.fashions,
  });

  @override
  Widget build(BuildContext context) {
    // Find the index of the selected item
    final initialIndex =
        fashions.indexWhere((item) => item.id == selectedFashionId);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Fashion Gallery",
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView.builder(
        controller: ScrollController(
          initialScrollOffset:
              initialIndex * MediaQuery.of(context).size.height * 0.85,
        ),
        itemCount: fashions.length,
        itemBuilder: (context, index) {
          final fashionItem = fashions[index];
          final imageUrl = fashionItem['image'];

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FashionDetailPage(
                    fashionId: fashionItem.id,
                  ),
                ),
              );
            },
            child: Stack(
              children: [
                // Background Image with Near Full-Screen Size
                Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height *
                      0.85, // Covers most of the screen
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Overlay with gradient
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Centered Text
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: Text(
                    fashionItem['fashiontitle'] ?? 'Fashion Item',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
