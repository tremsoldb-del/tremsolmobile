import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tremsolapp/social/fashion_detail_page.dart';
import 'package:tremsolapp/social/jobdetailsscreen.dart';
import 'package:tremsolapp/social/movie_detailspage.dart';

import 'package:url_launcher/url_launcher.dart';


class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  _FavoritePageState createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  final _auth = FirebaseAuth.instance;
  final List<String> categories = ['movies', 'jobs', 'fashions', 'games'];

  Future<List<DocumentSnapshot>> fetchFavoriteItems(String category) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection(category)
        .where('likes', arrayContains: userId)
        .get();

    return querySnapshot.docs;
  }

  void _removeFromFavorites(String category, String docId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove from Favorites"),
        content: const Text(
            "Are you sure you want to remove this item from favorites?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text("Remove"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection(category).doc(docId).update({
        'likes': FieldValue.arrayRemove([userId])
      });
      setState(() {});
    }
  }

  void _incrementViewCount(String gameId) {
    FirebaseFirestore.instance.collection('games').doc(gameId).update({
      'viewscount': FieldValue.increment(1),
    });
  }



Widget buildFavoriteItem(String category, DocumentSnapshot item) {
  String title;
  String? imageUrl = item['image'];
  //String id = item['id'];
  String id = item.id; // Use document ID instead of relying on `data['id']`

  switch (category) {
    case 'fashions':
      title = item['fashiontitle'] ?? 'No title';
      break;
    case 'jobs':
      title = item['jobtitle'] ?? 'No title';
      break;
    case 'games':
      title = item['gametitle'] ?? 'No title';
      break;
    case 'movies':
      title = item['moviestitle'] ?? 'No title';
      break;
    default:
      title = 'Unknown';
  }

  return Card(
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imageUrl != null
            ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover)
            : const Icon(Icons.image, size: 60, color: Colors.grey),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete, color: Colors.black54),
        onPressed: () => _removeFromFavorites(category, item.id),
      ),
   onTap: () {
  if (!item.exists) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Item no longer exists.")),
    );
    return;
  }

  if (category == 'jobs') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailsPage(jobId: id),
      ),
    );
  } else if (category == 'movies') {
    Navigator.push(
      context,
      MaterialPageRoute(
        //amended 13 04 2025
        builder: (context) => MovieDetailsScreen(movieId: id),
      ),
    );
  } else if (category == 'fashions') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FashionDetailPage(fashionId: id),
      ),
    );
  } else if (category == 'games') {
    final gameUrl = item['gamelocation'];
    if (gameUrl != null) {
      launch(gameUrl);
      _incrementViewCount(item['id']);
    }
  }
},

    ),
  );
}

  Widget buildShimmer() {
    return ListView.builder(
      itemCount: 6,
      shrinkWrap: true,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            leading: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
              ),
            ),
            title: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: 120,
                height: 20,
                color: Colors.grey[300],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Favorites",
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        /*   flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              //colors: [Colors.blue, Colors.purple],
              colors: [const Color(0xFF002A5C), Color(0xFF004D99)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),*/
        backgroundColor: const Color(0xFF002A5C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
       
        ),
        child: SingleChildScrollView(
          child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
            children: categories.map((category) {
              return FutureBuilder<List<DocumentSnapshot>>(
                future: fetchFavoriteItems(category),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return buildShimmer();
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(left:25,right:8.0,top:8,bottom:8),
                      child: Text(
                        "No items in $category favorites.",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 17.0),
                          child: Text(
                            category.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            var item = snapshot.data![index];
                            return buildFavoriteItem(category, item);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() {}),
        backgroundColor: Colors.purple,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}
