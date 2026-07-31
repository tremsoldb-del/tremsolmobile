import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UsersMissingUsernamePage extends StatefulWidget {
  const UsersMissingUsernamePage({super.key});

  @override
  _UsersMissingUsernamePageState createState() => _UsersMissingUsernamePageState();
}

class _UsersMissingUsernamePageState extends State<UsersMissingUsernamePage> {
  List<Map<String, dynamic>> _usersMissingUsername = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsersWithoutUsername();
  }

  Future<void> _fetchUsersWithoutUsername() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('users').get();

      final List<Map<String, dynamic>> missing = snapshot.docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return !data.containsKey('username');
          })
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'email': data['email'] ?? 'N/A',
              'fullname': data['fullname'] ?? 'N/A',
              'createdAt': data['createdAt']?.toDate().toString() ?? 'Unknown',
            };
          })
          .toList();

      setState(() {
        _usersMissingUsername = missing;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching users: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users Missing Username')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _usersMissingUsername.isEmpty
              ? const Center(child: Text("All users have a username."))
              : ListView.builder(
                  itemCount: _usersMissingUsername.length,
                  itemBuilder: (context, index) {
                    final user = _usersMissingUsername[index];
                    return ListTile(
                      leading: const Icon(Icons.person_off),
                      title: Text(user['fullname']),
                      subtitle: Text("Email: ${user['email']}"),
                      trailing: Text("Created: ${user['createdAt']}"),
                    );
                  },
                ),
    );
  }
}
