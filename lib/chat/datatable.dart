import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProductsTablePage extends StatefulWidget {
  const ProductsTablePage({super.key});

  @override
  _ProductsTablePageState createState() => _ProductsTablePageState();
}

class _ProductsTablePageState extends State<ProductsTablePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final int _rowsPerPage = 5; // Number of rows per page
  ProductDataTableSource? _dataSource; // Nullable _dataSource

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _dataSource = ProductDataTableSource(
          firestore: _firestore,
          rowsPerPage: _rowsPerPage,
          context: context,
        );
        _dataSource!.loadProducts(); // Initial load
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products Table'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _dataSource != null
                ? () => _dataSource!.showProductDialog(context)
                : null, // Prevent action until _dataSource is initialized
          ),
        ],
      ),
      body: _dataSource == null
          ? const Center(
              child: CircularProgressIndicator()) // Show loading state
          : SingleChildScrollView(
              child: PaginatedDataTable(
                header: const Text('Products'),
                rowsPerPage: _rowsPerPage,
                columns: const [
                  DataColumn(label: Text('Product Name')),
                  DataColumn(label: Text('Image')),
                  DataColumn(label: Text('Price')),
                  DataColumn(label: Text('Actions')),
                ],
                source: _dataSource!, // Non-nullable assertion here
              ),
            ),
    );
  }
}

class ProductDataTableSource extends DataTableSource {
  final FirebaseFirestore firestore;
  final int rowsPerPage;
  final BuildContext context;
  List<QueryDocumentSnapshot> products = [];
  bool isLoading = false;

  ProductDataTableSource({
    required this.firestore,
    required this.rowsPerPage,
    required this.context,
  });

  Future<void> loadProducts({DocumentSnapshot? startAfter}) async {
    if (isLoading) return;

    isLoading = true;
    notifyListeners();

    Query query = firestore
        .collection('products')
        .orderBy('productname')
        .limit(rowsPerPage);
    if (startAfter != null) query = query.startAfterDocument(startAfter);

    final QuerySnapshot snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      products.addAll(snapshot.docs);
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> showProductDialog(BuildContext context,
      {DocumentSnapshot? product}) async {
    // Implement dialog logic here
  }

  @override
  DataRow getRow(int index) {
    if (index >= products.length) {
      return const DataRow(cells: []);
    }

    final product = products[index];

    return DataRow(cells: [
      DataCell(Text(product['productname'] ?? 'N/A')),
      DataCell(Image.network(
        product['image'] ?? '',
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image),
      )),
      DataCell(Text(product['productsellingprice'] != null
          ? '\$${product['productsellingprice']}'
          : 'N/A')),
      DataCell(Row(
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => showProductDialog(context, product: product),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              await firestore.collection('products').doc(product.id).delete();
              loadProducts(); // Reload the data
            },
          ),
        ],
      )),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => products.length;

  @override
  int get selectedRowCount => 0;
}
