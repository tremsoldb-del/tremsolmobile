// import 'package:flutter/material.dart';
// import 'package:tremsolapp/custommedia_slider.dart';

// class ProductMediaWidget extends StatefulWidget {
//   final String? videoUrl;
//   final List<String> images;

//   const ProductMediaWidget(String? s, List list, {Key? key, this.videoUrl, required this.images}) : super(key: key);

//   @override
//   _ProductMediaWidgetState createState() => _ProductMediaWidgetState();
// }

// class _ProductMediaWidgetState extends State<ProductMediaWidget> {
//   late PageController _pageController;
//   int _currentPage = 0;

//   @override
//   void initState() {
//     super.initState();
//     _pageController = PageController();
//   }

//   @override
//   void dispose() {
//     _pageController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     double screenHeight = MediaQuery.of(context).size.height;
//     int totalItems = (widget.videoUrl != null && widget.videoUrl!.isNotEmpty ? 1 : 0) +
//         (widget.images?.length ?? 0);

//     if (totalItems == 0) {
//       return Container(
//         height: screenHeight * 0.25, // 25% of screen height
//         color: Colors.grey[200],
//         child: const Center(child: Text('No media available')),
//       );
//     }

//     return SizedBox(
//       height: screenHeight * 0.4, // 40% of screen height
//       child: Stack(
//         children: [
//           PageView.builder(
//             controller: _pageController,
//             itemCount: totalItems,
//             onPageChanged: (index) {
//               setState(() {
//                 _currentPage = index;
//               });
//             },
//             itemBuilder: (context, index) {
//               if (index == 0 && widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
//                 return SizedBox(
//                   height: screenHeight * 0.4, // Match parent height
//                   child: VideoWidget(videoUrl: widget.videoUrl!),
//                 );
//               } else {
//                 final imageIndex =
//                     index - (widget.videoUrl != null && widget.videoUrl!.isNotEmpty ? 1 : 0);
//                 return Container(
//                   margin: const EdgeInsets.all(2),
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(8),
//                     image: DecorationImage(
//                       image: NetworkImage(widget.images![imageIndex]),
//                       fit: BoxFit.contain,
//                     ),
//                   ),
//                 );
//               }
//             },
//           ),

//           // Overlay for "Item X/Y"
//           Positioned(
//             top: 10,
//             right: 10,
//             child: Container(
//               padding: const EdgeInsets.all(6),
//               decoration: BoxDecoration(
//                 color: Colors.black.withOpacity(0.7),
//                 borderRadius: BorderRadius.circular(5),
//               ),
//               child: Text(
//                 'Item ${_currentPage + 1}/$totalItems',
//                 style: const TextStyle(fontSize: 16, color: Colors.white),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
