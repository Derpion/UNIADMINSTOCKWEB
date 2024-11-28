import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReservationListPage extends StatefulWidget {
  @override
  _ReservationListPageState createState() => _ReservationListPageState();
}

class _ReservationListPageState extends State<ReservationListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> allPendingReservations = [];
  Set<String> expandedBulkOrders = Set<String>();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllPendingReservations();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllPendingReservations() async {
    List<Map<String, dynamic>> pendingReservations = [];
    setState(() {
      isLoading = true;
    });

    QuerySnapshot usersSnapshot = await _firestore.collection('users').get();

    for (var userDoc in usersSnapshot.docs) {
      String userName = userDoc['name'] ?? 'Unknown User';
      String studentId = (userDoc.data() as Map<String, dynamic>).containsKey('studentId')
          ? userDoc['studentId']
          : 'Unknown ID';

      QuerySnapshot ordersSnapshot = await _firestore
          .collection('users')
          .doc(userDoc.id)
          .collection('orders')
          .where('status', isEqualTo: 'pending')
          .get();

      for (var orderDoc in ordersSnapshot.docs) {
        Map<String, dynamic> reservationData = orderDoc.data() as Map<String, dynamic>;

        reservationData['orderId'] = orderDoc.id;
        reservationData['userName'] = userName;
        reservationData['studentId'] = studentId;
        reservationData['userId'] = userDoc.id;
        reservationData['category'] = reservationData['category'] ?? 'Unknown Category';
        reservationData['label'] = reservationData['label'] ?? 'No Label';
        reservationData['courseLabel'] = reservationData['courseLabel'] ?? 'Unknown Course';

        if (reservationData.containsKey('items') && reservationData['items'] is List) {
          List<dynamic> orderItems = reservationData['items'];

          double totalOrderPrice = 0.0;
          for (var item in orderItems) {
            int itemQuantity = item['quantity'] ?? 1;
            double itemPrice = item['price'] ?? 0.0;
            String itemSize = item['itemSize'] ?? 'Unknown Size';

            double itemTotalPrice = itemQuantity * itemPrice;
            item['totalPrice'] = itemTotalPrice.toStringAsFixed(2);
            item['pricePerPiece'] = itemPrice;
            item['size'] = itemSize;

            totalOrderPrice += itemTotalPrice;
          }

          reservationData['totalOrderPrice'] = totalOrderPrice.toStringAsFixed(2);
        } else {
          int quantity = reservationData['quantity'] ?? 1;
          double pricePerPiece = reservationData['price'] ?? 0.0;
          String itemSize = reservationData['itemSize'] ?? 'Unknown Size';
          double totalPrice = quantity * pricePerPiece;

          reservationData['totalPrice'] = totalPrice.toStringAsFixed(2);
          reservationData['pricePerPiece'] = pricePerPiece;
          reservationData['size'] = itemSize;
          reservationData['quantity'] = quantity;
          reservationData['label'] = reservationData['label'];
          reservationData['courseLabel'] = reservationData['courseLabel'];
          reservationData['category'] = reservationData['category'];
        }
        pendingReservations.add(reservationData);
      }
    }

    pendingReservations.sort((a, b) {
      Timestamp aTimestamp = a['orderDate'] != null && a['orderDate'] is Timestamp
          ? a['orderDate']
          : Timestamp.now();
      Timestamp bTimestamp = b['orderDate'] != null && b['orderDate'] is Timestamp
          ? b['orderDate']
          : Timestamp.now();
      return bTimestamp.compareTo(aTimestamp);
    });

    setState(() {
      allPendingReservations = pendingReservations;
      isLoading = false;
    });
  }


  Future<void> _approveReservation(Map<String, dynamic> reservation) async {
    try {
      String userId = reservation['userId'] ?? '';
      String orderId = reservation['orderId'] ?? '';
      String userName = reservation['userName'] ?? 'Unknown User';
      String studentId = reservation['studentId'] ?? 'Unknown ID';
      String studentName = reservation['userName'] ?? 'Unknown User';

      if (userId.isEmpty || orderId.isEmpty) {
        throw Exception('Invalid reservation data: userId or orderId is missing.');
      }

      DocumentSnapshot orderDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      Timestamp reservationDate = orderDoc['orderDate'] ?? Timestamp.now();
      List<dynamic> orderItems = reservation['items'] ?? [];

      // Aggregate items into a single document for bulk orders
      if (orderItems.isNotEmpty) {
        List<Map<String, dynamic>> approvedItems = [];
        for (var item in orderItems) {
          approvedItems.add({
            'label': item['label'] ?? 'No Label',
            'itemSize': item['itemSize'] ?? 'Unknown Size',
            'quantity': item['quantity'] ?? 1,
            'pricePerPiece': item['price'] ?? 0.0,
            'mainCategory': item['category'] ?? 'Unknown Category',
            'subCategory': item['courseLabel'] ?? 'Unknown Course',
          });
        }

        await _firestore.collection('approved_reservation').add({
          'reservationDate': reservationDate,
          'approvalDate': FieldValue.serverTimestamp(),
          'items': approvedItems,
          'name': userName,
          'userId': userId,
          'studentId': studentId,
        });
      } else {
        // For single item reservation
        await _firestore.collection('approved_reservation').add({
          'reservationDate': reservationDate,
          'approvalDate': FieldValue.serverTimestamp(),
          'label': reservation['label'],
          'itemSize': reservation['itemSize'],
          'quantity': reservation['quantity'],
          'pricePerPiece': reservation['price'],
          'mainCategory': reservation['category'],
          'subCategory': reservation['courseLabel'],
          'name': userName,
          'userId': userId,
          'studentId': studentId,
        });
      }

      await _firestore.collection('users').doc(userId).collection('orders').doc(orderId).update({'status': 'approved'});

      await _sendNotificationToUser(userId, userName, studentName, studentId, reservation);
      await _fetchAllPendingReservations();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reservation for ${reservation['label'] ?? 'items'} approved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('Error approving reservation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve reservation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendNotificationToUser(String userId, String userName, String studentName, String studentId, Map<String, dynamic> reservation) async {
    try {
      List<dynamic> orderItems = reservation['items'] ?? [];
      List<Map<String, dynamic>> orderSummary = [];

      if (orderItems.isNotEmpty) {
        for (var item in orderItems) {
          double pricePerPiece = item['price'] ?? 0.0;
          int quantity = item['quantity'] ?? 1;
          double totalPrice = pricePerPiece * quantity;

          orderSummary.add({
            'label': item['label'],
            'itemSize': item['itemSize'],
            'quantity': quantity,
            'pricePerPiece': pricePerPiece,
            'totalPrice': totalPrice,
          });
        }
      } else {
        double pricePerPiece = reservation['price'] ?? 0.0;
        int quantity = reservation['quantity'] ?? 1;
        double totalPrice = pricePerPiece * quantity;

        orderSummary.add({
          'label': reservation['label'],
          'itemSize': reservation['itemSize'],
          'quantity': quantity,
          'pricePerPiece': pricePerPiece,
          'totalPrice': totalPrice,
        });
      }

      String notificationMessage;
      if (orderSummary.length > 1) {
        notificationMessage = 'Dear $studentName (ID: $studentId), your bulk reservation (${orderSummary.length} items) has been approved.';
      } else {
        notificationMessage = 'Dear $studentName (ID: $studentId), your reservation for ${orderSummary[0]['label']} (${orderSummary[0]['itemSize']}) has been approved.';
      }

      await _firestore.collection('users').doc(userId).collection('notifications').add({
        'title': 'Reservation Approved',
        'message': notificationMessage,
        'orderSummary': orderSummary,
        'studentName': studentName,
        'studentId': studentId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unread',
      });

      print('Notification sent to user: $userName');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  Future<void> _rejectReservation(Map<String, dynamic> reservation) async {
    try {
      String userId = reservation['userId'] ?? '';
      String orderId = reservation['orderId'] ?? '';

      if (userId.isEmpty || orderId.isEmpty) {
        throw Exception('Invalid reservation data: userId or orderId is missing.');
      }

      // Delete the reservation from Firestore
      await _firestore.collection('users').doc(userId).collection('orders').doc(orderId).delete();

      await _fetchAllPendingReservations();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reservation for ${reservation['label']} rejected successfully!'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print('Error rejecting reservation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject reservation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Reservation List"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _fetchAllPendingReservations();
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
                  columnSpacing: 16.0,
                  headingRowColor: MaterialStateColor.resolveWith(
                        (states) => Colors.grey.shade200,
                  ),
                  columns: [
                    DataColumn(label: Text('Student Name')),
                    DataColumn(label: Text('Student ID')),
                    DataColumn(label: Text('Label')),
                    DataColumn(label: Text('Size')),
                    DataColumn(label: Text('Quantity')),
                    DataColumn(label: Text('Price per Piece')),
                    DataColumn(label: Text('Total Price')),
                    DataColumn(label: Text('Order Date')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: allPendingReservations.expand<DataRow>((reservation) {
                    final List orderItems = reservation['items'] ?? [];
                    bool isBulkOrder = orderItems.length > 1;
                    bool isExpanded = expandedBulkOrders.contains(reservation['orderId']);

                    if (!isBulkOrder) {
                      final singleItem = orderItems[0];
                      int quantity = singleItem['quantity'] ?? 1;
                      double pricePerPiece = double.tryParse(singleItem['price']?.toString() ?? '0') ?? 0.0;
                      double totalPrice = double.tryParse(singleItem['totalPrice']?.toString() ?? (pricePerPiece * quantity).toString()) ?? 0.0;
                      String size = singleItem['itemSize'] ?? 'No Size';
                      String label = singleItem['label'] ?? 'No Label';

                      return [
                        DataRow(
                          key: ValueKey(reservation['orderId']),
                          cells: [
                            DataCell(Text(reservation['userName'] ?? 'Unknown User')),
                            DataCell(Text(reservation['studentId'] ?? 'Unknown ID')),
                            DataCell(Text(label)),
                            DataCell(Text(size)),
                            DataCell(Text('$quantity')),
                            DataCell(Text('₱${pricePerPiece.toStringAsFixed(2)}')),
                            DataCell(Text('₱${totalPrice.toStringAsFixed(2)}')),
                            DataCell(Text(
                              reservation['orderDate'] != null && reservation['orderDate'] is Timestamp
                                  ? DateFormat('yyyy-MM-dd HH:mm:ss').format(
                                (reservation['orderDate'] as Timestamp).toDate(),
                              )
                                  : 'No Date Provided',
                            )),
                            DataCell(
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      _approveReservation(reservation);
                                    },
                                    child: Text('Approve'),
                                  ),
                                  SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      _rejectReservation(reservation);
                                    },
                                    child: Text('Reject', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ];
                    }

                    double totalQuantity = orderItems.fold<double>(0, (sum, item) => sum + (item['quantity'] ?? 1));
                    double totalPrice = orderItems.fold<double>(
                        0, (sum, item) => sum + ((item['quantity'] ?? 1) * (double.tryParse(item['price']?.toString() ?? '0') ?? 0.0)));

                    List<DataRow> rows = [
                      DataRow(
                        key: ValueKey(reservation['orderId']),
                        cells: [
                          DataCell(Text(reservation['userName'] ?? 'Unknown User')),
                          DataCell(Text(reservation['studentId'] ?? 'Unknown ID')),
                          DataCell(Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Bulk Order (${orderItems.length} items)'),
                              IconButton(
                                icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                                onPressed: () {
                                  setState(() {
                                    if (isExpanded) {
                                      expandedBulkOrders.remove(reservation['orderId']);
                                    } else {
                                      expandedBulkOrders.add(reservation['orderId']);
                                    }
                                  });
                                },
                              ),
                            ],
                          )),
                          DataCell(Text('')),
                          DataCell(Text('$totalQuantity')),
                          DataCell(Text('')),
                          DataCell(Text('₱${totalPrice.toStringAsFixed(2)}')),
                          DataCell(Text(
                            reservation['orderDate'] != null && reservation['orderDate'] is Timestamp
                                ? DateFormat('yyyy-MM-dd HH:mm:ss').format(
                              (reservation['orderDate'] as Timestamp).toDate(),
                            )
                                : 'No Date Provided',
                          )),
                          DataCell(
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    _approveReservation(reservation);
                                  },
                                  child: Text('Approve'),
                                ),
                                SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () {
                                    _rejectReservation(reservation);
                                  },
                                  child: Text('Reject'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ];

                    if (isExpanded) {
                      rows.addAll(orderItems.map<DataRow>((item) {
                        int itemQuantity = item['quantity'] ?? 1;
                        double pricePerPiece = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                        double itemTotalPrice = double.tryParse(item['totalPrice']?.toString() ?? (pricePerPiece * itemQuantity).toString()) ?? 0.0;
                        String itemLabel = item['label'] ?? 'No Label';
                        String itemSize = item['itemSize'] ?? 'No Size';

                        return DataRow(
                          key: ValueKey('${reservation['orderId']}_${itemLabel}'),
                          cells: [
                            DataCell(Text('')),
                            DataCell(Text('')),
                            DataCell(Text(itemLabel)),
                            DataCell(Text(itemSize)),
                            DataCell(Text('$itemQuantity')),
                            DataCell(Text('₱${pricePerPiece.toStringAsFixed(2)}')),
                            DataCell(Text('₱${itemTotalPrice.toStringAsFixed(2)}')),
                            DataCell(Text('')),
                            DataCell(Text('')),
                          ],
                        );
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
