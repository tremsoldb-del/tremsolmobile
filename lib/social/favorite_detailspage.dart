import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FavoriteDetailPage extends StatelessWidget {
  final String category;
  final String id;

  const FavoriteDetailPage(
      {super.key, required this.category, required this.id});

  Future<DocumentSnapshot> fetchFavoriteDetails() async {
    return await FirebaseFirestore.instance.collection(category).doc(id).get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Details",
          style: TextStyle(
              // color: Colors.white,
              fontSize: 18),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: fetchFavoriteDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Item not found"));
          }

          var item = snapshot.data!;
          String title;
          String? imageUrl = item['image'];
          //  String description = item['description'] ?? "No description available.";
          String? additionalDetail;
          String? date;

          // Determine fields based on category
          switch (category) {
            case 'fashions':
              title = item['fashiontitle'] ?? 'No title';
              // additionalDetail = item['designer'] ?? "Designer info not available";
              date = item['createdAt'] ?? "No release date";
              break;
            case 'jobs':
              title = item['jobtitle'] ?? 'No title';
              //   additionalDetail = item['company'] ?? "Company info not available";
              date = item['createdAt'] ?? "No created date";
              break;
            case 'games':
              title = item['gametitle'] ?? 'No title';
              //  additionalDetail = item['developer'] ?? "Developer info not available";
              date = item['createdAt'] ?? "No release date";
              break;
            case 'movies':
              title = item['moviestitle'] ?? 'No title';
              // additionalDetail = item['director'] ?? "Director info not available";

              date = item['createdAt'] ?? "No release date";

              break;
            default:
              title = 'Unknown';
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: imageUrl != null
                        ? Image.network(imageUrl,
                            width: 300, height: 200, fit: BoxFit.cover)
                        : const Icon(Icons.image,
                            size: 200, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 10),
                // Text(
                //   description,
                //   style: TextStyle(
                //     fontSize: 16,

                //   ),
                // ),
                const SizedBox(height: 20),
                Divider(color: Colors.grey[400]),
                Row(
                  children: [
                    const Icon(Icons.date_range, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text(
                      "Date: $date",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text(
                      "Additional Info: $additionalDetail",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      // Action for additional functionality, e.g., sharing, saving, etc.
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Perform Action",
                      style: TextStyle(fontSize: 18),
                    ),
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
