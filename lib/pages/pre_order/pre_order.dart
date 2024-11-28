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

  Future<void> _sendSMSToUser(String contactNumber, String studentName, String studentNumber, double totalOrderPrice, List<Map<String, dynamic>> cartItems) async {
    try {
      List<String> itemDetails = [];
      double overallTotalPrice = 0.0;

      for (var item in cartItems) {
        String label = item['label'] ?? 'Item';
        int quantity = item['quantity'] ?? 1;
        double pricePerPiece = item['pricePerPiece'] is double
            ? item['pricePerPiece']
            : (item['pricePerPiece'] != null ? double.parse(item['pricePerPiece'].toString()) : 0.0);

        double itemTotalPrice = pricePerPiece * quantity;
        overallTotalPrice += itemTotalPrice;

        itemDetails.add("$label (x$quantity) - ₱${itemTotalPrice.toStringAsFixed(2)}");
      }

      String itemNames = itemDetails.join(", ");
      String message = "Hello $studentName (Student ID: $studentNumber), your pre-order for $itemNames has been approved. Total Price: ₱${overallTotalPrice.toStringAsFixed(2)}.";

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
      } else {
      }
    } catch (e) {
    }
  }

  Future<void> _sendNotificationToUser(String userId, String userName, Map<String, dynamic> preOrder) async {
    try {
      List<String> itemDetails = [];
      double totalPrice = 0.0;


      if (preOrder.containsKey('items') && preOrder['items'] is List) {
        for (var item in preOrder['items']) {

          String label = item['label'] ?? 'No Label';
          int quantity = item['quantity'] ?? 1;
          double itemTotalPrice = 0.0;

          if (item['totalPrice'] != null) {
            if (item['totalPrice'] is int) {
              itemTotalPrice = (item['totalPrice'] as int).toDouble();
            } else if (item['totalPrice'] is double) {
              itemTotalPrice = item['totalPrice'];
            } else {
              itemTotalPrice = double.tryParse(item['totalPrice'].toString()) ?? 0.0;
            }
          }
          totalPrice += itemTotalPrice;
          itemDetails.add("$label (x$quantity) - ₱${itemTotalPrice.toStringAsFixed(2)}");
        }
      } else {
      }

      String itemNames = itemDetails.join(", ");
      String message = "Hello $userName, your pre-order for $itemNames has been approved. Total Price: ₱${totalPrice.toStringAsFixed(2)}.";

      await _firestore.collection('users').doc(userId).collection('notifications').add({
        'title': 'Pre-order approved',
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unread',
      });

    } catch (e) {
    }
  }

  Future<void> _approvePreOrder(Map<String, dynamic> preOrder) async {
    try {
      String userId = preOrder['userId'] ?? '';
      String orderId = preOrder['orderId'] ?? '';
      String userName = preOrder['userName'] ?? 'Unknown User';
      String studentId = preOrder['studentId'] ?? 'Unknown ID';

      print('Approving pre-order for userId: $userId, orderId: $orderId');
      print('Pre-order details: $preOrder');

      if (userId.isEmpty || orderId.isEmpty) {
        throw Exception('Invalid pre-order data: userId or orderId is missing.');
      }

      // Fetch the user's profile to get the contact number and name
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists || userDoc['contactNumber'] == null) {
        throw Exception('User profile not found or contact number is missing.');
      }

      // Get the contact number and other user details from the user's document
      String contactNumber = userDoc['contactNumber'];
      String studentName = userDoc['name'] ?? 'Unknown Name';  // Assuming `name` field exists
      String studentNumber = userDoc['studentId'] ?? 'Unknown ID';
      print('Fetched contact number: $contactNumber');

      // Fetch the order document
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

      double totalOrderPrice = orderData['totalOrderPrice'] ?? 0.0;  // Using totalOrderPrice from the document if available
      List<dynamic> orderItems = preOrder['items'] ?? [];

      if (orderItems.isEmpty) {
        throw Exception('No items found in the pre-order');
      }

      List<Map<String, dynamic>> cartItems = [];
      for (var item in orderItems) {
        String label = (item['label'] ?? 'No Label').trim();
        int quantity = item['quantity'] ?? 0;

        if (label.isEmpty || quantity <= 0) {
          throw Exception('Invalid item data: missing label or quantity.');
        }

        cartItems.add({
          'label': label,
          'quantity': quantity,
          'pricePerPiece': item['pricePerPiece'] ?? 0.0,  // Assuming pricePerPiece is part of each item
        });
      }

      // Save to approved_preorders collection and delete from preorders collection
      await _firestore.collection('approved_preorders').doc(orderId).set({
        'userId': userId,
        ...orderData,
      });

      await _firestore.collection('users').doc(userId).collection('preorders').doc(orderId).delete();

      // Send SMS and Notification
      await _sendSMSToUser(contactNumber, studentName, studentNumber, totalOrderPrice, cartItems);
      await _sendNotificationToUser(userId, userName, preOrder);

      await _fetchAllPendingPreOrders();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pre-order for ${preOrder['items'].map((e) => e['label']).join(", ")} approved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('Error approving pre-order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve pre-order: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
      String studentId = (userDoc.data() as Map<String, dynamic>).containsKey('studentId')
          ? userDoc['studentId']
          : 'Unknown ID';

      QuerySnapshot preordersSnapshot = await _firestore
          .collection('users')
          .doc(userDoc.id)
          .collection('preorders')
          .where('status', isEqualTo: 'pre-order confirmed')
          .get();

      for (var preorderDoc in preordersSnapshot.docs) {
        Map<String, dynamic> preOrderData = preorderDoc.data() as Map<String, dynamic>;

        List<dynamic> items = preOrderData['items'] ?? [];
        String label = items.length > 1 ? "Bulk Order (${items.length} items)" : items[0]['label'];
        String preOrderDate = DateFormat('yyyy-MM-dd').format((preOrderData['preOrderDate'] as Timestamp).toDate());

        pendingPreOrders.add({
          'userId': userDoc.id,
          'userName': userName,
          'studentId': studentId,
          'label': label,
          'category': items.length > 1 ? 'Multiple' : items[0]['category'],
          'courseLabel': items.length > 1 ? 'Various' : items[0]['courseLabel'],
          'itemSize': items.length > 1 ? 'Various' : items[0]['itemSize'],
          'quantity': items.length > 1 ? items.map((e) => e['quantity'] as int).reduce((a, b) => a + b) : items[0]['quantity'],
          'preOrderDate': preOrderDate,
          'items': items,
          'preOrderTimestamp': preOrderData['preOrderDate'] as Timestamp,
          'orderId': preorderDoc.id,
        });
      }
    }

    pendingPreOrders.sort((a, b) => b['preOrderTimestamp'].compareTo(a['preOrderTimestamp']));

    setState(() {
      allPendingPreOrders = pendingPreOrders;
      isLoading = false;
    });
  }

  Future<void> _rejectPreOrder(Map<String, dynamic> preOrder) async {
    try {
      String userId = preOrder['userId'] ?? '';
      String orderId = preOrder['orderId'] ?? '';

      if (userId.isEmpty || orderId.isEmpty) {
        throw Exception('Invalid pre-order data: userId or orderId is missing.');
      }

      await _firestore.collection('users').doc(userId).collection('preorders').doc(orderId).delete();

      await _fetchAllPendingPreOrders();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pre-order for ${preOrder['label']} rejected successfully!'),
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
                          DataColumn(
                            label: Text('Student Name')),
                          DataColumn(
                            label: Text('Item Label')),
                          DataColumn(
                            label: Text('Category')),
                          DataColumn(
                            label: Text('Course Label')),
                          DataColumn(
                            label: Text('Size')),
                          DataColumn(
                            label: Text('Quantity')),
                          DataColumn(
                            label: Text('Pre-Order Date')),
                          DataColumn(
                            label: Text('Actions')),
                  ],
                  rows: allPendingPreOrders.expand((order) {
                    List<DataRow> rows = [];
                    bool isBulkOrder = order['items'].length > 1;

                    rows.add(DataRow(cells: [
                      DataCell(Text(order['userName'], overflow: TextOverflow.ellipsis)),
                      DataCell(
                        isBulkOrder
                            ? InkWell(
                          onTap: () {
                            setState(() {
                              if (expandedBulkOrders.contains(order['orderId'])) {
                                expandedBulkOrders.remove(order['orderId']);
                              } else {
                                expandedBulkOrders.add(order['orderId']);
                              }
                            });
                          },
                          child: Row(
                            children: [
                              Text(order['label'], overflow: TextOverflow.ellipsis),
                              Icon(
                                expandedBulkOrders.contains(order['orderId'])
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 16,
                              ),
                            ],
                          ),
                        )
                            : Text(order['label'], overflow: TextOverflow.ellipsis),
                      ),
                      DataCell(Text(order['category'], overflow: TextOverflow.ellipsis)),
                      DataCell(Text(order['courseLabel'], overflow: TextOverflow.ellipsis)),
                      DataCell(Text(order['itemSize'], overflow: TextOverflow.ellipsis)),
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
                              child: Text("Reject", style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    ]));

                    if (isBulkOrder && expandedBulkOrders.contains(order['orderId'])) {
                      rows.addAll(order['items'].map<DataRow>((item) {
                        return DataRow(cells: [
                          DataCell(SizedBox()),
                          DataCell(Text(item['label'], overflow: TextOverflow.ellipsis)),
                          DataCell(Text(item['category'], overflow: TextOverflow.ellipsis)),
                          DataCell(Text(item['courseLabel'], overflow: TextOverflow.ellipsis)),
                          DataCell(Text(item['itemSize'], overflow: TextOverflow.ellipsis)),
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