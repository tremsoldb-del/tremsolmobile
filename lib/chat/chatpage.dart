// import 'package:flutter/material.dart';
// import 'package:dialog_flowtter/dialog_flowtter.dart';

// class ChatPage extends StatefulWidget {
//   @override
//   _ChatPageState createState() => _ChatPageState();
// }

// class _ChatPageState extends State<ChatPage> {
//   late DialogFlowtter dialogFlowtter;
//   final TextEditingController _messageController = TextEditingController();
//   final List<Map<String, dynamic>> _messages = [];

//   @override
//   void initState() {
//     super.initState();
//     initializeDialogFlow();
//   }

//   void initializeDialogFlow() async {
//     try {
//       dialogFlowtter = await DialogFlowtter(
//         jsonPath: "assets/dialogflow_auth.json",
//       );
//     } catch (e) {
//       debugPrint("Error initializing DialogFlowtter: $e");
//     }
//   }

//   @override
//   void dispose() {
//     _messageController.dispose();
//     super.dispose();
//   }

//   void sendMessage(String text) async {
//     if (text.isEmpty) return;

//     setState(() {
//       _messages.add({"message": text, "isUserMessage": true});
//     });
//     _messageController.clear();

//     try {
//       final response = await dialogFlowtter.detectIntent(
//         queryInput: QueryInput(
//           text: TextInput(text: text, languageCode: 'en'),
//         ),
//       );

//       if (response.message != null) {
//         final botMessage = response.message?.text?.text?.first ?? "No response";
//         setState(() {
//           _messages.add({"message": botMessage, "isUserMessage": false});
//         });
//       }
//     } catch (e) {
//       debugPrint("Error detecting intent: $e");
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Chat with Bot"),
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: ListView.builder(
//               itemCount: _messages.length,
//               itemBuilder: (context, index) {
//                 final message = _messages[index];
//                 final isUserMessage = message["isUserMessage"] as bool;
//                 return Align(
//                   alignment: isUserMessage
//                       ? Alignment.centerRight
//                       : Alignment.centerLeft,
//                   child: Container(
//                     margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
//                     padding: EdgeInsets.all(10),
//                     decoration: BoxDecoration(
//                       color:
//                           isUserMessage ? Colors.blue[100] : Colors.grey[300],
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: Text(
//                       message["message"],
//                       style: TextStyle(fontSize: 16),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _messageController,
//                     decoration: InputDecoration(
//                       hintText: "Type your message...",
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                     ),
//                   ),
//                 ),
//                 SizedBox(width: 8),
//                 IconButton(
//                   icon: Icon(Icons.send, color: Colors.blue),
//                   onPressed: () => sendMessage(_messageController.text),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
