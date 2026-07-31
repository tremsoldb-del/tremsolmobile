import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  _AddProductPageState createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controllers for form fields
  final TextEditingController productNameController = TextEditingController();
  final TextEditingController productDescriptionController =
      TextEditingController();
  final TextEditingController productCategoryController =
      TextEditingController();
  final TextEditingController ratingController = TextEditingController();
  final TextEditingController productMinQuantityController =
      TextEditingController();
  final TextEditingController costPerItemController = TextEditingController();
  final TextEditingController productStateController = TextEditingController();
  final TextEditingController productLocationController =
      TextEditingController();
  final TextEditingController uidController = TextEditingController();
  final TextEditingController videoUrlController = TextEditingController();
  final TextEditingController comparePriceController = TextEditingController();
  final TextEditingController productSubCatController = TextEditingController();
  final TextEditingController productCompanyController =
      TextEditingController();
  final TextEditingController supplierNameController = TextEditingController();
  final TextEditingController skuController = TextEditingController();
  final TextEditingController productsellingpriceController = TextEditingController();
  final TextEditingController productDiscPriceController =
      TextEditingController();
  final TextEditingController deliveryDaysController = TextEditingController();
  final TextEditingController commentCountController = TextEditingController();
  final TextEditingController productQuantityController =
      TextEditingController();
  final TextEditingController minimumOrderController = TextEditingController();
  final TextEditingController internationalShippingFeeController =
      TextEditingController();
  final TextEditingController localShippingFeeController =
      TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController typeController = TextEditingController();
  final TextEditingController viewCountController = TextEditingController();
  final TextEditingController sharesController = TextEditingController();
  final TextEditingController productDiscountPerController =
      TextEditingController();

  bool isPublish = false;

  Future<void> _addProduct() async {
    if (_formKey.currentState!.validate()) {
      await _firestore.collection('products').add({
        'out_of_stock': null,
        'productdescription': productDescriptionController.text,
        'productcategory': productCategoryController.text,
        'rating': double.tryParse(ratingController.text) ?? 0,
        'productminquantity':
            int.tryParse(productMinQuantityController.text) ?? 0,
        'hs_code': null,
        'cost_per_item': costPerItemController.text,
        'productcustomers': [],
        'productstate': productStateController.text,
        'productlocation': productLocationController.text,
        'createdAt': Timestamp.now(),
        'uid': uidController.text,
        'videoUrl': videoUrlController.text,
        'compare_price': double.tryParse(comparePriceController.text) ?? 0,
        'productsubcat': productSubCatController.text,
        'international_shipping': null,
        'productname': productNameController.text,
        'productcompany': productCompanyController.text,
        'product_sizes': [],
        'id': _firestore.collection('products').doc().id,
        'closedAt': null,
        'supplier_name': supplierNameController.text,
        'sku': skuController.text,
        'productsellingprice': double.tryParse(productsellingpriceController.text) ?? 0,
        'productdiscprice': productDiscPriceController.text,
        'updatedAt': Timestamp.now(),
        'likes': [],
        'image': '',
        'images': [],
        'track_quantity': null,
        'delivery_days': int.tryParse(deliveryDaysController.text) ?? 0,
        'tax': null,
        'charge_tax': null,
        'delivery_date': null,
        'commentcount': int.tryParse(commentCountController.text) ?? 0,
        'producttag': [],
        'productquantity': int.tryParse(productQuantityController.text) ?? 0,
        'minimumorder': int.tryParse(minimumOrderController.text) ?? 0,
        'product_colors': [],
        'international_shipping_fee': internationalShippingFeeController.text,
        'local_shipping_fee': localShippingFeeController.text,
        'username': usernameController.text,
        'isPublish': isPublish,
        'type': int.tryParse(typeController.text) ?? 0,
        'viewscount': int.tryParse(viewCountController.text) ?? 0,
        'shares': int.tryParse(sharesController.text) ?? 0,
        'productdiscountper': productDiscountPerController.text,
        'prodctdescription': productDescriptionController.text,
        'video_url': videoUrlController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product added successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                    controller: productNameController,
                    decoration: const InputDecoration(labelText: 'Product Name')),
                TextFormField(
                    controller: productDescriptionController,
                    decoration:
                        const InputDecoration(labelText: 'Product Description')),
                TextFormField(
                    controller: productCategoryController,
                    decoration: const InputDecoration(labelText: 'Product Category')),
                TextFormField(
                    controller: ratingController,
                    decoration: const InputDecoration(labelText: 'Rating'),
                    keyboardType: TextInputType.number),
                TextFormField(
                    controller: productMinQuantityController,
                    decoration: const InputDecoration(labelText: 'Min Quantity'),
                    keyboardType: TextInputType.number),
                TextFormField(
                    controller: productsellingpriceController,
                    decoration: const InputDecoration(labelText: 'Product Price'),
                    keyboardType: TextInputType.number),
                SwitchListTile(
                  title: const Text('Publish Product?'),
                  value: isPublish,
                  onChanged: (value) {
                    setState(() {
                      isPublish = value;
                    });
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _addProduct,
                  child: const Text('Add Product'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
