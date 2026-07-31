import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tremsolapp/shop/ratingandreview.dart';




class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  _OrderPageState createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  String? currencySymbol = "GHS";
  double? exchangeRate = 1.0;

  @override
  void initState() {
    super.initState();
    _loadCurrencyData();
  }

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
    return exchangeRate != null ? price * exchangeRate! : price;
  }


  double _asDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('ordersitems')
              .where('userId', isEqualTo: userId)
              .snapshots(),
          builder: (context, snapshot) {
            int orderCount = 0;

            if (snapshot.hasData) {
              orderCount = snapshot.data!.docs.length;
            }

            return Text(
              'My Orders ($orderCount)',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
              ),
            );
          },
        ),
        backgroundColor: const Color(0xFF002A5C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: userId == null
          ? const Center(
              child: Text(
                'Please log in to view your orders',
                style: TextStyle(fontSize: 16),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ordersitems')
                  .where('userId', isEqualTo: userId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print('Error fetching orders: ${snapshot.error}');
                  return const Center(
                    child: Text(
                      'Error fetching orders. Please try again later.',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'You have no orders',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                final orders = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final orderDoc = orders[index];
                    final orderData = orderDoc.data() as Map<String, dynamic>;
                    final orderId = orderDoc.id;
                   final totalAmount = _asDouble(orderData['totalAmount']);
final shippingFee = _asDouble(orderData['shippingFee']);

                    final status = (orderData['status'] ?? 'Unknown').toString();
                    final timestamp = orderData['timestamp'];

                    final orderDate = timestamp is Timestamp
                        ? timestamp.toDate()
                        : DateTime.now();
                    final formattedDate =
                        DateFormat('EEEE, d MMMM yyyy').format(orderDate);

                    final convertedTotal =
                        _convertPrice(totalAmount + shippingFee);

                    final isCanceled = status == 'Canceled' ||
                        status == 'Cancelled Before Dispatch';
                    final isDeliveryException = status == 'Customer Unreachable' ||
                        status == 'Customer Rejected Delivery' ||
                        status == 'Delivery Failed' ||
                        status == 'Disputed';
                    final cardColor = isCanceled
                        ? Colors.red.shade100
                        : (isDeliveryException
                            ? Colors.orange.shade50
                            : Colors.white);

                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.only(bottom: 16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Status: $status',
                              style: TextStyle(
                                fontSize: 14,
                                color: isCanceled
                                    ? Colors.red
                                    : (isDeliveryException
                                        ? Colors.orange.shade900
                                        : Colors.black),
                                fontWeight: (isCanceled || isDeliveryException)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Total: $currencySymbol ${convertedTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OrderDetailPage(
                                      orderId: orderId,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                              ),
                              child: const Text(
                                'View Details',
                                style: const TextStyle(
                                    fontFamily:
                                        'Poppins', // Ensure your desired font is applied
                                    fontWeight: FontWeight
                                        .w500, // Optional: Customize weight/style
                                    fontSize: 16, // Optional: Set font size
                                    color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class OrderDetailPage extends StatefulWidget {
  final String orderId; // Pass the orderId to fetch the order details

  const OrderDetailPage({super.key, required this.orderId});

  @override
  _OrderDetailPageState createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  double _asDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  String? currencySymbol;
  double? exchangeRate;
  Map<String, dynamic>? orderData;
  bool isLoading = true;
  bool _isSubmittingDispute = false;

  @override
  void initState() {
    super.initState();
    _loadCurrencyData();
    _fetchOrderDetails();
  }

  //added 22-12-2024
  String _capitalizeFirstLetter(String input) {
    if (input.isEmpty) return ''; // Handle empty string case

    return input
        .split(' ')
        .where((word) => word.isNotEmpty) // Ensure empty words are removed
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

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


  Future<void> _fetchOrderDetails() async {
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

  Future<void> _cancelOrder() async {
    try {
      final orderId = widget.orderId;

      // Fetch the latest order status from Firestore
      final orderSnapshot = await FirebaseFirestore.instance
          .collection('ordersitems')
          .doc(orderId)
          .get();

      if (!orderSnapshot.exists) {
        throw Exception('Order not found');
      }

      final orderData = orderSnapshot.data() as Map<String, dynamic>;
      final currentStatus = orderData['status'];

      // Orders can only be cancelled before dispatch.
      const cancellableStatuses = {
        'Processing',
        'Confirmed – Delivery Fee Paid',
      };
      if (!cancellableStatuses.contains(currentStatus)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Order cannot be canceled. Current status: $currentStatus'),
          ),
        );
        return;
      }

      // Show confirmation dialog to the user
      final bool confirm = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Confirm Cancellation'),
                content:
                    const Text('Are you sure you want to cancel this order?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Yes'),
                  ),
                ],
              );
            },
          ) ??
          false;

      // If the user does not confirm, exit
      if (!confirm) {
        return;
      }

      final isProtectedCod =
          (orderData['paymentMethod'] ?? '').toString() == 'Protected COD';
      final cancellationStatus =
          isProtectedCod ? 'Cancelled Before Dispatch' : 'Canceled';

      await FirebaseFirestore.instance
          .collection('ordersitems')
          .doc(orderId)
          .update({
        'status': cancellationStatus,
        'canceledAt': FieldValue.serverTimestamp(),
        if (isProtectedCod) 'codCancellationReviewRequired': true,
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': cancellationStatus,
            'at': Timestamp.now(),
          }
        ]),
      });

      setState(() {
        orderData['status'] = cancellationStatus;
        orderData['canceledAt'] = DateTime.now();
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order canceled successfully'),
        ),
      );
    } catch (error) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel order: $error'),
        ),
      );
    }
  }

  Future<void> _submitCodDispute() async {
    final currentData = orderData;
    final user = FirebaseAuth.instance.currentUser;
    if (currentData == null || user == null || _isSubmittingDispute) return;

    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Dispute delivery report'),
          content: TextField(
            controller: reasonController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Briefly explain what happened',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = reasonController.text.trim();
                if (value.isNotEmpty) {
                  Navigator.of(dialogContext).pop(value);
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
    reasonController.dispose();

    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _isSubmittingDispute = true);
    try {
      final orderRef = FirebaseFirestore.instance
          .collection('ordersitems')
          .doc(widget.orderId);
      final disputeRef =
          FirebaseFirestore.instance.collection('codDisputes').doc();
      final previousStatus = (currentData['status'] ?? '').toString();
      final batch = FirebaseFirestore.instance.batch();

      batch.set(disputeRef, {
        'disputeId': disputeRef.id,
        'orderId': widget.orderId,
        'userId': user.uid,
        'reason': reason.trim(),
        'reportedStatus': previousStatus,
        'status': 'Open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(orderRef, {
        'status': 'Disputed',
        'disputedFromStatus': previousStatus,
        'codDisputeId': disputeRef.id,
        'codDisputeOpenedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': 'Disputed',
            'at': Timestamp.now(),
          }
        ]),
      });
      await batch.commit();

      if (!mounted) return;
      setState(() {
        orderData!['status'] = 'Disputed';
        orderData!['codDisputeId'] = disputeRef.id;
        _isSubmittingDispute = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your dispute has been submitted for review.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmittingDispute = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to submit dispute: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double _convertPrice(dynamic price) {
    if (price == null) {
      throw ArgumentError('Price cannot be null');
    }

    final double parsedPrice =
        (price is int) ? price.toDouble() : (price as double);

    if (exchangeRate != null) {
      return parsedPrice * exchangeRate!;
    }

    return parsedPrice;
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
        body: Center(child: Text('Order not found')),
      );
    }

    final items = orderData?['items'] as List<dynamic>? ?? [];
    final totalAmount = _asDouble(orderData?['totalAmount']);
    final shippingFee = _asDouble(orderData?['shippingFee']);
    final status = (orderData?['status'] ?? 'Unknown').toString();
    final paymentMethod = (orderData?['paymentMethod'] ?? '').toString();
    final isProtectedCod = paymentMethod == 'Protected COD';
    final amountPaid = _asDouble(orderData?['amountPaid']);
    final amountDueOnDelivery = _asDouble(
      orderData?['amountDueOnDelivery'] ??
          (totalAmount + shippingFee - amountPaid),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            )),
        backgroundColor: const Color(0xFF002A5C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body:  SafeArea(
        child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //         Text(
                  //   'Order ID: $orderId', // <-- Add this line
                  //   style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  // ),
                  const SizedBox(height: 8),
                  Text(
                    'Status: $status',
                    style: const TextStyle(fontSize: 17, 
                   // fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 17),
                  const Text(
                    'Items:',
                    style: TextStyle(fontSize: 16, 
                    //fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index] as Map<String, dynamic>;
                          final productId = item['productId'] ?? '';
                          final productName =
                              item['productName'] ?? 'Unknown Product';
                          final quantity = item['quantity'] ?? 1;
                          final price = item['totalPrice'] ?? 0.0;
                          final imageUrl = item['productImage'] ?? '';
            
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                leading: imageUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          fadeInDuration: const Duration(milliseconds: 120),
                                          placeholder: (context, url) => Container(
                                            width: 50,
                                            height: 50,
                                            color: Colors.grey.shade100,
                                            alignment: Alignment.center,
                                            child: const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => const Icon(
                                            Icons.image_not_supported,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.image_not_supported,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                title: Text(
                                  _capitalizeFirstLetter(productName),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                subtitle: Text(
                                  'Quantity: $quantity',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                trailing: Text(
                                  '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(price))}',
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (status == 'Delivered')
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 72.0, bottom: 12.0),
                                  child: FutureBuilder<QuerySnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('ratingreview')
                                        .where('productId', isEqualTo: productId)
                                        .where('userId',
                                            isEqualTo: FirebaseAuth
                                                .instance.currentUser!.uid)
                                        .get(),
                                    builder: (context, snapshot) {
                                      final hasRated = snapshot.hasData &&
                                          snapshot.data!.docs.isNotEmpty;
            
                                      return hasRated
                                          ? Text(
                                              'You rated this product',
                                              style:
                                                  TextStyle(color: Colors.grey[600]),
                                            )
                                          : ElevatedButton.icon(
                                              icon: const Icon(Icons.star,
                                                  color: Colors.amber),
                                              label: const Text('Rate this product'),
                                              onPressed: ()
                                               {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ReviewsPage(
                                                      productId: productId,
                                                      canPostReview: true,
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                    },
                                  ),
                                ),
                            ],
                          );
                        }),
                  ),
            
                  const SizedBox(height: 16),
                  if (isProtectedCod) ...[
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
                          const Text(
                            'Protected Cash on Delivery',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF002A5C),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Paid now: $currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(amountPaid))}',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Due on delivery: $currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(amountDueOnDelivery))}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    'Shipping Fee = $currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(shippingFee))}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total = $currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(totalAmount + shippingFee))}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
            
                  const SizedBox(height: 16),
                  if (status == 'Processing' ||
                      status == 'Confirmed – Delivery Fee Paid')
                    ElevatedButton(
                      onPressed: _cancelOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text(
                        'Cancel Order',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  if (isProtectedCod &&
                      (status == 'Customer Unreachable' ||
                          status == 'Customer Rejected Delivery' ||
                          status == 'Delivery Failed')) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed:
                          _isSubmittingDispute ? null : _submitCodDispute,
                      icon: _isSubmittingDispute
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.report_problem_outlined),
                      label: const Text('Dispute delivery report'),
                    ),
                  ],
                ],
              ),
            ),
      ),
       
    );
  }
}
