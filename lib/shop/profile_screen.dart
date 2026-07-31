import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tremsolapp/auth/auth_gate.dart';


import '../auxilliary/in-app-firestore/fbnotification_screen.dart';
import '../chat/mainscreen.dart';
import '../currency/currencysel.dart';
import 'orderpage.dart';
import 'shipping_address/shipping_address.dart';
import 'user_profile.dart';
import 'wishlist.page.dart';

class ProfileScreenPage extends StatefulWidget {
  const ProfileScreenPage({super.key});

  @override
  State<ProfileScreenPage> createState() => _ProfileScreenPageState();
}

class _ProfileScreenPageState extends State<ProfileScreenPage> {
  String profilePicUrl = "";
  String userFullName = "";
  String userEmail = "";
  int orderCount = 0;
  int addressCount = 0;
  int wishlistCount = 0;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  

  User? currentUser; // Declare a class-level variable

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser; // Initialize user
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          userFullName = userData?['fullname'] ?? "No Name";
          userEmail = userData?['email'] ?? "No Email";
          profilePicUrl = userData?['profilepic'] ?? "";
        });
      }
    } catch (e) {
      print("Error loading user data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = _auth.currentUser;
    bool isLoggedIn = currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          InkWell(
            onTap: isLoggedIn
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfilePage()),
                    );
                  }
                : null, // Disable tap if not signed in
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: profilePicUrl.isNotEmpty ? NetworkImage(profilePicUrl) : null,
                  child: profilePicUrl.isEmpty ? const Icon(Icons.person, size: 50) : null,
                ),
                const SizedBox(height: 8),
                Text(
                  isLoggedIn ? userFullName : "Guest",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  isLoggedIn ? userEmail : "Please sign in",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildMenuItem(Icons.shopping_bag, "My Orders", "Track your orders", isLoggedIn, const OrderPage()),
          _buildMenuItem(Icons.favorite, "Wishlist", "Your saved items", isLoggedIn, WishlistPage(userId: currentUser?.uid ?? "")),
         _buildMenuItem(Icons.location_on, "Shipping Addresses", "Manage saved addresses", isLoggedIn, const ShippingAddressesPage()),
// _buildMenuItem(Icons.location_on, "Shipping Addresses", "Manage saved addresses", isLoggedIn,  AdsDebugPage()),
       // _buildMenuItem(Icons.location_on, "Shipping Addresses", "Manage saved addresses", isLoggedIn,  New_NotificationScreen()),
          
          _buildMenuItem(Icons.notifications, "Notifications", "View your latest updates", isLoggedIn, const FBNotificationsScreen()),
        //  _buildMenuItem(Icons.support_agent, "Support", "Need help? Contact us anytime", true, EmailSender()),
          _buildMenuItem(Icons.support_agent, "Support", "Need help? Contact us anytime", true, const ChatBotHome()),
         _buildMenuItem(Icons.currency_exchange, "Currency", "Set your preferred currency", true, const CurrencyConverterSelection()),

  
          // Sign In/Out Button
     ListTile(
  leading: Icon(isLoggedIn ? Icons.logout : Icons.login),
  title: Text(isLoggedIn ? "Sign Out" : "Sign In / Sign Up"),
  subtitle: Text(isLoggedIn ? "End your session securely" : "Access your account"),
  trailing: const Icon(Icons.arrow_forward_ios),
  onTap: () async {
    if (isLoggedIn) {
      try {
        // Optional: also sign out provider SDKs so their sessions aren’t kept
        // try { await GoogleSignIn().signOut(); } catch (_) {}
        // try { await FacebookAuth.instance.logOut(); } catch (_) {}

        await FirebaseAuth.instance.signOut();

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('isSignedIn'); // not used by AuthGate, safe to clear
        // Do NOT touch any “isFirstAccess” flag here.
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign out failed: $e')),
        );
      }
    }

    if (!context.mounted) return;
    // Always go through AuthGate so the app re-evaluates auth state cleanly
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  },
)
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, bool isEnabled, Widget page) {
    return ListTile(
      leading: Icon(icon, color: isEnabled ? null : Colors.grey),
      title: Text(title, style: TextStyle(color: isEnabled ? null : Colors.grey)),
      subtitle: Text(subtitle, style: TextStyle(color: isEnabled ? null : Colors.grey)),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: isEnabled
          ? () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => page));
            }
          : null,
    );
  }
}