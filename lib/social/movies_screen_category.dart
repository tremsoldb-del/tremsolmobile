import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'movie_detailspage.dart';

class MoviesByCategoryScreen extends StatelessWidget {
  final String category;

  const MoviesByCategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Movies in $category",
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
        iconTheme: const IconThemeData(
            color: Colors.white), // Sets the back arrow color to white
      ),
      backgroundColor: Colors.black,
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('movies')
            .where('moviescat', isEqualTo: category)
            .snapshots(),
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
          if (movies.isEmpty) {
            return const Center(
              child: Text('No movies found in this category',
                  style: TextStyle(color: Colors.white)),
            );
          }

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
              final viewCount = movie['viewscount'] ?? 0;

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
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
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
    );
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
}
