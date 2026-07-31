// import 'package:flutter/material.dart';

// class FilterButton extends StatelessWidget {
//   final String label;
//   final bool selected;
//   final VoidCallback onTap;

//   const FilterButton({
//     Key? key,
//     required this.label,
//     required this.selected,
//     required this.onTap,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(
//             horizontal: 12, vertical: 6), // Reduced size
//         decoration: BoxDecoration(
//           color: selected ? Colors.orangeAccent : Colors.grey[200],
//           borderRadius:
//               BorderRadius.circular(12), // Slightly reduced corner radius
//           boxShadow: selected
//               ? [
//                   BoxShadow(
//                     color: Colors.orangeAccent.withOpacity(0.5),
//                     blurRadius: 8,
//                     spreadRadius: 1,
//                     offset: const Offset(0, 4),
//                   ),
//                 ]
//               : [],
//         ),
//         child: Text(
//           label,
//           style: TextStyle(
//             color: selected ? Colors.white : Colors.black,
//             fontSize: 14, // Reduced font size
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//     );
//   }
// }

// void main() {
//   runApp(const MaterialApp(home: TestPage()));
// }

// class TestPage extends StatefulWidget {
//   const TestPage({Key? key}) : super(key: key);

//   @override
//   _TestPageState createState() => _TestPageState();
// }

// class _TestPageState extends State<TestPage> {
//   String selectedFilter = "FLASH DEALS";

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Filter Buttons"),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             FilterButton(
//               label: "FLASH DEALS",
//               selected: selectedFilter == "FLASH DEALS",
//               onTap: () {
//                 setState(() {
//                   selectedFilter = "FLASH DEALS";
//                 });
//               },
//             ),
//             FilterButton(
//               label: "SPECIAL DEALS",
//               selected: selectedFilter == "SPECIAL DEALS",
//               onTap: () {
//                 setState(() {
//                   selectedFilter = "SPECIAL DEALS";
//                 });
//               },
//             ),
//             FilterButton(
//               label: "TRENDING DEALS",
//               selected: selectedFilter == "TRENDING DEALS",
//               onTap: () {
//                 setState(() {
//                   selectedFilter = "TRENDING DEALS";
//                 });
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
