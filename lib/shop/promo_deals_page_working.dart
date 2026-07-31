// import 'dart:async';

// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:tremsolapp/services/app_colors.dart';

// import '../homescreen.dart';
// import 'cartpage.dart';
// import 'product_details_screen.dart';
// import 'productsearch_deals.dart';

// class PromoDealsPage extends StatefulWidget {
//   const PromoDealsPage({Key? key}) : super(key: key);

//   @override
//   State<PromoDealsPage> createState() => _PromoDealsPageState();
// }

// class _PromoDealsPageState extends State<PromoDealsPage> {
//   String currencySymbol = "GHS";
//   double exchangeRate = 1.0;
//   Duration _timeRemaining = const Duration(hours: 1); // unused but kept

//   @override
//   void initState() {
//     super.initState();
//     _loadCurrencyData();
//   }

//   Future<void> _loadCurrencyData() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     setState(() {
//       currencySymbol = prefs.getString('baseCurrency') ?? 'GHS'; // your real base
//       exchangeRate = prefs.getDouble('conversionRate') ?? 1.0;
//     });
//   }

//   String _capitalizeFirstLetter(String input) {
//     if (input.isEmpty) return '';
//     return input
//         .split(' ')
//         .where((word) => word.isNotEmpty)
//         .map((word) => word[0].toUpperCase() + word.substring(1))
//         .join(' ');
//   }

//   double _convertPrice(double price) {
//     return price * exchangeRate;
//   }

//   Future<int> getOrderCount(String productId) async {
//     final querySnapshot =
//         await FirebaseFirestore.instance.collection('ordersitems').get();

//     int orderCount = 0;
//     for (var doc in querySnapshot.docs) {
//       var items = doc['items'];
//       for (var item in items) {
//         if (item is Map && item['productId'] == productId) {
//           orderCount++;
//           break;
//         }
//       }
//     }
//     return orderCount;
//   }

//   String? selectedColor;
//   String? selectedSize;

//   void _placeOrder(Map<String, dynamic> productData, int quantity) async {
//     final userId = FirebaseAuth.instance.currentUser?.uid;
//     if (userId == null) {
//       _showError("User not signed in");
//       return;
//     }

//     final hasColors = productData['product_colors'] != null &&
//         (productData['product_colors'] as List).isNotEmpty;
//     final hasSizes = productData['product_sizes'] != null &&
//         (productData['product_sizes'] as List).isNotEmpty;

//     if ((hasColors && selectedColor == null) ||
//         (hasSizes && selectedSize == null)) {
//       String errorMessage = "Please select ";
//       if (hasColors &&
//           selectedColor == null &&
//           hasSizes &&
//           selectedSize == null) {
//         errorMessage += "a color and a size before adding to cart.";
//       } else if (hasColors && selectedColor == null) {
//         errorMessage += "a color before adding to cart.";
//       } else if (hasSizes && selectedSize == null) {
//         errorMessage += "a size before adding to cart.";
//       }
//       _showError(errorMessage);
//       return;
//     }

//     try {
//       final cartQuerySnapshot = await FirebaseFirestore.instance
//           .collection('cartitems')
//           .where('userId', isEqualTo: userId)
//           .where('productId', isEqualTo: productData['id'])
//           .where('selectedColor', isEqualTo: selectedColor ?? "")
//           .where('selectedSize', isEqualTo: selectedSize ?? "")
//           .get();

//       if (cartQuerySnapshot.docs.isNotEmpty) {
//         final existingCartItem = cartQuerySnapshot.docs.first;
//         final existingQuantity = existingCartItem['quantity'] as int;

//         await FirebaseFirestore.instance
//             .collection('cartitems')
//             .doc(existingCartItem.id)
//             .update({
//           'quantity': existingQuantity + quantity,
//           'totalPrice': (productData['productsellingprice'] ?? 0) *
//               (existingQuantity + quantity),
//         });

//         showDialog(
//           context: context,
//           builder: (context) => AlertDialog(
//             title: const Text('Updated Cart'),
//             content: Text(
//                 'Quantity of ${productData['productname'] ?? "Product"} updated to ${existingQuantity + quantity}.'),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(),
//                 child: const Text('OK'),
//               ),
//             ],
//           ),
//         );
//       } else {
//         await FirebaseFirestore.instance.collection('cartitems').add({
//           'userId': userId,
//           'productId': productData['id'],
//           'productName': productData['productname'] ?? "Unknown Product",
//           'productsellingprice': productData['productsellingprice'] ?? 0,
//           'productprice': productData['productprice'] ?? 0,
//           'tax': productData['tax'] ?? 0,
//           'cost_per_item': productData['cost_per_item'] ?? 0,
//           'productDescription': productData['productdescription'] ?? "",
//           'quantity': quantity,
//           'selectedColor': selectedColor ?? "",
//           'selectedSize': selectedSize ?? "",
//           'totalPrice': (productData['productsellingprice'] ?? 0) * quantity,
//           'productImage': (productData['images'] != null &&
//                   (productData['images'] as List).isNotEmpty)
//               ? productData['images'].first
//               : "",
//           'timestamp': FieldValue.serverTimestamp(),
//         });

//         showDialog(
//           context: context,
//           builder: (context) => AlertDialog(
//             title: const Text('Added to Cart'),
//             content: Text(
//                 'Added $quantity of ${productData['productname'] ?? "Product"} to the cart.'),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(),
//                 child: const Text('OK'),
//               ),
//             ],
//           ),
//         );
//       }
//     } catch (e) {
//       _showError("Failed to add to cart");
//     }
//   }

//   void _showError(String message) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Error'),
//         content: Text(message),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'Promotions',
//           style: TextStyle(color: Colors.white, fontSize: 18),
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.search),
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   // you can adapt PrdSearchDealsPage to also search Promo/Sales
//                   builder: (context) => const PrdSearchDealsPage(dealTag: 'Promo'),
//                 ),
//               );
//             },
//           ),
//           IconButton(
//             icon: const Icon(Icons.home),
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => HomeScreen()),
//               );
//             },
//           ),
//           FirebaseAuth.instance.currentUser == null
//               ? const SizedBox()
//               : StreamBuilder<QuerySnapshot>(
//                   stream: FirebaseFirestore.instance
//                       .collection('cartitems')
//                       .where('userId',
//                           isEqualTo: FirebaseAuth.instance.currentUser!.uid)
//                       .snapshots(),
//                   builder: (context, snapshot) {
//                     int cartCount = 0;
//                     if (snapshot.hasData) {
//                       cartCount = snapshot.data!.docs.length;
//                     }

//                     return Padding(
//                       padding: const EdgeInsets.all(8.0),
//                       child: Stack(
//                         clipBehavior: Clip.none,
//                         children: [
//                           IconButton(
//                             icon: const Icon(Icons.shopping_cart_outlined),
//                             onPressed: () {
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (context) => const CartPage(),
//                                 ),
//                               );
//                             },
//                           ),
//                           if (cartCount > 0)
//                             Positioned(
//                               right: 0,
//                               top: -2,
//                               child: Container(
//                                 padding: const EdgeInsets.symmetric(
//                                     horizontal: 6, vertical: 2),
//                                 decoration: BoxDecoration(
//                                   color: Colors.red,
//                                   borderRadius: BorderRadius.circular(8),
//                                   boxShadow: [
//                                     BoxShadow(
//                                       color: Colors.black.withOpacity(0.3),
//                                       blurRadius: 4,
//                                       offset: const Offset(0, 2),
//                                     ),
//                                   ],
//                                 ),
//                                 constraints: const BoxConstraints(
//                                   minWidth: 16,
//                                   minHeight: 16,
//                                 ),
//                                 child: Text(
//                                   '$cartCount',
//                                   style: const TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 12,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                   textAlign: TextAlign.center,
//                                 ),
//                               ),
//                             ),
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//         ],
//         // if AppColors().getColor('promo') exists, you can switch to that
//         backgroundColor: AppColors().getColor('promo'),
//         iconTheme: const IconThemeData(color: Colors.white),
//       ),
//       body: _buildProductGrid(),
//     );
//   }

//   Widget _buildProductGrid() {
//     return StreamBuilder<QuerySnapshot>(
//       stream: FirebaseFirestore.instance
//           .collection('products')
//           .where('producttag', arrayContainsAny: [
//             'Promo',
//             'promo',
//             'PROMO',
//             'Sales',
//             'sales',
//             'SALES',
//           ])
//           .where('isPublish', isEqualTo: true)
//           .orderBy('createdAt', descending: true)
//           .snapshots(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const Center(child: CircularProgressIndicator());
//         }

//         final products = snapshot.data!.docs;
//         final screenWidth = MediaQuery.of(context).size.width;
//         const int crossAxisCount = 2;
//         final double childAspectRatio = screenWidth / (screenWidth * 1.8);

//         return Padding(
//           padding: const EdgeInsets.all(8.0),
//           child: GridView.builder(
//             gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//               crossAxisCount: crossAxisCount,
//               mainAxisSpacing: 8,
//               crossAxisSpacing: 8,
//               childAspectRatio: childAspectRatio,
//             ),
//             itemCount: products.length,
//             itemBuilder: (context, index) {
//               final product = products[index];
//               final name = product['productname'];
//               final imageUrl = product['image'] ?? '';

//               final ini_price = product['productprice']?.toDouble() ?? 0.0;
//               final price = product['productsellingprice']?.toDouble() ?? 0.0;
//               final discountedPrice =
//                   (product['productdiscprice'] is String
//                           ? double.tryParse(
//                               product['productdiscprice'] ?? '0')
//                           : (product['productdiscprice'] as num?)
//                               ?.toDouble()) ??
//                       0.0;

//               final productPrice = product['productprice']?.toDouble() ?? 0.0;
//               final tax = product['tax']?.toDouble() ?? 0.0;
//               final ini_sellingPrice = productPrice + tax;
//               final fin_sellingPrice =
//                   product['productsellingprice']?.toDouble() ?? 0.0;

//               final discountedPercentage =
//                   (((ini_sellingPrice - fin_sellingPrice) / (ini_sellingPrice)) *
//                       100);

//               final productState = product['productstate'];
//               final double? rating = product['rating']?.toDouble();

//               final ValueNotifier<bool> isLiked = ValueNotifier(
//                 (product['likes'] != null &&
//                         FirebaseAuth.instance.currentUser != null)
//                     ? product['likes']
//                         .contains(FirebaseAuth.instance.currentUser!.uid)
//                     : false,
//               );

//               Future<void> toggleLike() async {
//                 final currentUser = FirebaseAuth.instance.currentUser;
//                 if (currentUser != null) {
//                   final productRef = FirebaseFirestore.instance
//                       .collection('products')
//                       .doc(product.id);

//                   await FirebaseFirestore.instance
//                       .runTransaction((transaction) async {
//                     DocumentSnapshot snapshot =
//                         await transaction.get(productRef);
//                     List<dynamic> likes = snapshot['likes'] ?? [];

//                     if (likes.contains(currentUser.uid)) {
//                       likes.remove(currentUser.uid);
//                     } else {
//                       likes.add(currentUser.uid);
//                     }

//                     transaction.update(productRef, {'likes': likes});
//                   });

//                   isLiked.value = !isLiked.value;
//                 }
//               }

//               return GestureDetector(
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) =>
//                           ProductDetailsScreen(productId: product.id),
//                     ),
//                   );
//                 },
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(8),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.grey.withOpacity(0.2),
//                         blurRadius: 5,
//                         offset: const Offset(0, 3),
//                       ),
//                     ],
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Stack(
//                         children: [
//                           ClipRRect(
//                             borderRadius: const BorderRadius.vertical(
//                                 top: Radius.circular(10)),
//                             child: Image.network(
//                               imageUrl,
//                               height:
//                                   MediaQuery.of(context).size.height * 0.19,
//                               width: double.infinity,
//                               fit: BoxFit.cover,
//                               errorBuilder:
//                                   (context, error, stackTrace) =>
//                                       const Icon(
//                                 Icons.image_not_supported,
//                                 size: 50,
//                                 color: Colors.grey,
//                               ),
//                             ),
//                           ),
//                           if (productState != null && productState.isNotEmpty)
//                             Positioned(
//                               top: 8,
//                               left: 8,
//                               child: Container(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 6,
//                                   vertical: 2,
//                                 ),
//                                 decoration: BoxDecoration(
//                                   color: Colors.white,
//                                   borderRadius: BorderRadius.circular(5),
//                                   border: Border.all(
//                                       color: Colors.red, width: 0.5),
//                                 ),
//                                 child: Text(
//                                   productState.toUpperCase(),
//                                   style: const TextStyle(
//                                     fontSize: 9,
//                                     color: Colors.red,
//                                     fontWeight: FontWeight.w900,
//                                   ),
//                                   overflow: TextOverflow.ellipsis,
//                                 ),
//                               ),
//                             ),
//                           if (discountedPercentage > 0 &&
//                               discountedPercentage < 100)
//                             Positioned(
//                               top: 8,
//                               right: 8,
//                               child: Container(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 8,
//                                   vertical: 4,
//                                 ),
//                                 decoration: BoxDecoration(
//                                   color: Colors.red,
//                                   borderRadius: BorderRadius.circular(20),
//                                 ),
//                                 child: Text(
//                                   '-${discountedPercentage.toStringAsFixed(0)}%',
//                                   style: const TextStyle(
//                                     fontSize: 12,
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           Positioned(
//                             bottom: 8,
//                             right: 8,
//                             child: ValueListenableBuilder<bool>(
//                               valueListenable: isLiked,
//                               builder: (context, value, child) {
//                                 return GestureDetector(
//                                   onTap: toggleLike,
//                                   child: Opacity(
//                                     opacity: 0.8,
//                                     child: CircleAvatar(
//                                       backgroundColor:
//                                           const Color(0xFFFFEDEE),
//                                       radius: 18,
//                                       child: Icon(
//                                         value
//                                             ? Icons.favorite
//                                             : Icons.favorite_border,
//                                         color: Colors.red,
//                                         size: 20,
//                                       ),
//                                     ),
//                                   ),
//                                 );
//                               },
//                             ),
//                           ),
//                         ],
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Padding(
//                               padding: const EdgeInsets.only(top: 6.0),
//                               child: Text(
//                                 _capitalizeFirstLetter(name),
//                                 style: const TextStyle(
//                                   fontSize: 13,
//                                   color: Colors.black,
//                                 ),
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                             ),
//                             if (discountedPercentage > 0 &&
//                                 discountedPercentage < 100)
//                               Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(fin_sellingPrice))}',
//                                     style: const TextStyle(
//                                       fontSize: 15,
//                                       fontWeight: FontWeight.bold,
//                                       color: Colors.red,
//                                     ),
//                                     maxLines: 1,
//                                     overflow: TextOverflow.ellipsis,
//                                   ),
//                                   Text(
//                                     '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(ini_sellingPrice))}',
//                                     style: const TextStyle(
//                                       fontSize: 13,
//                                       color: Colors.grey,
//                                       decoration: TextDecoration.lineThrough,
//                                     ),
//                                     maxLines: 1,
//                                     overflow: TextOverflow.ellipsis,
//                                   ),
//                                 ],
//                               )
//                             else
//                               Text(
//                                 '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(ini_sellingPrice))}',
//                                 style: const TextStyle(
//                                   fontSize: 15,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.black,
//                                 ),
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                             if (rating != null)
//                               Row(
//                                 children: [
//                                   const Icon(
//                                     Icons.star,
//                                     color: Colors.amber,
//                                     size: 14,
//                                   ),
//                                   const SizedBox(width: 4),
//                                   Text(
//                                     '$rating',
//                                     style: const TextStyle(
//                                       fontSize: 12,
//                                       color: Colors.black54,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             FutureBuilder<int>(
//                               future: getOrderCount(product.id),
//                               builder: (context, snapshot) {
//                                 if (snapshot.connectionState ==
//                                     ConnectionState.waiting) {
//                                   return const Text(
//                                     'Loading...',
//                                     style: TextStyle(
//                                         fontSize: 12,
//                                         color: Colors.black54),
//                                   );
//                                 }

//                                 if (snapshot.data == 0) {
//                                   return Container();
//                                 }

//                                 return Text(
//                                   '${snapshot.data ?? 0} Orders',
//                                   style: const TextStyle(
//                                     fontSize: 12,
//                                     color: Colors.black54,
//                                   ),
//                                 );
//                               },
//                             ),
//                           ],
//                         ),
//                       ),
//                       const Spacer(),
//                       Padding(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 8.0, vertical: 8.0),
//                         child: SizedBox(
//                           width: double.infinity,
//                           child: ElevatedButton(
//                             onPressed: () {
//                               var firebaseUser =
//                                   FirebaseAuth.instance.currentUser;
//                               if (firebaseUser == null) {
//                                 ScaffoldMessenger.of(context).showSnackBar(
//                                   const SnackBar(
//                                     content: Text(
//                                         'Please sign in or create an account to add product to cart'),
//                                     duration: Duration(seconds: 2),
//                                   ),
//                                 );
//                                 return;
//                               }

//                               _placeOrder(
//                                 {
//                                   'id': product.id,
//                                   'productname': name,
//                                   'productsellingprice': price,
//                                   'product_colors': product['product_colors'],
//                                   'product_sizes': product['product_sizes'],
//                                   'images': product['images'],
//                                   'productdescription':
//                                       product['productdescription'],
//                                   'productprice': product['productprice'],
//                                   'tax': product['tax'],
//                                   'cost_per_item': product['cost_per_item'],
//                                 },
//                                 product['productminquantity'],
//                               );
//                             },
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor:
//                                   AppColors().getColor('flash'),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                             ),
//                             child: const Text(
//                               'Add to Cart',
//                               style: TextStyle(
//                                   color: Colors.white, fontSize: 14),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }
// }
