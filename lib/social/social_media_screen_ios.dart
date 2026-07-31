// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// import '../custom_scripts/custom_script.dart';
// import '../homescreen.dart';
// import '../shop/flashdeals_seeall.dart';
// import '../shop/shop_screen.dart';
// import '../shop/specialproducts_screen.dart';
// import '../shop/trendingpage_seeall.dart';
// import 'fashion_grid.dart';
// import 'favorite.dart';
// import 'general_test.dart';
// import 'movies_screen.dart';
// import 'games_screen.dart';
// import 'jobs_screen.dart';
// import 'general_test.dart';
// import 'social_notification/social_fbnotification_model.dart';
// import 'social_notification/social_fbnotification_screen.dart';
// import 'social_notification/social_fbnotification_service.dart';

// class SocialMediaScreen extends StatefulWidget {
//   const SocialMediaScreen({super.key});

//   @override
//   State<SocialMediaScreen> createState() => _SocialMediaScreenState();
// }

// class _SocialMediaScreenState extends State<SocialMediaScreen> {
//   Future<void> _signOut() async {
//     await FirebaseAuth.instance.signOut();
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('isSignedIn', false);
//     Navigator.of(context).pushReplacementNamed('/login');
//   }

//   //added 30 01 2025
//   final SFBNotificationService notificationService = SFBNotificationService();
//   late String userId;

//   @override
//   void initState() {
//     super.initState();
//     final FirebaseAuth auth = FirebaseAuth.instance;
//     final User? currentUser = auth.currentUser;

//     if (currentUser != null) {
//       userId = currentUser.uid;
//     } else {
//       userId = '';
//     }
//   }

//   int _getUnreadCount(List<SNotificationModel> notifications) {
//     return notifications
//         .where((notification) => !notification.readBy.contains(userId))
//         .length;
//   }

//   //added 30 01 2025
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               Color(0xFF6A8DFF), // Vibrant blue at the top
//               Color(0xFFECF2FF), // Soft pastel blue transitioning
//               Colors.white, // Pure white at the bottom
//             ],
//           ),
//         ),
//         child: Column(
//           children: [
//             // AppBar-like structure with Favorite and Notification Icons
//             // AppBar-like structure with Favorite and Notification Icons
//             Padding(
//               padding:
//                   const EdgeInsets.symmetric(horizontal: 16.0, vertical: 40.0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const SizedBox(width: 48), // Spacer for symmetry

//                   Row(
//                     children: [
//                       userId.isNotEmpty
//                           ? StreamBuilder<List<SNotificationModel>>(
//                               stream: notificationService.getNotifications(),
//                               builder: (context, snapshot) {
//                                 if (!snapshot.hasData ||
//                                     snapshot.connectionState ==
//                                         ConnectionState.waiting) {
//                                   return IconButton(
//                                     icon: const Icon(Icons.notifications),
//                                     onPressed: () {},
//                                   );
//                                 }

//                                 final unreadCount =
//                                     _getUnreadCount(snapshot.data!);

//                                 return Stack(
//                                   alignment: Alignment.center,
//                                   children: [
//                                     IconButton(
//                                       icon: const Icon(Icons.notifications,
//                                           color: Colors.white),
//                                       onPressed: () {
//                                         Navigator.push(
//                                           context,
//                                           MaterialPageRoute(
//                                             builder: (context) =>
//                                                 SFBNotificationsScreen(),
//                                           ),
//                                         );
//                                       },
//                                     ),
//                                     if (unreadCount > 0)
//                                       Positioned(
//                                         right: 5,
//                                         top: 2,
//                                         child: Container(
//                                           padding: const EdgeInsets.all(4),
//                                           decoration: BoxDecoration(
//                                             color: Colors.red,
//                                             shape: BoxShape.circle,
//                                           ),
//                                           constraints: const BoxConstraints(
//                                             minWidth: 20,
//                                             minHeight: 20,
//                                           ),
//                                           child: Text(
//                                             unreadCount.toString(),
//                                             style: const TextStyle(
//                                               color: Colors.white,
//                                               fontSize: 12,
//                                               fontWeight: FontWeight.bold,
//                                             ),
//                                             textAlign: TextAlign.center,
//                                           ),
//                                         ),
//                                       ),
//                                   ],
//                                 );
//                               },
//                             )
//                           : Container(),
//                       IconButton(
//                         icon: const Icon(Icons.favorite, color: Colors.white),
//                         onPressed: () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => FavoritePage(),
//                             ),
//                           );
//                         },
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),

//             Padding(
//               padding:
//                   const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   RichText(
//                     text: TextSpan(
//                       text: 'Discover\n',
//                       style: GoogleFonts.playfairDisplay(
//                         fontSize: 35, // Larger font size for emphasis
//                         fontWeight: FontWeight.bold,
//                         color: Colors.black, // Adjust color as needed
//                       ),
//                       children: [
//                         TextSpan(
//                           text: 'your ',
//                           style: GoogleFonts.playfairDisplay(
//                             fontSize: 31, // Slightly smaller size
//                             fontWeight: FontWeight.w400, // Normal weight
//                             color: Colors.black,
//                           ),
//                         ),
//                         TextSpan(
//                           text: 'lifestyle trends',
//                           style: GoogleFonts.playfairDisplay(
//                             fontSize: 35, // Match the larger size for impact
//                             fontWeight: FontWeight.bold,
//                             color: Colors.black,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   // const SizedBox(height: 20), // Add spacing below the text
//                   // Tab Filters (e.g., All cards, Left, Taken)

//                   const SizedBox(height: 25),

//                   // Text(
//                   //   "     Shop Our Best Deals",
//                   //   style: TextStyle(
//                   //     fontSize: 16,
//                   //     //color: Color(0xFF800080),
//                   //     color: Colors.black,
//                   //     // fontFamily: 'Lato', // Friendly and modern
//                   //     // fontFamily: 'Nunito', // Rounded and modern
//                   //     //fontFamily: 'Raleway', // Elegant and modern font
//                   //     //fontFamily: 'Montserrat', // Stylish and modern font
//                   //     fontFamily: 'Roboto', // Stylish and modern font
//                   //     fontWeight: FontWeight.bold,
//                   //   ),
//                   // ),
//                   // const SizedBox(height: 10),

//                   // Sales buttons with icons and badges

//                   Row(
//                     ///// mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     mainAxisAlignment: MainAxisAlignment.start,
//                     children: [
//                       // SAVE BIG Button
//                       Expanded(
//                         child: SalesButton(
//                           icon: Icons.local_offer,
//                           label: "🛍️ SAVE BIG",
//                           subtitle: "Wow discounts",
//                           badgeText: "SALE",
//                           onTap: () {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => const FlashDealsPage(),
//                               ),
//                             );
//                           },
//                         ),
//                       ),

//                       // HOT PICKS Button
//                       Expanded(
//                         child: SalesButton(
//                           icon: Icons.fireplace,
//                           label: "🔥 HOT PICKS",
//                           subtitle: "Special deals",
//                           badgeText: "HOT",
//                           onTap: () {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) =>
//                                     const SpecialDealsScreen(),
//                               ),
//                             );
//                           },
//                         ),
//                       ),

//                       // SPOTLIGHT Button
//                       Expanded(
//                         child: SalesButton(
//                           icon: Icons.star,
//                           label: "🌟 SPOTLIGHT",
//                           subtitle: "Exclusive picks",
//                           badgeText: "NEW",
//                           onTap: () {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => const TrendingDealsPage(),
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
// SizedBox(height: 30,),
//             // Grid of Section Cards
//            Expanded(
//   child: Padding(
//     padding: const EdgeInsets.only(left: 16.0, right: 16, bottom: 16, top: 0),
//     child: LayoutBuilder(
//       builder: (context, constraints) {
//         final isWide = constraints.maxWidth >= 720; // tablet/landscape

//         if (!isWide) {
//           // PHONE: Fashion + Movies on first row; Jobs full-width underneath
//           return SingleChildScrollView(
//             child: Column(
//               children: [
//                 Row(
//                   children: [
//                     Expanded(
//                       child: _buildSectionCard(
//                         'Fashion', const Color(0xFFB4D9FF), 'Discover Trends', 'images/fashion.jpg',
//                         onTap: () => Navigator.push(
//                           context,
//                           MaterialPageRoute(builder: (_) => FashionGridPage()),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 16),
//                     Expanded(
//                       child: _buildSectionCard(
//                         'Movies', const Color(0xFFFFD7B5), 'Sneak Peeks', 'images/movies.jpg',
//                         onTap: () => Navigator.push(
//                           context,
//                           MaterialPageRoute(builder: (_) => const MoviesScreen()),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 16),
//                 // JOBS spans horizontally (full width)
//                 SizedBox(
//                   height: 170, // adjust to taste
//                   width: double.infinity,
//                   child: _buildSectionCard(
//                     'Jobs', const Color(0xFFFFB4B4), 'Explore Careers', 'images/jobs.jpg',
//                     onTap: () => Navigator.push(
//                       context,
//                       MaterialPageRoute(builder: (_) => JobsScreen()),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           );
//         }

//         // TABLET / WIDE: 3 even tiles in one row
//         return GridView(
//           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: 3, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1,
//           ),
//           children: [
//             _buildSectionCard(
//               'Fashion', const Color(0xFFB4D9FF), 'Discover Trends', 'images/fashion.jpg',
//               onTap: () => Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => FashionGridPage()),
//               ),
//             ),
//             _buildSectionCard(
//               'Movies', const Color(0xFFFFD7B5), 'Sneak Peeks', 'images/movies.jpg',
//               onTap: () => Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => const MoviesScreen()),
//               ),
//             ),
//             _buildSectionCard(
//               'Jobs', const Color(0xFFFFB4B4), 'Explore Careers', 'images/jobs.jpg',
//               onTap: () => Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => JobsScreen()),
//               ),
//             ),
//           ],
//         );
//       },
//     ),
//   ),
// )

//           ],
//         ),
//       ),
//     );
//   }

//   // Helper: Build Section Card
//   Widget _buildSectionCard(
//       String title, Color color, String subtitle, String iconPath,
//       {required VoidCallback onTap}) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         decoration: BoxDecoration(
//           color: color,
//           borderRadius: BorderRadius.circular(16),
//           // The image background with opacity
//           image: DecorationImage(
//             image: AssetImage(iconPath),
//             fit: BoxFit.cover,
//             colorFilter: ColorFilter.mode(
//               Colors.black.withOpacity(0.3), // Apply opacity to the image
//               BlendMode.darken,
//             ),
//           ),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Container for title and subtitle with darkened background
//               Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.black.withOpacity(0.5),
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       title,
//                       style: const TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       subtitle,
//                       style: const TextStyle(
//                         fontSize: 14,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // Custom SalesButton Widget
// class SalesButton extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final String subtitle;
//   final String badgeText;
//   final VoidCallback onTap;

//   const SalesButton({
//     Key? key,
//     required this.icon,
//     required this.label,
//     required this.subtitle,
//     required this.badgeText,
//     required this.onTap,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Column(
//         children: [
//           Stack(
//             clipBehavior: Clip.none,
//             children: [
//               Container(
//                 width: MediaQuery.of(context).size.width * 0.21,
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   gradient: const LinearGradient(
//                     colors: [Colors.orange, Colors.red],
//                   ),
//                   borderRadius: BorderRadius.circular(10),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.grey.withOpacity(0.4),
//                       spreadRadius: 1,
//                       blurRadius: 3,
//                       offset: const Offset(0, 2),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   children: [
//                     Icon(
//                       icon,
//                       size: 24,
//                       color: Colors.white,
//                     ),
//                     const SizedBox(height: 4),
//                     FittedBox(
//                       child: Text(
//                         label,
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.white,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Positioned(
//                 top: -4,
//                 right: -4,
//                 child: Container(
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                   decoration: BoxDecoration(
//                     color: Colors.red,
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                   child: Text(
//                     badgeText,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 8,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 4),
//           FittedBox(
//             child: Text(
//               subtitle,
//               style: TextStyle(
//                 fontSize: 9,
//                 color: Colors.grey[600],
//               ),
//               textAlign: TextAlign.center,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
