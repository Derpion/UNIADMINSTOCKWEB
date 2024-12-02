import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

  String normalizeCategory(String category) {
    switch (category) {
      case 'senior_high_items':
        return 'Senior High Items';
      case 'college_items':
        return 'College Items';
      case 'proware_and_pe':
      case 'Proware & PE':
        return 'Proware & PE';
      case 'merch_and_accessories':
      case 'Merch & Accessories':
        return 'Merch & Accessories';
      default:
        return category;
    }
  }


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

        if (reservationData['category'] == 'Proware & PE') {
          reservationData['subcategory'] = reservationData['subcategory'] ?? 'Unknown Subcategory';
        } else {
          reservationData['courseLabel'] = reservationData['courseLabel'] ?? 'Unknown Course';
        }

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

          if (reservationData['category'] == 'Proware & PE') {
            reservationData['subcategory'] = reservationData['subcategory'] ?? 'Unknown Subcategory';
          } else {
            reservationData['courseLabel'] = reservationData['courseLabel'] ?? 'Unknown Course';
          }
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

      if (orderItems.isNotEmpty) {
        List<Map<String, dynamic>> approvedItems = [];

        for (var item in orderItems) {
          String label = item['label'] ?? 'No Label';
          String size = item['itemSize'] ?? 'Unknown Size';
          int quantity = item['quantity'] ?? 1;
          String mainCategory = item['category'] ?? 'Unknown Category';
          String subCategory = item['courseLabel'] ?? 'Unknown Course';

          await _validateAndProcessStock(mainCategory, subCategory, label, size, quantity);

          approvedItems.add({
            'label': label,
            'itemSize': size,
            'quantity': quantity,
            'pricePerPiece': item['price'] ?? 0.0,
            'mainCategory': mainCategory,
            'subCategory': subCategory,
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
        String label = reservation['label'] ?? 'No Label';
        String size = reservation['itemSize'] ?? 'Unknown Size';
        int quantity = reservation['quantity'] ?? 1;
        String mainCategory = reservation['category'] ?? 'Unknown Category';
        String subCategory = reservation['courseLabel'] ?? 'Unknown Course';

        await _validateAndProcessStock(mainCategory, subCategory, label, size, quantity);

        await _firestore.collection('approved_reservation').add({
          'reservationDate': reservationDate,
          'approvalDate': FieldValue.serverTimestamp(),
          'label': label,
          'itemSize': size,
          'quantity': quantity,
          'pricePerPiece': reservation['price'] ?? 0.0,
          'mainCategory': mainCategory,
          'subCategory': subCategory,
          'name': userName,
          'userId': userId,
          'studentId': studentId,
        });
      }

      await _firestore.collection('users').doc(userId).collection('orders').doc(orderId).update({'status': 'approved'});

      await _fetchAllPendingReservations();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reservation for ${reservation['label'] ?? 'items'} approved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve reservation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _validateAndProcessStock(String category, String subcategoryOrCourseLabel, String label, String size, int quantity) async {
    try {
      category = normalizeCategory(category);

      if (category == 'Merch & Accessories') {
        DocumentSnapshot merchDoc =
        await _firestore.collection('Inventory_stock').doc('Merch & Accessories').get();

        if (!merchDoc.exists) {
          throw Exception('Merch & Accessories document not found.');
        }

        Map<String, dynamic> merchData = merchDoc.data() as Map<String, dynamic>;
        if (merchData.containsKey(label)) {
          Map<String, dynamic> itemData = merchData[label] as Map<String, dynamic>;
          await _processItemStock(itemData, label, size, quantity, category, subcategoryOrCourseLabel);
        } else {
          throw Exception('Item "$label" not found in Merch & Accessories inventory.');
        }
      } else if (category == 'College Items') {
        CollectionReference itemsRef =
        _firestore.collection('Inventory_stock').doc('college_items').collection(subcategoryOrCourseLabel);
        QuerySnapshot querySnapshot = await itemsRef.where('label', isEqualTo: label).limit(1).get();

        if (querySnapshot.docs.isNotEmpty) {
          DocumentSnapshot itemDoc = querySnapshot.docs.first;
          Map<String, dynamic> itemData = itemDoc.data() as Map<String, dynamic>;
          await _processItemStock(itemData, label, size, quantity, category, subcategoryOrCourseLabel,
              docRef: itemDoc.reference);
        } else {
          throw Exception('Item "$label" not found in College Items inventory.');
        }
      } else if (category == 'Senior High Items') {
        CollectionReference itemsRef =
        _firestore.collection('Inventory_stock').doc('senior_high_items').collection('Items');
        QuerySnapshot querySnapshot = await itemsRef.where('label', isEqualTo: label).limit(1).get();

        if (querySnapshot.docs.isNotEmpty) {
          DocumentSnapshot itemDoc = querySnapshot.docs.first;
          Map<String, dynamic> itemData = itemDoc.data() as Map<String, dynamic>;
          await _processItemStock(itemData, label, size, quantity, category, subcategoryOrCourseLabel,
              docRef: itemDoc.reference);
        } else {
          throw Exception('Item "$label" not found in Senior High Items inventory.');
        }
      } else if (category == 'Proware & PE') {
        CollectionReference itemsRef =
        _firestore.collection('Inventory_stock').doc('Proware & PE').collection(subcategoryOrCourseLabel);
        QuerySnapshot querySnapshot = await itemsRef.where('label', isEqualTo: label).limit(1).get();

        if (querySnapshot.docs.isNotEmpty) {
          DocumentSnapshot itemDoc = querySnapshot.docs.first;
          Map<String, dynamic> itemData = itemDoc.data() as Map<String, dynamic>;
          await _processItemStock(itemData, label, size, quantity, category, subcategoryOrCourseLabel,
              docRef: itemDoc.reference);
        } else {
          throw Exception('Item "$label" not found in Proware & PE under $subcategoryOrCourseLabel.');
        }
      } else {
        throw Exception('Unknown category: $category');
      }
    } catch (e) {
      throw Exception('Failed to process stock: $e');
    }
  }

  Future<void> _processItemStock(Map<String, dynamic> itemData, String label, String size, int quantity, String category, String subCategory, {DocumentReference? docRef,}) async {
    if (itemData.containsKey('sizes') && itemData['sizes'][size] != null) {
      int currentStock = itemData['sizes'][size]['quantity'] ?? 0;

      if (currentStock >= quantity) {
        itemData['sizes'][size]['quantity'] = currentStock - quantity;

        if (docRef != null) {
          await docRef.update({'sizes': itemData['sizes']});
        } else {
          await _firestore.collection('Inventory_stock').doc(category).update({label: itemData});
        }
      } else {
        throw Exception(
            'Insufficient stock for $label size $size. Available: $currentStock, Required: $quantity.');
      }
    } else {
      throw Exception('Size "$size" not available for item "$label".');
    }
  }

  void _notifyUser(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ),
    );
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

    } catch (e) {
    }
  }

  Future<void> _rejectReservation(Map<String, dynamic> reservation) async {
    try {
      String userId = reservation['userId'] ?? '';
      String orderId = reservation['orderId'] ?? '';

      if (userId.isEmpty || orderId.isEmpty) {
        throw Exception('Invalid reservation data: userId or orderId is missing.');
      }
      await _firestore.collection('users').doc(userId).collection('orders').doc(orderId).delete();
      await _fetchAllPendingReservations();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reservation for ${reservation['label']} rejected successfully!'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
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
