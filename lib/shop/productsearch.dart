// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'product_details_screen.dart';

// class SearchPage extends StatefulWidget {
//   @override
//   _SearchPageState createState() => _SearchPageState();
// }

// class _SearchPageState extends State<SearchPage> {
//   TextEditingController searchController = TextEditingController();
//   List<DocumentSnapshot> searchResults = [];
//   bool isLoading = false;

//   void searchProducts(String query) async {
//     if (query.isEmpty) {
//       setState(() {
//         searchResults = [];
//         isLoading = false;
//       });
//       return;
//     }

//     setState(() {
//       isLoading = true;
//     });

//     QuerySnapshot snapshot = await FirebaseFirestore.instance
//         .collection('products')
//         .where('productname', isGreaterThanOrEqualTo: query.toLowerCase())
//         .where('productname',
//             isLessThanOrEqualTo: query.toLowerCase() + '\uf8ff')
//         .get();

//     setState(() {
//       searchResults = snapshot.docs;
//       isLoading = false;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'Search Products'
//         ),
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: TextField(
//               controller: searchController,
//               onChanged: (value) => searchProducts(value)
//               decoration: InputDecoration(
//                 labelText: "Search"
//                 border: const OutlineInputBorder(),
//                 prefixIcon: const Icon(Icons.search),
//               ),
//             ),
//           ),
//           if (isLoading)
//             const Center(
//               child: CircularProgressIndicator(),
//             )
//           else
//             Expanded(
//               child: ListView.builder(
//                 itemCount: searchResults.length,
//                 itemBuilder: (context, index) {
//                   final product = searchResults[index];
//                   return ListTile(
//                     title: Text(
//                       product['productname']
//                     ),
//                     subtitle: Text(
//                       '\$${product['productsellingprice']}'
//                     ),
//                     onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => ProductDetailsScreen(
//                             productId: product.id,
//                           ),
//                         ),
//                       );
//                     },
//                   );
//                 },
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
