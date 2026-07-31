import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tremsolapp/shop/orderpage.dart';
import 'package:tremsolapp/shop/shop_screen.dart';


class CODOrderScreen extends StatefulWidget {
  final String orderId;

  const CODOrderScreen({super.key, required this.orderId});

  @override
  _CODOrderScreenState createState() => _CODOrderScreenState();
}

class _CODOrderScreenState extends State<CODOrderScreen> {
  Map<String, dynamic>? orderData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrderData();
    _loadCurrencyData();
  }

  Future<void> _fetchOrderData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('ordersitems')
          .doc(widget.orderId)
          .get();

      if (doc.exists) {
        setState(() {
          orderData = doc.data();
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order not found')),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching order: $e')),
      );
    }
  }

  String _formatDeliveryDate(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Processing';
    }
    DateTime date = timestamp.toDate();
    return DateFormat('MMMM d').format(date); // Example: April 26
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

  String? currencySymbol;
  double? exchangeRate;

  //added 08-12-2024
  // Function to load currency data
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


  double _convertPrice(double price) {
    if (exchangeRate != null) {
      return price * exchangeRate!;
    }
    return price; // Default price without conversion
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (orderData == null) {
      return const Scaffold(
        body: Center(child: Text('Order details not available')),
      );
    }

    String orderNumber = widget.orderId;
    String deliveryDate = _formatDeliveryDate(orderData?['deliveryDate']);
    List<dynamic> cartItems = orderData?['items'] ?? [];
    // Map<String, dynamic> shippingInfo = orderData?['shippingAddress'] ?? {};

    double shippingFee = (orderData?['shippingFee'] ?? 0).toDouble();
    double totalAmount = (orderData?['totalAmount'] ?? 0).toDouble();
    String shippingAddress =
        orderData?['shippingAddress'] ?? 'Address not provided';
    final paymentMethod = (orderData?['paymentMethod'] ?? '').toString();
    final status = (orderData?['status'] ?? 'Processing').toString();
    final isProtectedCod = paymentMethod == 'Protected COD';
    final amountPaid = (orderData?['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final amountDueOnDelivery =
        (orderData?['amountDueOnDelivery'] as num?)?.toDouble() ??
            (totalAmount + shippingFee - amountPaid);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height - 48, // 48 for padding
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 100,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isProtectedCod ? 'Order Confirmed' : 'Success',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isProtectedCod
                          ? 'Your commitment payment was received. Pay the remaining balance when your order is delivered.'
                          : 'Thank you for your purchase!',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Order ID: $orderNumber',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- Order Summary Section ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Order Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(height: 24, thickness: 1),
                          // List Items
                          if (cartItems.isNotEmpty)
                            ...cartItems.map((item) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(item['productName'] ?? 'Item',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines:
                                                1 // <-- this prevents overflow
                                            ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Qty: ${item['quantity'] ?? 1}'),
                                        Text(
                                          '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice((item['productsellingprice'] ?? 0).toDouble()))}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const Divider(height: 30),

                          // Shipping Fee
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Shipping Fee',
                                style: TextStyle(fontSize: 16),
                              ),
                              Text(
                                '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(shippingFee.toDouble()))}',
                                style: const TextStyle(fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Total Amount
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice((totalAmount + shippingFee).toDouble()))}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          if (isProtectedCod) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F1FB),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFB7CEE7),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    status,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF002A5C),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Paid now'),
                                      Text(
                                        '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(amountPaid))}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Due on delivery'),
                                      Text(
                                        '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(amountDueOnDelivery))}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),
                          const Text(
                            'Shipping',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _capitalizeFirstLetter(shippingAddress),
                            style: const TextStyle(
                                fontSize: 16, color: Colors.black54),
                          ),

                          /*    const SizedBox(height: 8),
                            Text(
                              'Delivery by $deliveryDate',
                              style: const TextStyle(fontSize: 16, color: Colors.black54),
                            ),*/
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),
                    //const Spacer(),

                    // --- Bottom Buttons ---
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00195E),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      OrderDetailPage(orderId: widget.orderId),
                                ),
                              );
                            },
                            child: const Text(
                              'Track Order',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Color(0xFF00195E)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              //   Navigator.popUntil(context, (route) => route.isFirst);

                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const ShopScreen()),
                              );
                            },
                            child: const Text(
                              'Continue Shopping',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF00195E),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
