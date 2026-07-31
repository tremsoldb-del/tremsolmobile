import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'fashion_comment.dart';

class FashionDetailPage extends StatefulWidget {
  final String fashionId;

  const FashionDetailPage({super.key, required this.fashionId});

  @override
  _FashionDetailPageState createState() => _FashionDetailPageState();
}

class _FashionDetailPageState extends State<FashionDetailPage> {
  bool isLiked = false;
  String appName = "This App";

  @override
  void initState() {
    super.initState();
    checkIfLiked();
    incrementViewCount();
    _loadAppName();
  }

  Future<void> _loadAppName() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      appName = packageInfo.appName;
    });
  }

 /*commented on 18 03 2025
 void checkIfLiked() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    DocumentSnapshot fashionItem = await FirebaseFirestore.instance
        .collection('fashions')
        .doc(widget.fashionId)
        .get();

    List likes = fashionItem['likes'] ?? [];
    if (likes.contains(userId)) {
      setState(() {
        isLiked = true;
      });
    }
  }*/

  void checkIfLiked() async {
  final user = FirebaseAuth.instance.currentUser;
  
  // Ensure user is not null
  if (user == null) {
    print("User is not signed in");
    return;
  }

  final userId = user.uid;

  DocumentSnapshot fashionItem = await FirebaseFirestore.instance
      .collection('fashions')
      .doc(widget.fashionId)
      .get();

  List likes = fashionItem['likes'] ?? [];
  if (likes.contains(userId)) {
    setState(() {
      isLiked = true;
    });
  }
}


/*commented on 18 03 2025
  void toggleLike() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final fashionRef =
        FirebaseFirestore.instance.collection('fashions').doc(widget.fashionId);

    if (isLiked) {
      await fashionRef.update({
        'likes': FieldValue.arrayRemove([userId])
      });
    } else {
      await fashionRef.update({
        'likes': FieldValue.arrayUnion([userId])
      });
    }

    setState(() {
      isLiked = !isLiked;
    });
  }*/

  void toggleLike() async {
  final user = FirebaseAuth.instance.currentUser;
  
  // Ensure the user is not null before accessing uid
  if (user == null) {
    print("User is not signed in");
    return;
  }

  final userId = user.uid;
  final fashionRef =
      FirebaseFirestore.instance.collection('fashions').doc(widget.fashionId);

  if (isLiked) {
    await fashionRef.update({
      'likes': FieldValue.arrayRemove([userId])
    });
  } else {
    await fashionRef.update({
      'likes': FieldValue.arrayUnion([userId])
    });
  }

  setState(() {
    isLiked = !isLiked;
  });
}


  void navigateToComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FashionCommentPage(widget.fashionId),
      ),
    );
  }

  void incrementViewCount() async {
    final fashionRef =
        FirebaseFirestore.instance.collection('fashions').doc(widget.fashionId);

    await fashionRef.update({
      'viewscount': FieldValue.increment(1),
    });
  }

  Future<void> shareFashion(String title, String imageUrl) async {
    const appName = "Tremsol";
    final catchySentence =
        "🔥 Discover the latest trends with $title on $appName! Elevate your style today. 👗✨\n\n";

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/shared_image.jpg';

        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        await Share.shareFiles(
          [filePath],
          text: "$catchySentence👉 Download $appName now to explore more!",
          subject: "Style Alert: $title is waiting for you on $appName!",
        );
      } else {
        throw Exception('Failed to load image');
      }
    } catch (e) {
      print('Error sharing fashion: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50], // Matches the outer blue margin
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('fashions')
            .doc(widget.fashionId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final fashionItem = snapshot.data!;
          final imageUrl = fashionItem['image'];
          final comments = fashionItem['commentcount'] ?? 0;
          final likes = fashionItem['likes']?.length ?? 0;
          final views = fashionItem['viewscount'] ?? 0;
          final fashionTitle = fashionItem['fashiontitle'] ?? 'Untitled';
          final fashionDescription = fashionItem['description'] ?? '';
          final fashionCompany = fashionItem['fashioncompany'] ?? '';
          final fashionTel = fashionItem['fashionlocation'] ?? '';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Section with Overlay
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(30),
                      ),
                      child: AspectRatio(
                        aspectRatio: 0.64, // Adjust this as needed
                        child: Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: MediaQuery.of(context).size.height *
                              0.4, // 40% of the screen height
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 40,
                      left: 16,
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),

                    /*
                    Positioned(
                      top: 40,
                      right: 16,
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: Colors.red,
                          ),
                          onPressed: toggleLike,
                        ),
                      ),
                    ),*/

                    Positioned(
                      bottom: 20,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fashionTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        color: Colors.white, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      fashionCompany,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.phone,
                                        color: Colors.white, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      fashionTel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Title and Details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /* Text(
                        fashionTitle,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),*/
                      //const SizedBox(height: 8),
                      /* Text(
                        fashionDescription,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),*/
                      const SizedBox(height: 16),
                      // Stats Row
                      Row(
                        // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            //amended 10 04 2025
                         onTap: () async {
  var firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please sign in or create an account to view or post comments'),
        duration: Duration(seconds: 2),
      ),
    );
    return; // Stop execution if user is not signed in
  }

  // User is signed in, navigate to comments
  navigateToComments();
},

                            child: Container(
                              padding: const EdgeInsets.all(4.0),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(6.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    spreadRadius: 2,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.comment,
                                  color: Colors.black, size: 20),
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Text(
                            '$comments', // Replace with your comment count variable
                            style: const TextStyle(
                              fontSize: 14.0,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                          GestureDetector(
                           
                           //amended 10 04 2025
                           onTap: () {
  var firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please sign in or create an account to like this item'),
        duration: Duration(seconds: 2),
      ),
    );
    return; // Stop if not signed in
  }

  // If signed in, proceed
  toggleLike();
},

                            child: Container(
                              padding: const EdgeInsets.all(4.0),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(6.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    spreadRadius: 2,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isLiked
                                    ? Icons.thumb_up
                                    : Icons
                                        .thumb_up_off_alt, // Change icon based on like status
                                color: isLiked
                                    ? Colors.blue
                                    : Colors.black, // Highlight if liked
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Text(
                            '$likes', // Replace with your comment count variable
                            style: const TextStyle(
                              fontSize: 14.0,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              const Icon(Icons.visibility, color: Colors.black),
                              const SizedBox(width: 4),
                              Text('$views'),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      ExpandableText(text: fashionDescription),
                      const SizedBox(height: 40),
                      // Book Now Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                        ),
                        onPressed: () {
                          shareFashion(fashionTitle, imageUrl);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment
                              .center, // Center the text and icon
                          children: [
                            IconButton(
                              icon: const FaIcon(
                                FontAwesomeIcons.shareFromSquare,
                                color: Colors.white,
                                size: 20, // Set icon size to 16
                              ),
                              onPressed: () {},
                            ),

                            const SizedBox(width: 8), // Space between icon and text
                            const Text(
                              'Share Style',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
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
}

//added 29-12-2024
class ExpandableText extends StatefulWidget {
  final String text;

  const ExpandableText({super.key, required this.text});

  @override
  _ExpandableTextState createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    const int characterLimit =
        100; // Limit for the number of characters before truncating

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isExpanded
              ? widget.text
              : (widget.text.length > characterLimit
                  ? '${widget.text.substring(0, characterLimit)}...'
                  : widget.text),
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        if (widget.text.length > characterLimit)
          TextButton(
            onPressed: () {
              setState(() {
                isExpanded = !isExpanded;
              });
            },
            child: Text(
              isExpanded ? "Show Less" : "Read More",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.blue,
              ),
            ),
          ),
      ],
    );
  }
}
