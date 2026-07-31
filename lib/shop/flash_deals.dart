// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:async';

// import 'product_details_screen.dart';

// class FlashDealsPage extends StatefulWidget {
//   const FlashDealsPage({super.key});

//   @override
//   State<FlashDealsPage> createState() => _FlashDealsPageState();
// }

// class _FlashDealsPageState extends State<FlashDealsPage> {
//   late Timer _timer;
//   Duration _timeRemaining = const Duration(hours: 1); // Initial countdown time

//   // Variables to store currency symbol and exchange rate
//   String _currencySymbol = "GHS";
//   double _exchangeRate = 1.0;

//   @override
//   void initState() {
//     super.initState();
//     _loadCurrencyData();
//     _startTimer();
//   }

//   void _startTimer() {
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       setState(() {
//         if (_timeRemaining > const Duration(seconds: 1)) {
//           _timeRemaining -= const Duration(seconds: 1);
//         } else {
//           _timeRemaining = const Duration(hours: 1); // Restart countdown
//         }
//       });
//     });
//   }

//   @override
//   void dispose() {
//     _timer.cancel();
//     super.dispose();
//   }

//  bool _currencyLoaded = false;

// Future<void> _loadCurrencyData() async {
//   final prefs = await SharedPreferences.getInstance();

//   final base = prefs.getString('baseCurrency') ?? 'GHS';
//   final selected = prefs.getString('selectedCurrency') ?? base;
//   final rate = prefs.getDouble('conversionRate') ?? 1.0;

//   setState(() {
//     currencySymbol = selected;  // 👈 show user’s chosen currency code
//     exchangeRate = rate;        // 👈 base → selected
//     _currencyLoaded = true;
//   });
// }


//   String _formatTimeRemaining(Duration duration) {
//     final hours = duration.inHours;
//     final minutes = duration.inMinutes % 60;
//     final seconds = duration.inSeconds % 60;

//     return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
//   }

//   double _getConvertedPrice(double price) {
//     return price * _exchangeRate;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F5F5),
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         title: const Text(
//           "Flash Deals",
//           style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
//         ),
//         centerTitle: true,
//         iconTheme: const IconThemeData(color: Colors.black),
//       ),
//       body: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Text(
//               'Time Left: ${_formatTimeRemaining(_timeRemaining)}',
//               style: const TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.redAccent,
//               ),
//             ),
//           ),
//           Expanded(
//             child: StreamBuilder<QuerySnapshot>(
//               stream: FirebaseFirestore.instance
//                   .collection('products')
//                   .where('producttag', isEqualTo: 'Flash')
//                   .snapshots(),
//               builder: (context, snapshot) {
//                 if (!snapshot.hasData) {
//                   return const Center(child: CircularProgressIndicator());
//                 }

//                 final products = snapshot.data!.docs;
//                 return GridView.builder(
//                   padding: const EdgeInsets.all(8.0),
//                   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                     crossAxisCount: 2,
//                     crossAxisSpacing: 12.0,
//                     mainAxisSpacing: 12.0,
//                     childAspectRatio: 0.8,
//                   ),
//                   itemCount: products.length,
//                   itemBuilder: (context, index) {
//                     final product = products[index];
//                     final productsellingprice =
//                         double.tryParse(product['productsellingprice'].toString()) ??
//                             0.0;
//                     final convertedPrice = _getConvertedPrice(productsellingprice);

//                     return GestureDetector(
//                       onTap: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) =>
//                                 ProductDetailsScreen(productId: product.id),
//                           ),
//                         );
//                       },
//                       child: Container(
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(12),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.grey.withOpacity(0.2),
//                               blurRadius: 6,
//                               offset: const Offset(0, 4),
//                             ),
//                           ],
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//                             ClipRRect(
//                               borderRadius: const BorderRadius.vertical(
//                                 top: Radius.circular(12),
//                               ),
//                               child: Image.network(
//                                 product['image'],
//                                 height: 140,
//                                 width: double.infinity,
//                                 fit: BoxFit.cover,
//                                 errorBuilder: (context, error, stackTrace) =>
//                                     const Icon(Icons.broken_image, size: 50),
//                               ),
//                             ),
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 8.0, vertical: 8.0),
//                               child: Text(
//                                 product['productname'],
//                                 style: const TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                                 textAlign: TextAlign.center,
//                               ),
//                             ),
//                             Padding(
//                               padding:
//                                   const EdgeInsets.symmetric(horizontal: 8.0),
//                               child: Text(
//                                 '$_currencySymbol${convertedPrice.toStringAsFixed(2)}',
//                                 style: const TextStyle(
//                                   fontSize: 18,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.black,
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             if (product['productdiscprice'] != null)
//                               Padding(
//                                 padding:
//                                     const EdgeInsets.symmetric(horizontal: 8.0),
//                                 child: Text(
//                                   '-${(((productsellingprice - (double.tryParse(product['productdiscprice'].toString()) ?? 0.0)) / productsellingprice) * 100).toStringAsFixed(0)}% OFF',
//                                   style: const TextStyle(
//                                     fontSize: 14,
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.redAccent,
//                                   ),
//                                 ),
//                               ),
//                           ],
//                         ),
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
