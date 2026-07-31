import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pay_with_paystack/pay_with_paystack.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../homescreen.dart';
import 'payment_options.dart';
import 'shipping_address/add_shipping_address.dart';
import 'shipping_address/edit_shippingaddress.dart';
import 'shop_screen.dart';


class CheckoutPage extends StatefulWidget {
  final double tAmount; // Field to hold the passed value

  const CheckoutPage({super.key, required this.tAmount});

  @override
  _CheckoutPageState createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _shippingAddressController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _orderNotesController =
      TextEditingController(); // Controller for order notes
  bool _isShippingAddressExpanded = false;
  bool _isOrderNotesExpanded =
      false; // To control the visibility of the order notes section
  bool _hasShippingAddress = false;
  Map<String, dynamic>? _shippingAddress;

  double totalAmount = 0.0;
  double shippingFee = 0.0;

  String? currencySymbol;
  double? exchangeRate;

  String uidlocvar = "";

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchShippingFee();
    _calculateInitialTotalAmount();
    _loadCurrencyData();

    _fetchShippingAddress();
  }



//added 27 04 2025
bool _isLoading = false; // 1. Add this at the top of your StatefulWidget

  
  
//added 2-1-2024
//updated 27 04 2025


void _navigateToPaymentOptions() async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("You need to be signed in to proceed.")),
    );
    return;
  }

  setState(() {
    _isLoading = true; // 2. Start loading
  });

  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('shippingaddress')
        .where('uid', isEqualTo: userId)
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No default shipping address found.")),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final defaultAddress = querySnapshot.docs.first.data();

    final shippingAddress = [
      defaultAddress['address'] ?? '',
      defaultAddress['city'] ?? '',
      defaultAddress['region'] ?? '',
      defaultAddress['zipcode'] ?? '',
      defaultAddress['country'] ?? '',
    ].where((field) => field.isNotEmpty).join(', ');

    final userRegion = defaultAddress['region'] ?? '';

    setState(() {
      _isLoading = false; // 3. Stop loading before navigating
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentOptionsPage(
          region: userRegion,
          totalAmount: widget.tAmount,
          shippingFee: shippingFee,
          orderNotes: _orderNotesController.text,
          shippingAddress: shippingAddress,
          
        ),
      ),
    );
  } catch (e) {
    setState(() {
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error fetching default address: $e")),
    );
  }
}

 



  //added 08-12-2024
  //amended 28 -11- 2025
 bool _currencyLoaded = false;

Future<void> _loadCurrencyData() async {
  final prefs = await SharedPreferences.getInstance();

  final base = prefs.getString('baseCurrency') ?? 'GHS';
  final selected = prefs.getString('selectedCurrency') ?? base;
  final rate = prefs.getDouble('conversionRate') ?? 1.0;

  setState(() {
    currencySymbol = selected;  // 👈 show user’s chosen currency code
    exchangeRate = rate;        // 👈 base → selected
    _currencyLoaded = true;
  });
}

  double _convertPrice(dynamic price) {
    if (price == null) {
      throw ArgumentError('Price cannot be null');
    }

    // Ensure the price is treated as a double
    final double parsedPrice =
        (price is int) ? price.toDouble() : (price as double);

    if (exchangeRate != null) {
      return parsedPrice * exchangeRate!;
    }

    return parsedPrice; // Default price without conversion
  }

  Future<void> _fetchUserData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        _fullNameController.text = userData['fullname'] ?? '';
        _emailController.text = userData['email'] ?? '';
        _shippingAddressController.text = userData['shippingaddress'] ?? '';
        _phoneController.text = userData['phone'] ?? '';

        setState(() {
          _hasShippingAddress = userData['shippingaddress'] != null &&
              userData['shippingaddress'] != '';
        });
      }
    }
  }

 
 
  Future<void> _fetchShippingFee() async {
    DocumentSnapshot settingsDoc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('doc1')
        .get();
        
    // setState(() {
    //   shippingFee = settingsDoc['shipping_fee']?.toDouble() ?? 0.0;
    // }
    
    // );


    setState(() {
  final v = settingsDoc['shipping_fee'];
  shippingFee = v is num
      ? v.toDouble()
      : (v is String ? double.tryParse(v.replaceAll(RegExp(r'[^0-9\.\-]'), '')) ?? 0.0 : 0.0);
});

  }

//   Future<void> _fetchShippingFee() async {
//   final doc = await FirebaseFirestore.instance
//       .collection('settings')
//       .doc('doc1')
//       .get();

//   final data = doc.data() as Map<String, dynamic>?;
//   double fee = 0.0;

//   if (data != null) {
//     final raw = data['shipping_fee'];

//     if (raw is num) {
//       fee = raw.toDouble();
//     } else if (raw is String) {
//       // remove currency/commas/spaces if any, then parse
//       final cleaned = raw.replaceAll(RegExp(r'[^0-9\.\-]'), '');
//       fee = double.tryParse(cleaned) ?? 0.0;
//     } // else keep 0.0
//   }

//   setState(() => shippingFee = fee);
// }


  Future<void> _calculateInitialTotalAmount() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('cartitems')
        .where('userId', isEqualTo: userId)
        .get();

    double newTotalAmount = 0.0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      newTotalAmount += (data['totalPrice'] ?? 0.0).toDouble();
    }

    setState(() {
      totalAmount = newTotalAmount;
    });
  }

  Future<void> _processPayment() async {
    final email = _emailController.text;
    final orderNotes = _orderNotesController.text;

    if (email.isEmpty) {
      _showSnackbar('Please fill in all fields');
      return;
    }

    final uniqueTransRef = PayWithPayStack().generateUuidV4();

    PayWithPayStack().now(
      context: context,
      secretKey: "sk_test_b39874d55f8ee9be128b489a7fd99ec8e01a9036",
      customerEmail: email,
      reference: uniqueTransRef,
      currency: "GHS",
      amount: (totalAmount - (totalAmount - widget.tAmount) + shippingFee),
      callbackUrl: 'https://your.callback.url',
      transactionCompleted: () async {
        print("Transaction Successful");
        await _moveCartItemsToOrders(orderNotes);
     //==   sendEmailFromFirestore() ;
    //     sendEmailFromFirestore(  orderNumber: 'orderId',
    //  userName: 'userName');
        _navigateToSuccessScreen();
        
      },
      transactionNotCompleted: () {
        print("Transaction Not Successful!");
      },
    );
  }

     //added 27-12-2024
  String _capitalizeFirstLetter(String input) {
    if (input.isEmpty) return ''; // Handle empty string case

    return input
        .split(' ')
        .where((word) => word.isNotEmpty) // Ensure empty words are removed
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }


  //added 13 04 2025
Future<void> _moveCartItemsToOrders(String orderNotes) async {
  final user = FirebaseAuth.instance.currentUser;
  final userId = user?.uid;
  final userEmail = user?.email;

  if (userId == null || userEmail == null) return;

  // Fetch the user's cart items
  final cartItems = await FirebaseFirestore.instance
      .collection('cartitems')
      .where('userId', isEqualTo: userId)
      .get();

  if (cartItems.docs.isEmpty) {
    print('No items in the cart to move.');
    return;
  }

  // Prepare the items for the order
  final List<Map<String, dynamic>> items = cartItems.docs.map((doc) => doc.data()).toList();

  // Create an order in the 'ordersitems' collection
  final orderRef = await FirebaseFirestore.instance.collection('ordersitems').add({
    'userId': userId,
    'email': userEmail,
    'totalAmount': totalAmount, // assume this is defined in your widget
    'shippingFee': shippingFee, // assume this is defined in your widget
    'orderNotes': orderNotes,
    'status': 'Processing',
    'items': items,
    'timestamp': Timestamp.now(),
  });

  // Add the orderId field using the generated document ID
  final orderId = orderRef.id;
  await orderRef.update({'orderId': orderId});

  // Clear the cart
  final batch = FirebaseFirestore.instance.batch();
  for (var item in cartItems.docs) {
    batch.delete(item.reference);
  }
  await batch.commit();

  print('Cart items moved to orders and cleared successfully.');

  // 🔍 Fetch username from 'users' collection
  String userName = 'Customer';
  final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
  if (userDoc.exists && userDoc.data()!.containsKey('username')) {
    userName = userDoc['username'];
  }


}


 /*==Future<void> sendEmailFromFirestore() async {
    try {
      // 🔐 Step 1: Get SMTP email & password from Firestore
      final docSnapshot = await FirebaseFirestore.instance
          .collection('settings')
          .doc('doc3')
          .get();

      if (!docSnapshot.exists) {
        print("Settings document not found.");
        return;
      }

      final data = docSnapshot.data()!;
      final String email = data['email'];
      final String password = data['pass'];

      // 📬 Step 2: Set up SMTP server
      final smtpServer = SmtpServer(
  'smtp.gmail.com',
  port: 465,
  username: email,
  password: password,
  ssl: true, // <- Use SSL
);


      // 📧 Step 3: Create email message
      final message = Message()
        ..from = Address(email, 'Tremsol')
        ..recipients.add('eganeboe@gmail.com')
        ..subject = 'Order Request'
        ..text = 'Hello, I would like to place an order.';

      // 🚀 Step 4: Send the email
      final sendReport = await send(message, smtpServer);
      print('Message sent: ' + sendReport.toString());
    } on MailerException catch (e) {
      print('Failed to send email: $e');
    } catch (e) {
      print('Error: $e');
    }
  }*/



 






  //=================

  void _navigateToSuccessScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PaymentSuccessScreen()),
    );
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  //added 1-1-24
  Future<void> _fetchShippingAddress() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      QuerySnapshot shippingDocs = await FirebaseFirestore.instance
          .collection('shippingaddress')
          .where('uid', isEqualTo: userId)
          .where('isDefault', isEqualTo: true)
          .get();

      if (shippingDocs.docs.isNotEmpty) {
        final shippingData =
            shippingDocs.docs.first.data() as Map<String, dynamic>;

        setState(() {
          _shippingAddress = {
            'fullname': shippingData['fullname'] ?? '',
            'id': shippingData['id'] ?? '',
            'address': shippingData['address'] ?? '',
            'city': shippingData['city'] ?? '',
            'region': shippingData['region'] ?? '',
            'zipcode': shippingData['zipcode'] ?? '',
            'country': shippingData['country'] ?? '',
          };
        });
      } else {
        setState(() {
          _shippingAddress = null;
        });
      }
    }
  }

  Widget _buildShippingAddressSection() {
    if (_shippingAddress == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // const Text(
          //   'Shipping Address',
          //   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          // ),
          const SizedBox(height: 10),
          const Text('No default shipping address found.'),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddShippingAddressPage(),
                ),
              );
            },
            child: const Text('Add Address'),
          ),
        ],
      );
    }

    // Safely check and display the shipping address
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _shippingAddress!['fullname'] ?? 'No Name',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(_shippingAddress!['address'] ?? 'No Address'),
                  Text(
                    '${_shippingAddress!['city'] ?? 'No City'}, '
                    '${_shippingAddress!['region'] ?? 'No Region'} '
                    '${_shippingAddress!['zipcode'] ?? 'No Zipcode'}',
                  ),
                  Text(_shippingAddress!['country'] ?? 'No Country'),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                // Check for the existence of 'id' and handle null
                final addressId = _shippingAddress!['id'];
                if (addressId == null || addressId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Address ID is missing or invalid."),
                    ),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditShippingAddressPage(
                      addressId: addressId,
                    ),
                  ),
                );
              },
              child: const Text(
                'Change',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Center(
        child: Text('You need to be signed in to view your cart.'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Order Confirmation',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          /*  IconButton(
            icon: const Icon(
              Icons.favorite_border_outlined,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WishlistPage(userId: userId),
                ),
              );
            },
          ),*/
          IconButton(
            icon: const Icon(
              Icons.home,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
          ),
        ],
        backgroundColor: const Color(0xFF002A5C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Shipping Address',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  
                  _buildShippingAddressSection(),
                  const SizedBox(height: 20),
                  _buildOrderNotesSection(), // Collapsible section for order notes
                  const SizedBox(height: 20),
                  const Text(
                    'Cart Items',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('cartitems')
                        .where('userId', isEqualTo: userId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
          
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('Your cart is empty.'));
                      }
          
                      final cartItems = snapshot.data!.docs;
          
                      return Column(
                        children: cartItems.map((cartItem) {
                          final data = cartItem.data() as Map<String, dynamic>;
                          final int quantity = data['quantity'] ?? 1;
          
                          Color? color;
                          if (data['selectedColor'] != null &&
                              data['selectedColor'].isNotEmpty) {
                            color = Color(int.parse(
                                    data['selectedColor'].substring(1),
                                    radix: 16))
                                .withOpacity(1.0);
                          }
          


double imageSize = MediaQuery.of(context).size.width * 0.15; // ~15%

                          return SizedBox(
                            width: MediaQuery.of(context).size.width,
                            child: Card(
                              margin: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [


CachedNetworkImage(
  imageUrl: data['productImage'],
  width: imageSize,
  height: imageSize,
  fit: BoxFit.cover,
  placeholder: (context, url) => SizedBox(
    width: imageSize,
    height: imageSize,
    child: const Center(
      child: Icon(Icons.shopping_cart_outlined, size: 28, color: Colors.grey),
    ),
  ),
  errorWidget: (context, url, error) => Icon(Icons.broken_image, size: imageSize * 0.6),
),

                                     
                                     
                                     /*   Image.network(
                                          data['productImage'],
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        ),*/


                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                data['productName'],
                                                style:
                                                    const TextStyle(fontSize: 14),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                data['productDescription'] ?? '',
                                                style:
                                                    const TextStyle(fontSize: 12),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (color != null)
                                                Row(
                                                  children: [
                                                    const Text('Color: ',
                                                        style: TextStyle(
                                                            fontSize: 12)),
                                                    Container(
                                                      width: 16,
                                                      height: 16,
                                                      decoration: BoxDecoration(
                                                        color: color,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              if (data['selectedSize'] != null &&
                                                  data['selectedSize'].isNotEmpty)
                                                Text(
                                                  'Size: ${data['selectedSize']}',
                                                  style:
                                                      const TextStyle(fontSize: 12),
                                                ),
                                            ],
                                          ),
                                        ),
          
                                        /* IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.grey, size: 18),
                                          onPressed: () {
                                            _confirmRemoveFromCart(cartItem.id);
                                          },
                                        ),*/
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          
                                           // '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(productsellingprice.toDouble()))}',
                                          //'$currencySymbol ${_convertPrice(data['totalPrice']).toDouble().toStringAsFixed(2)}',
                                          
                                          '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(data['totalPrice']))}',
          
                                          
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Row(
                                          children: [],
                                        ),
          
                                        /*Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove),
                                              onPressed: () async {
                                                final minQuantity =
                                                    await _getProductMinQuantity(
                                                        data['productId']);
                                                if (quantity > minQuantity) {
                                                  _updateQuantity(
                                                      cartItem.id, quantity - 1);
                                                } else {
                                                  _showSnackbar(
                                                      'Cannot reduce below minimum quantity of $minQuantity');
                                                }
                                              },
                                            ),
                                            Text(quantity.toString()),
                                            IconButton(
                                              icon: const Icon(Icons.add),
                                              onPressed: () {
                                                _updateQuantity(
                                                    cartItem.id, quantity + 1);
                                              },
                                            ),
                                          ],
                                        ),*/
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
          
                  const SizedBox(height: 10),
                  const Text(
                    'Summary',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    // '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(data['totalPrice']))}',
                    'Subtotal: $currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(totalAmount))}',
                   // 'Subtotal: $currencySymbol ${_convertPrice(totalAmount).toStringAsFixed(2)}',
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                   // 'Coupon Discount : - ($currencySymbol ${_convertPrice(totalAmount - widget.tAmount).toStringAsFixed(2)})',
                       'Coupon Discount : - ($currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(totalAmount - widget.tAmount))})',
                   
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                  Text(
                    // 'Shipping Fee : $currencySymbol ${_convertPrice(shippingFee).toStringAsFixed(2)}',
                    'Shipping Fee : $currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(shippingFee))}',
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
          
                    'Total : $currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(totalAmount - (totalAmount - widget.tAmount) + shippingFee))}',
                    //'Total : $currencySymbol ${_convertPrice(totalAmount - (totalAmount - widget.tAmount) + shippingFee).toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
            // The loading overlay
    if (_isLoading) ...[
      Positioned.fill(
        child: Container(
          color: Colors.black.withOpacity(0.5), // semi-transparent black
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white, // or any color you want
            ),
          ),
        ),
      ),
    ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
              onPressed: () {
            _navigateToPaymentOptions();
          },         
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              backgroundColor: const Color(0xFFFFA500),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Proceed to Payment',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        
         
        ),
      ),
    );
  }


  Widget _buildOrderNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Additional Notes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(
                _isOrderNotesExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _isOrderNotesExpanded = !_isOrderNotesExpanded;
                });
              },
            ),
          ],
        ),
        if (_isOrderNotesExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextField(
                controller: _orderNotesController,
                maxLines: 4, // Make it multiline
                decoration: const InputDecoration(
                  labelText: 'Enter any additional notes for your order',
                  border: OutlineInputBorder(),
                )),
          ),
      ],
    );
  }

  Future<void> _addShippingAddress() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fullname': _fullNameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'shippingaddress': _shippingAddressController.text,
      });
      setState(() {
        _hasShippingAddress = true;
        _isShippingAddressExpanded = false;
      });
    }
  }

  Widget _buildTextField(TextEditingController controller, String labelText) {
    return TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
        ));
  }

  void _confirmRemoveFromCart(String cartItemId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Item'),
          content: const Text(
              'Are you sure you want to remove this item from the cart?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text('Remove'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _removeFromCart(cartItemId); // Perform the action
              },
            ),
          ],
        );
      },
    );
  }

  void _removeFromCart(String cartItemId) {
    FirebaseFirestore.instance.collection('cartitems').doc(cartItemId).delete();
    _calculateInitialTotalAmount();
  }

  Future<void> _updateQuantity(String cartItemId, int newQuantity) async {
    if (newQuantity < 1) {
      _removeFromCart(cartItemId);
      return;
    }

    try {
      final cartItemRef =
          FirebaseFirestore.instance.collection('cartitems').doc(cartItemId);
      final docSnapshot = await cartItemRef.get();
      final data = docSnapshot.data() as Map<String, dynamic>;

      final double unitPrice =
          (data['totalPrice'] / (data['quantity'] ?? 1)).toDouble();
      final double newTotalPrice = unitPrice * newQuantity;

      await cartItemRef.update({
        'quantity': newQuantity,
        'totalPrice': newTotalPrice,
      });

      setState(() {
        totalAmount = totalAmount - data['totalPrice'] + newTotalPrice;
      });
    } catch (e) {
      print('Error updating quantity: $e');
    }
  }

  Future<int> _getProductMinQuantity(String productId) async {
    try {
      final productRef =
          FirebaseFirestore.instance.collection('products').doc(productId);
      final productDoc = await productRef.get();

      if (productDoc.exists) {
        final data = productDoc.data() as Map<String, dynamic>;
        return data['productminquantity'] ?? 1;
      }
    } catch (e) {
      print('Error fetching product minimum quantity: $e');
    }
    return 1;
  }
}

// Payment success screen
class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Successful'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Thank you for your purchase!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const ShopScreen()),
                );
              },
              child: const Text('Buy Again'),
            ),
          ],
        ),
      ),
    );
  }
}
