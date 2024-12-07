import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PreOrderPage extends StatefulWidget {
  @override
  _PreOrderPageState createState() => _PreOrderPageState();
}

class _PreOrderPageState extends State<PreOrderPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> allPendingPreOrders = [];
  Set<String> expandedBulkOrders = Set<String>();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllPendingPreOrders();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _sendSMSToUser(
      String contactNumber,
      String studentName,
      String studentNumber,
      double totalOrderPrice,
      List<Map<String, dynamic>> cartItems) async {
    try {
      List<String> itemDetails = [];
      double overallTotalPrice = 0.0;

      for (var item in cartItems) {
        String label = item['label'] ?? 'Item';
        int quantity = item['quantity'] ?? 1;
        double pricePerPiece = item['pricePerPiece'] is double
            ? item['pricePerPiece']
            : (item['pricePerPiece'] != null
                ? double.parse(item['pricePerPiece'].toString())
                : 0.0);

        double itemTotalPrice = pricePerPiece * quantity;
        overallTotalPrice += itemTotalPrice;

        itemDetails
            .add("$label (x$quantity) - ₱${itemTotalPrice.toStringAsFixed(2)}");
      }

      String itemNames = itemDetails.join(", ");
      String message =
          "Hello $studentName (Student ID: $studentNumber), your pre-order for $itemNames has been approved. Total Price: ₱${overallTotalPrice.toStringAsFixed(2)}.";

      // Print the composed message
      print("Composed SMS message: $message");

      final response = await http.post(
        Uri.parse('http://localhost:3000/send-sms'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'apikey': dotenv.env['APIKEY'] ?? '',
          'number': contactNumber,
          'message': message,
          'sendername': dotenv.env['SENDERNAME'] ?? 'Unistock',
        }),
      );

      if (response.statusCode == 200) {
        print("SMS sent successfully to $contactNumber");
      } else {
        print("Failed to send SMS. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error in _sendSMSToUser: $e");
    }
  }

  Future<void> _fetchAllPendingPreOrders() async {
    List<Map<String, dynamic>> pendingPreOrders = [];
    setState(() {
      isLoading = true;
    });

    QuerySnapshot usersSnapshot = await _firestore.collection('users').get();

    for (var userDoc in usersSnapshot.docs) {
      String userName = userDoc['name'] ?? 'Unknown User';
      String studentId =
          (userDoc.data() as Map<String, dynamic>).containsKey('studentId')
              ? userDoc['studentId']
              : 'Unknown ID';

      QuerySnapshot preordersSnapshot = await _firestore
          .collection('users')
          .doc(userDoc.id)
          .collection('preorders')
          .where('status', isEqualTo: 'pre-order confirmed')
          .get();

      for (var preorderDoc in preordersSnapshot.docs) {
        Map<String, dynamic> preOrderData =
            preorderDoc.data() as Map<String, dynamic>;

        List<dynamic> items = preOrderData['items'] ?? [];
        String label = items.length > 1
            ? "Bulk Order (${items.length} items)"
            : items[0]['label'];
        String preOrderDate = DateFormat('yyyy-MM-dd')
            .format((preOrderData['preOrderDate'] as Timestamp).toDate());

        pendingPreOrders.add({
          'userId': userDoc.id,
          'userName': userName,
          'studentId': studentId,
          'label': label,
          'category': items.length > 1 ? 'Multiple' : items[0]['category'],
          'courseLabel': items.length > 1
              ? 'Various'
              : (items[0]['courseLabel'] ?? 'Unknown CourseLabel'),
          'itemSize': items.length > 1 ? 'Various' : items[0]['itemSize'],
          'quantity': items.length > 1
              ? items.map((e) => e['quantity'] as int).reduce((a, b) => a + b)
              : items[0]['quantity'],
          'preOrderDate': preOrderDate,
          'items': items,
          'preOrderTimestamp': preOrderData['preOrderDate'] as Timestamp,
          'orderId': preorderDoc.id,
        });
      }
    }

    pendingPreOrders.sort(
        (a, b) => b['preOrderTimestamp'].compareTo(a['preOrderTimestamp']));

    setState(() {
      allPendingPreOrders = pendingPreOrders;
      isLoading = false;
    });
  }

  Future<void> _approvePreOrder(Map<String, dynamic> preOrder) async {
    try {
      String userId = preOrder['userId'] ?? '';
      String orderId = preOrder['orderId'] ?? '';
      String userName = preOrder['userName'] ?? 'Unknown User';
      String studentId = preOrder['studentId'] ?? 'Unknown ID';

      print('Processing pre-order for userId: $userId, orderId: $orderId');

      DateTime preOrderDate;
      if (preOrder['preOrderDate'] is Timestamp) {
        preOrderDate = (preOrder['preOrderDate'] as Timestamp).toDate();
      } else if (preOrder['preOrderDate'] is String) {
        preOrderDate = DateTime.parse(preOrder['preOrderDate']);
      } else {
        preOrderDate = DateTime.now();
      }

      if (userId.isEmpty || orderId.isEmpty) {
        throw Exception(
            'Invalid pre-order data: userId or orderId is missing.');
      }

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists || userDoc['contactNumber'] == null) {
        throw Exception('User profile not found or contact number is missing.');
      }

      String contactNumber = userDoc['contactNumber'];
      String studentName = userDoc['name'] ?? 'Unknown Name';
      String studentNumber = userDoc['studentId'] ?? 'Unknown ID';

      print('Retrieved user contact number: $contactNumber');

      DocumentSnapshot orderDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('preorders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      Map<String, dynamic> orderData = orderDoc.data() as Map<String, dynamic>;
      orderData['status'] = 'approved';

      double totalOrderPrice = 0.0;
      List<dynamic> orderItems = orderData['items'] ?? [];

      if (orderItems.isEmpty) {
        throw Exception('No items found in the pre-order');
      }

      print('Processing order items: ${orderItems.length} items');

      List<Map<String, dynamic>> approvedItems = [];

      for (var item in orderItems) {
        String label = (item['label'] ?? '').trim();
        if (label.isEmpty || label.toLowerCase() == 'unknown') {
          throw Exception('Invalid item label: $label');
        }
        String category = item['category'] ?? 'Unknown Category';
        String courseLabel = item['courseLabel'] ?? 'Unknown CourseLabel';
        String size = item['itemSize'] ?? 'Unknown Size';
        int quantity = item['quantity'] ?? 0;

        print(
            'Validating item: $label, category: $category, size: $size, quantity: $quantity');

        double pricePerPiece = await _fetchPricePerPiece(category, label, size,
            courseLabel: courseLabel);

        if (pricePerPiece <= 0) {
          throw Exception(
              "Failed to fetch pricePerPiece for $label in category $category.");
        }

        if (!await _validateStockAvailability(
            category, courseLabel, label, size, quantity)) {
          throw Exception('Insufficient stock for $label size $size.');
        }

        approvedItems.add({
          'category': category,
          'courseLabel': courseLabel,
          'itemSize': size,
          'label': label,
          'quantity': quantity,
          'pricePerPiece': pricePerPiece,
          'totalPrice': pricePerPiece * quantity,
        });

        totalOrderPrice += pricePerPiece * quantity;
      }

      print('Total order price calculated: $totalOrderPrice');

      await _firestore.collection('approved_preorders').doc(orderId).set({
        'userId': userId,
        'orderId': orderId,
        'userName': userName,
        'studentId': studentId,
        'preOrderDate': Timestamp.fromDate(preOrderDate),
        'status': 'approved',
        'totalOrderPrice': totalOrderPrice,
        'items': approvedItems,
      });

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('preorders')
          .doc(orderId)
          .delete();

      print('Pre-order approved and moved to approved_preorders collection.');

      await _sendSMSToUser(contactNumber, studentName, studentNumber,
          totalOrderPrice, approvedItems);
      await _sendNotificationToUser(userId, userName, approvedItems);
      await _fetchAllPendingPreOrders();

      print('Notifications sent and pending pre-orders fetched.');
    } catch (e) {
      print('Error in _approvePreOrder: $e');
    }
  }

  Future<double> _fetchPricePerPiece(String category, String label, String size,
      {String? courseLabel}) async {
    try {
      final normalizedCategory = category.toLowerCase().trim();
      final normalizedLabel = label.toLowerCase().trim();

      if (normalizedCategory == 'merch_and_accessories') {
        final categoryDoc = await _firestore
            .collection('Inventory_stock')
            .doc('Merch & Accessories')
            .get();
        if (categoryDoc.exists) {
          final data = categoryDoc.data() as Map<String, dynamic>;
          if (data.containsKey(label)) {
            final itemData = data[label] as Map<String, dynamic>;
            if (itemData.containsKey('sizes')) {
              final sizes = itemData['sizes'] as Map<String, dynamic>;
              if (sizes.containsKey(size)) {
                return sizes[size]['price']?.toDouble() ?? 0.0;
              }
            }
            return itemData['price']?.toDouble() ?? 0.0;
          }
        }
        throw Exception('Item not found in Merch & Accessories: $label');
      } else if (normalizedCategory == 'college_items') {
        if (courseLabel == null || courseLabel.isEmpty) {
          throw Exception('Missing courseLabel for college_items.');
        }

        final categoryDoc = await _firestore
            .collection('Inventory_stock')
            .doc('college_items')
            .collection(courseLabel)
            .where('label', isEqualTo: label)
            .limit(1)
            .get();

        if (categoryDoc.docs.isNotEmpty) {
          final itemData =
              categoryDoc.docs.first.data() as Map<String, dynamic>;
          if (itemData.containsKey('sizes')) {
            final sizes = itemData['sizes'] as Map<String, dynamic>;
            if (sizes.containsKey(size)) {
              return sizes[size]['price']?.toDouble() ?? 0.0;
            }
          }
          return itemData['price']?.toDouble() ?? 0.0;
        }
        throw Exception(
            'Item document not found for label: $label in courseLabel: $courseLabel under category: $category.');
      } else if (normalizedCategory == 'senior_high_items') {
        final categoryDoc = await _firestore
            .collection('Inventory_stock')
            .doc('senior_high_items')
            .collection('Items')
            .doc(label)
            .get();
        if (categoryDoc.exists) {
          final data = categoryDoc.data() as Map<String, dynamic>;
          if (data.containsKey('sizes')) {
            final sizes = data['sizes'] as Map<String, dynamic>;
            if (sizes.containsKey(size)) {
              return sizes[size]['price']?.toDouble() ?? 0.0;
            }
          }
          return data['price']?.toDouble() ?? 0.0;
        }
        throw Exception('Item not found in Senior High Items: $label');
      } else if (normalizedCategory == 'proware_and_pe' ||
          category.trim() == 'Proware & PE') {
        if (courseLabel == null || courseLabel.isEmpty) {
          throw Exception('Missing courseLabel for Proware & PE.');
        }

        final categoryDoc = await _firestore
            .collection('Inventory_stock')
            .doc('Proware & PE')
            .collection(courseLabel)
            .doc(label)
            .get();

        if (categoryDoc.exists) {
          final data = categoryDoc.data() as Map<String, dynamic>;

          // Check if sizes exist and retrieve the price for the specified size
          if (data.containsKey('sizes')) {
            final sizes = data['sizes'] as Map<String, dynamic>;
            if (sizes.containsKey(size)) {
              return sizes[size]['price']?.toDouble() ?? 0.0;
            } else {
              throw Exception(
                  "Size $size not found for $label in Proware & PE under $courseLabel.");
            }
          }
          return data['price']?.toDouble() ?? 0.0;
        }

        throw Exception(
            'Item not found in Proware & PE: $label under $courseLabel.');
      }

      throw Exception('Unknown category: $category');
    } catch (e) {
      throw Exception(
          'Failed to fetch pricePerPiece for $label in category $category.');
    }
  }

  Future<void> _sendNotificationToUser(String userId, String userName,
      List<Map<String, dynamic>> approvedItems) async {
    try {
      List<String> itemDetails = [];

      for (var item in approvedItems) {
        String label = item['label'] ?? 'No Label';
        int quantity = item['quantity'] ?? 1;
        double itemTotalPrice = item['totalPrice'] ?? 0.0;

        itemDetails
            .add("$label (x$quantity) - ₱${itemTotalPrice.toStringAsFixed(2)}");
      }

      String itemNames = itemDetails.join(", ");
      String message =
          "Hello $userName, your pre-order for $itemNames has been approved.";

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': 'Pre-order approved',
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unread',
      });
    } catch (e) {}
  }

  Future<bool> _validateStockAvailability(
      String category,
      String subCategoryOrCourseLabel,
      String label,
      String size,
      int quantity) async {
    try {
      final normalizedCategory = category.toLowerCase().trim();

      DocumentSnapshot? itemDoc;

      if (normalizedCategory == 'merch_and_accessories') {
        final doc = await _firestore
            .collection('Inventory_stock')
            .doc('Merch & Accessories')
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          if (data.containsKey(label)) {
            final itemData = data[label] as Map<String, dynamic>;
            if (itemData.containsKey('sizes')) {
              final sizes = itemData['sizes'] as Map<String, dynamic>;
              if (sizes.containsKey(size)) {
                final sizeData = sizes[size] as Map<String, dynamic>;
                int currentStock = sizeData['quantity'] ?? 0;
                return currentStock >= quantity;
              } else {
                throw Exception(
                    "Size $size not found for $label in Merch & Accessories.");
              }
            } else {
              throw Exception(
                  "Sizes not defined for $label in Merch & Accessories.");
            }
          } else {
            throw Exception("Label $label not found in Merch & Accessories.");
          }
        } else {
          throw Exception("Merch & Accessories document not found.");
        }
      } else if (normalizedCategory == 'college_items') {
        itemDoc = await _firestore
            .collection('Inventory_stock')
            .doc('college_items')
            .collection(subCategoryOrCourseLabel)
            .where('label', isEqualTo: label)
            .limit(1)
            .get()
            .then((querySnapshot) => querySnapshot.docs.isNotEmpty
                ? querySnapshot.docs.first
                : null);
      } else if (normalizedCategory == 'senior_high_items') {
        itemDoc = await _firestore
            .collection('Inventory_stock')
            .doc('senior_high_items')
            .collection('Items')
            .doc(label)
            .get();
      } else if (normalizedCategory == 'proware_and_pe' ||
          category.trim() == 'Proware & PE') {
        itemDoc = await _firestore
            .collection('Inventory_stock')
            .doc('Proware & PE')
            .collection(subCategoryOrCourseLabel)
            .doc(label)
            .get();
      }

      if (itemDoc != null && itemDoc.exists) {
        final data = itemDoc.data() as Map<String, dynamic>;
        if (data.containsKey('sizes')) {
          final sizes = data['sizes'] as Map<String, dynamic>;
          if (sizes.containsKey(size)) {
            final sizeData = sizes[size] as Map<String, dynamic>;
            int currentStock = sizeData['quantity'] ?? 0;
            return currentStock >= quantity;
          } else {
            throw Exception("Size $size not found for $label in $category.");
          }
        } else {
          throw Exception("Sizes not defined for $label in $category.");
        }
      } else {
        throw Exception(
            "Item $label not found in $category -> $subCategoryOrCourseLabel.");
      }
    } catch (e) {
      throw Exception("Failed to validate stock availability for $label.");
    }
  }

  Future<void> _rejectPreOrder(Map<String, dynamic> preOrder) async {
    try {
      String userId = preOrder['userId'] ?? '';
      String orderId = preOrder['orderId'] ?? '';
      String label = preOrder['label'] ?? 'Item';

      if (userId.isEmpty || orderId.isEmpty) {
        throw Exception(
            'Invalid pre-order data: userId or orderId is missing.');
      }

      // Remove the pre-order from the user's preorders collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('preorders')
          .doc(orderId)
          .delete();

      // Add a notification to the user's notifications collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': 'Order Cancelled',
        'message': 'Your pre-order for $label has been cancelled.',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'order_cancellation',
        'orderId': orderId,
        'isRead': false, // Mark as unread initially
      });

      // Refresh the pending pre-orders list
      await _fetchAllPendingPreOrders();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pre-order for $label rejected successfully!'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject pre-order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pre-Order List"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _fetchAllPendingPreOrders();
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Scrollbar(
              controller: _verticalController,
              thumbVisibility: true,
              interactive: true,
              child: SingleChildScrollView(
                controller: _verticalController,
                scrollDirection: Axis.vertical,
                child: Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: true,
                  interactive: true,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width,
                      ),
                      child: DataTable(
                        columnSpacing: 12.0,
                        headingRowColor: MaterialStateColor.resolveWith(
                          (states) => Colors.grey.shade200,
                        ),
                        columns: [
                          DataColumn(label: Text('Student Name')),
                          DataColumn(label: Text('Item Label')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Course Label')),
                          DataColumn(label: Text('Size')),
                          DataColumn(label: Text('Quantity')),
                          DataColumn(label: Text('Pre-Order Date')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: allPendingPreOrders.expand((order) {
                          List<DataRow> rows = [];
                          bool isBulkOrder = order['items'].length > 1;

                          rows.add(DataRow(cells: [
                            DataCell(Text(order['userName'],
                                overflow: TextOverflow.ellipsis)),
                            DataCell(
                              isBulkOrder
                                  ? InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (expandedBulkOrders
                                              .contains(order['orderId'])) {
                                            expandedBulkOrders
                                                .remove(order['orderId']);
                                          } else {
                                            expandedBulkOrders
                                                .add(order['orderId']);
                                          }
                                        });
                                      },
                                      child: Row(
                                        children: [
                                          Text(order['label'],
                                              overflow: TextOverflow.ellipsis),
                                          Icon(
                                            expandedBulkOrders
                                                    .contains(order['orderId'])
                                                ? Icons.expand_less
                                                : Icons.expand_more,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    )
                                  : Text(order['label'],
                                      overflow: TextOverflow.ellipsis),
                            ),
                            DataCell(Text(order['category'],
                                overflow: TextOverflow.ellipsis)),
                            DataCell(Text(order['courseLabel'],
                                overflow: TextOverflow.ellipsis)),
                            DataCell(Text(order['itemSize'],
                                overflow: TextOverflow.ellipsis)),
                            DataCell(Text(order['quantity'].toString())),
                            DataCell(Text(order['preOrderDate'])),
                            DataCell(
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _approvePreOrder(order),
                                    child: Text("Approve"),
                                  ),
                                  SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _rejectPreOrder(order),
                                    child: Text("Reject",
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ),
                          ]));

                          if (isBulkOrder &&
                              expandedBulkOrders.contains(order['orderId'])) {
                            rows.addAll(order['items'].map<DataRow>((item) {
                              return DataRow(cells: [
                                DataCell(SizedBox()),
                                DataCell(Text(item['label'],
                                    overflow: TextOverflow.ellipsis)),
                                DataCell(Text(item['category'],
                                    overflow: TextOverflow.ellipsis)),
                                DataCell(Text(item['courseLabel'],
                                    overflow: TextOverflow.ellipsis)),
                                DataCell(Text(item['itemSize'],
                                    overflow: TextOverflow.ellipsis)),
                                DataCell(Text(item['quantity'].toString())),
                                DataCell(SizedBox()),
                                DataCell(SizedBox()),
                              ]);
                            }).toList());
                          }
                          return rows;
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
