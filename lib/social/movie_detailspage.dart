import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

import 'chewie_video_player_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'movie_comment.dart';

class MovieDetailsScreen extends StatefulWidget {
  final String movieId;

  const MovieDetailsScreen({super.key, required this.movieId});

  @override
  _MovieDetailsScreenState createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  bool _isLiked = false; // Track whether the user has liked the movie

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      // appBar: AppBar(
      //   backgroundColor: Colors.transparent,
      //   elevation: 0,
      //   leading: IconButton(
      //     icon: const Icon(Icons.arrow_back, color: Colors.white),
      //     onPressed: () {
      //       Navigator.pop(context);
      //     },
      //   ),
      //   iconTheme: const IconThemeData(color: Colors.white),
      // ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('movies')
            .doc(widget.movieId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Movie not found',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final movie = snapshot.data!;
          final String imageUrl = movie['image'] ?? '';
          final String title = movie['moviestitle'] ?? 'Unknown Title';
          final String category = movie['moviescat'] ?? 'Unknown Category';
          final String actors = movie['moviesactors'] ?? 'Unknown Actors';
          final String description =
              movie['moviesdescription'] ?? 'No description available.';
          final int viewCount = movie['viewscount'] ?? 0;
          final int likeCount = (movie['likes'] as List<dynamic>?)?.length ?? 0;
          final String movieTrailerUrl = movie['movieslocation'] ?? '';
          final int commentCount = movie['commentcount'] ?? 0;

          // Check if the current user has liked the movie
          final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
          if (userId.isNotEmpty) {
            _isLiked =
                (movie['likes'] as List<dynamic>?)?.contains(userId) ?? false;
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Image.network(
                      imageUrl,
                      height: MediaQuery.of(context).size.height *
                          0.40, // 40% of the screen height
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 40.0, // Adjust for spacing from the top
                      left: 16.0, // Adjust for spacing from the left
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context); // Navigate back
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(
                                0.6), // Semi-transparent background
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white, // White back arrow
                            size: 24.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(), // Convert the text to uppercase
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SizedBox(
                            width: screenWidth * 0.5,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Navigate to VideoPlayerScreen when "Watch Trailer" is tapped
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ChewieVideoPlayerScreen(
                                            trailerUrl: movieTrailerUrl,
                                            movietitle: title),
                                  ),
                                );

                                _incrementViewCount(movie.id);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: const Icon(Icons.play_circle,
                                  color: Colors.white),
                              label: const Text(
                                'Watch Trailer',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        category,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isLiked
                                      ? Icons.thumb_up
                                      : Icons.thumb_up_off_alt,
                                  color: _isLiked ? Colors.blue : Colors.white,
                                ),
                            //amended 10 04 2025
                            onPressed: () {
  var firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please sign in or create an account to like a movie'),
        duration: Duration(seconds: 2),
      ),
    );
    return; // Stop execution if user is not signed in
  }

  // Proceed if user is signed in
  _toggleLike(movie.id, _isLiked);
  setState(() {
    _isLiked = !_isLiked; // Toggle the state
  });
},

                              ),
                              //  const SizedBox(width: 4),
                              Text('$likeCount',
                                  style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Row(
                            children: [
                              const Icon(Icons.visibility,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 4),
                              Text('$viewCount',
                                  style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                          const Spacer(),
                         //amended 10 04 2025
                         IconButton(
  icon: const Icon(
    Icons.comment,
    color: Colors.white,
    size: 19,
  ),
  onPressed: () {
    var firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in or create an account to view or post comments'),
          duration: Duration(seconds: 2),
        ),
      );
      return; // Stop navigation if not signed in
    }

    // Navigate if user is signed in
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MoviesCommentPage(movie.id),
      ),
    );
  },
),

                          //  const SizedBox(width: 4),
                          Text('$commentCount',
                              style: const TextStyle(color: Colors.white)),
                          IconButton(
                            icon: const FaIcon(
                              FontAwesomeIcons.shareFromSquare,
                              color: Colors.white,
                              size: 18, // Set icon size to 16
                            ),
                            onPressed: () {
                              // Handle share button click
                              _shareMovie(title, movieTrailerUrl, imageUrl);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Cast & Crew',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        actors,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Toggle like/unlike status for the movie
  /*commented 18 03 2025
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
  }*/

  void _toggleLike(String movieId, bool isLiked) async {
  final user = FirebaseAuth.instance.currentUser;

  // Check if user is signed in
  if (user == null) {
    print("User is not signed in");
    return;
  }

  final userId = user.uid;
  final movieRef = FirebaseFirestore.instance.collection('movies').doc(movieId);

  try {
    if (isLiked) {
      await movieRef.update({
        'likes': FieldValue.arrayRemove([userId])
      });
    } else {
      await movieRef.update({
        'likes': FieldValue.arrayUnion([userId])
      });
    }
  } catch (e) {
    print("Error updating likes: $e");
  }
}


  // Share the movie to other platforms
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
}

void _incrementViewCount(String movieId) async {
  final movieRef = FirebaseFirestore.instance.collection('movies').doc(movieId);
  final movieSnapshot = await movieRef.get();
  if (movieSnapshot.exists) {
    final currentViewCount = movieSnapshot['viewscount'] ?? 0;
    await movieRef.update({'viewscount': currentViewCount + 1});
  }
}
