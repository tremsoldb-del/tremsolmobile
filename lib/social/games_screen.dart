import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'game_search.dart';
import 'games_comment.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A2540),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2540),
        iconTheme: const IconThemeData(
            color: Colors.white), // Sets the back arrow color to white
        elevation: 0,
        // title: const Text(
        //   'Gameboard',
        //   style: TextStyle(
        //     color: Colors.white,
        //     // fontWeight: FontWeight.bold,
        //   ),
        // ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.search,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GameSearchPage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('games')
            .orderBy('viewscount',
                descending: true) // Use viewscount for top games
            .limit(3)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No games found',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            );
          }

          final topGames = snapshot.data!.docs;
          return Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                'Top 3 Games',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  topGames.length,
                  (index) {
                    final game = topGames[index].data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              launch(game['gamelocation']);
                              _incrementViewCount(game['id']);
                            },
                            child: CircleAvatar(
                              radius: 40,
                              backgroundImage: NetworkImage(game['image']),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            game['gametitle'],
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                          ),
                          Text(
                            '+${game['viewscount']} views',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('games')
                      .orderBy('viewscount', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No games available',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      );
                    }

                    final games = snapshot.data!.docs;
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: games.length,
                      itemBuilder: (context, index) {
                        final game =
                            games[index].data() as Map<String, dynamic>;
                        final userId = FirebaseAuth.instance.currentUser?.uid;
                        final isLiked =
                            (game['likes'] as List).contains(userId);

                        return Card(
                          color: const Color(0xFF122F46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            onTap: () {
                              launch(game['gamelocation']);
                              _incrementViewCount(game['id']);
                            },
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey[200],
                              backgroundImage:
                                  CachedNetworkImageProvider(game['image']),
                              // onBackgroundImageError: (_, __) {},
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: game['image'],
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Icon(
                                      Icons.videogame_asset,
                                      size: 20,
                                      color: Colors.grey),
                                  errorWidget: (context, url, error) => const Icon(
                                      Icons.videogame_asset,
                                      size: 20,
                                      color: Colors.grey),
                                ),
                              ),
                            ),
                            title: Text(
                              game['gametitle'],
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                            ),
                            subtitle: Row(
                              children: [
                                const Icon(Icons.remove_red_eye,
                                    color: Colors.grey, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${game['viewscount']}',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                                const SizedBox(width: 22),
                                GestureDetector(
                                  //amended 10 04 2025
                                  onTap: () async {
                                    var firebaseUser =
                                        FirebaseAuth.instance.currentUser;
                                    if (firebaseUser == null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Please sign in or create an account to view or post comments'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                      return; // Stop execution if user is not signed in
                                    }

                                    // User is signed in, navigate to comments
                                    navigateToComments(game['id'], context);
                                  },

                                  child: const Icon(Icons.comment,
                                      color: Colors.grey, size: 16),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${game['commentcount']}',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                                const SizedBox(width: 22),
                                IconButton(
                                  icon: const FaIcon(
                                    FontAwesomeIcons.shareFromSquare,
                                    color:
                                        Colors.grey, // Set icon color to grey
                                    size: 14, // Set icon size to 16
                                  ),
                                  onPressed: () {
                                    _shareGame(
                                      game['gametitle'],
                                      game['gamelocation'],
                                      game['image'],
                                    );
                                  },
                                ),
                                //amended 10 04 2025
                                IconButton(
                                  icon: Icon(
                                    isLiked
                                        ? Icons.thumb_up
                                        : Icons.thumb_up_off_alt,
                                    color: isLiked ? Colors.blue : Colors.grey,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    var firebaseUser =
                                        FirebaseAuth.instance.currentUser;
                                    if (firebaseUser == null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Please sign in or create an account to like this game'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                      return; // Stop if user is not signed in
                                    }

                                    // Proceed if signed in
                                    toggleLike(game['id'], isLiked);
                                  },
                                ),
                              ],
                            ),

                            /*commented 08 09 2025
                            trailing: IconButton(
                              icon: const Icon(Icons.play_circle_fill,
                                  color: Colors.green, size: 30),
                              onPressed: () {
                                launch(game['gamelocation']);
                                _incrementViewCount(game['id']);
                              },
                            ),
                            */
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void navigateToComments(String gameId, BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameCommentPage(gameId),
      ),
    );
  }

  void _incrementViewCount(String gameId) {
    FirebaseFirestore.instance.collection('games').doc(gameId).update({
      'viewscount': FieldValue.increment(1),
    });
  }

  Future<void> _shareGame(
      String title, String location, String imageUrl) async {
    final shareText = """
🎮 Discover amazing games on TremsolApp!

🏷 $title
📍 $location

🌟 Download TremsolApp now from the stores to explore more exciting games!

#TremsolApp #GamingMadeEasy
""";

    Share.share(shareText, subject: "Game Alert: $title");
  }

  void toggleLike(String gameId, bool isLiked) async {
    final user = FirebaseAuth.instance.currentUser;

    // Ensure user is signed in
    if (user == null) {
      print("User is not signed in");
      return;
    }

    final userId = user.uid;
    final gameRef = FirebaseFirestore.instance.collection('games').doc(gameId);

    try {
      if (isLiked) {
        await gameRef.update({
          'likes': FieldValue.arrayRemove([userId])
        });
      } else {
        await gameRef.update({
          'likes': FieldValue.arrayUnion([userId])
        });
      }
    } catch (e) {
      print("Error updating likes: $e");
    }
  }
}
