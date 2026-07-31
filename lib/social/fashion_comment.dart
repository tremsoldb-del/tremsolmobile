import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FashionCommentPage extends StatefulWidget {
  final String documentId;

  const FashionCommentPage(this.documentId, {super.key});

  @override
  _FashionCommentPageState createState() => _FashionCommentPageState();
}

class _FashionCommentPageState extends State<FashionCommentPage> {
  final TextEditingController commentController = TextEditingController();

 Future<void> addComment() async {
  final firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser == null || commentController.text.trim().isEmpty) return;

  DocumentSnapshot userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(firebaseUser.uid)
      .get();

  final userData = userDoc.data() as Map<String, dynamic>;

  // Use fullname if available, else fallback to username, else use 'Anonymous'
  final displayName = userData['fullname'] ??
                      userData['username'] ??
                      'Anonymous';

  await FirebaseFirestore.instance
      .collection('fashions')
      .doc(widget.documentId)
      .collection('comments')
      .add({
    'comment': commentController.text,
    'username': displayName,
    'uid': userData['uid'] ?? firebaseUser.uid,
    'profilepic': userData['profilepic'] ?? '',
    'time': FieldValue.serverTimestamp(),
  });

  DocumentSnapshot jobDoc = await FirebaseFirestore.instance
      .collection('fashions')
      .doc(widget.documentId)
      .get();

  int currentCommentCount = jobDoc['commentcount'] ?? 0;

  await FirebaseFirestore.instance
      .collection('fashions')
      .doc(widget.documentId)
      .update({'commentcount': currentCommentCount + 1});

  commentController.clear();
}

 Future<void> deleteComment(String commentId) async {
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Delete Comment"),
      content: const Text("Are you sure you want to delete this comment?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Delete"),
        ),
      ],
    ),
  );

  if (shouldDelete == true) {
    final docRef = FirebaseFirestore.instance.collection('fashions').doc(widget.documentId);
    final commentRef = docRef.collection('comments').doc(commentId);

    await commentRef.delete();

    final snapshot = await docRef.get();
    int currentCount = snapshot['commentcount'] ?? 1;
    await docRef.update({'commentcount': currentCount - 1});
  }
}

  void showEditDialog(DocumentSnapshot commentDoc) {
    final editController = TextEditingController(text: commentDoc['comment']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextFormField(
          controller: editController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Update your comment'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('fashions')
                  .doc(widget.documentId)
                  .collection('comments')
                  .doc(commentDoc.id)
                  .update({
                'comment': editController.text,
                'time': FieldValue.serverTimestamp(),
              });
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  String getTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('yMMMd').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('fashions')
                  .doc(widget.documentId)
                  .collection('comments')
                  .orderBy('time', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final commentData = comments[index];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.white,
                        backgroundImage:
                            NetworkImage(commentData['profilepic']),
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            commentData['username'],
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            commentData['comment'],
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      subtitle: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            getTimeAgo(commentData['time'] ?? Timestamp.now()),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                          if (currentUser != null &&
                              commentData['uid'] == currentUser.uid)
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => showEditDialog(commentData),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18),
                                  onPressed: () =>
                                      deleteComment(commentData.id),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(),
         SafeArea(
  minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 150, // Set a reasonable max height
          ),
          child: TextField(
            controller: commentController,
            maxLines: null, // Allows it to grow vertically
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText: "Add a comment...",
              hintStyle: TextStyle(fontSize: 15),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      OutlinedButton(
        onPressed: addComment,
        child: const Text(
          "Publish",
          style: TextStyle(fontSize: 13),
        ),
      ),
    ],
  ),
),

        ],
      ),
    );
  }
}
