import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'movie_detailspage.dart';
import 'movie_search.dart';
import 'movies_screen_category.dart';

class MoviesScreen extends StatelessWidget {
  const MoviesScreen({super.key});

  void _navigateToCategory(BuildContext context, String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MoviesByCategoryScreen(category: category),
      ),
    );
  }

  Future<void> _shareMovie(
      String title, String videoUrl, String imageUrl) async {
    const appName = "Tremsol"; // Replace with your app's name

    final shareText =
        "\uD83C\uDFAC Check out this awesome movie: $title!\n\n\uD83C\uDF1F Watch now on $appName!\n\n";

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/shared_movie_image.jpg';

        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        await Share.shareFiles(
          [filePath],
          text:
              "$shareText\uD83D\uDC49 Don't miss out on this amazing movie experience!",
          subject: "\uD83C\uDFAC Movie Alert: $title - Watch Now!",
        );
      } else {
        throw Exception('Failed to load movie image');
      }
    } catch (e) {
      print('Error sharing movie: $e');
    }
  }

  void _incrementViewCount(String movieId) async {
    final movieRef =
        FirebaseFirestore.instance.collection('movies').doc(movieId);
    final movieSnapshot = await movieRef.get();
    if (movieSnapshot.exists) {
      final currentViewCount = movieSnapshot['viewscount'] ?? 0;
      await movieRef.update({'viewscount': currentViewCount + 1});
    }
  }

  void _toggleLike(String movieId, bool isLiked) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final movieRef =
        FirebaseFirestore.instance.collection('movies').doc(movieId);

    if (isLiked) {
      await movieRef.update({
        'likes': FieldValue.arrayRemove([userId])
      });
    } else {
      await movieRef.update({
        'likes': FieldValue.arrayUnion([userId])
      });
    }
  }

  void _showMovieDetails(BuildContext context, String category, String actors,
      String description) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black87,
          title: const Text("Movie Details",
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Category: $category",
                    style: const TextStyle(color: Colors.white)),
                Text("Actors: $actors", style: const TextStyle(color: Colors.white)),
                Text("Description: $description",
                    style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Close", style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Movies',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MovieSearchPage()),
              );
            },
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GestureDetector(
              onTap: () {
                // Navigate to the MovieSearchPage when tapped
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MovieSearchPage()),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'Find movies, shows, and more',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          StreamBuilder(
            stream: FirebaseFirestore.instance.collection('movies').snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white)),
                );
              }

              final movies = snapshot.data?.docs ?? [];
              final categories = [
                'All',
                ...movies
                    .map((doc) => doc['moviescat'])
                    .where((cat) => cat != null && cat.isNotEmpty)
                    .toSet()
                    
              ];

              if (categories.isEmpty) {
                return const SizedBox();
              }

              return SizedBox(
                height: 35,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = index == 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: GestureDetector(
                        onTap: () => _navigateToCategory(context, category),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue : Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder(
              stream:
                  FirebaseFirestore.instance.collection('movies').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white)));
                }

                final movies = snapshot.data?.docs ?? [];

                return GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    mainAxisSpacing: 12.0,
                    crossAxisSpacing: 12.0,
                  ),
                  itemCount: movies.length,
                  itemBuilder: (context, index) {
                    final movie = movies[index];
                    final imageUrl = movie['image'];
                    final videoUrl = movie['movieslocation'];
                    final movieTitle = movie['moviestitle'];
                    final movieCategory = movie['moviescat'] ?? "Unknown";
                    final movieActors = movie['moviesactors'] ?? "Unknown";
                    final movieDescription =
                        movie['moviesdescription'] ?? "Unknown";
                    final viewCount = movie['viewscount'] ?? 0;
                    final commentCount = movie['commentcount'] ?? 0;
                    final likes = movie['likes'] ?? [];

                    //added 12 03 2025
                    bool isLiked = FirebaseAuth.instance.currentUser != null &&
                        likes.contains(FirebaseAuth.instance.currentUser!.uid);

                    //commented 12 03 2025
                    /* bool isLiked =
                        likes.contains(FirebaseAuth.instance.currentUser!.uid);*/

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MovieDetailsScreen(movieId: movie.id),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15.0),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
          child: Icon(
            Icons.movie,
            color: Colors.grey.shade400,
            size: 50,
          ),
        ),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
