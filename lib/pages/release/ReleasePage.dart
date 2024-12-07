import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:unistock/helpers/API.dart';

class ReleasePage extends StatefulWidget {
  @override
  _ReleasePageState createState() => _ReleasePageState();
}

extension CapitalizeExtension on String {
  String capitalize() {
    return this.isNotEmpty ? this[0].toUpperCase() + this.substring(1).toLowerCase() : '';
  }
}

class _ReleasePageState extends State<ReleasePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> allPendingReservations = [];
  Set<String> expandedBulkOrders = Set<String>();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAllApprovedTransactions();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> fetchAllApprovedTransactions() async {
    List<Map<String, dynamic>> approvedTransactions = [];
    setState(() {
      isLoading = true;
    });

    try {
      QuerySnapshot approvedReservationsSnapshot =
      await _firestore.collection('approved_reservation').get();

      for (var doc in approvedReservationsSnapshot.docs) {
        Map<String, dynamic> transactionData = doc.data() as Map<String, dynamic>;
        transactionData['transactionId'] = doc.id;

        transactionData['date'] = transactionData['approvalDate'] ?? Timestamp.now();

        transactionData['name'] = transactionData['name'] ??
            transactionData['studentName'] ??
            'Unknown User';
        transactionData['studentId'] = transactionData['studentId'] ??
            transactionData['studentNumber'] ??
            'Unknown ID';

        approvedTransactions.add(transactionData);
      }

      QuerySnapshot approvedPreordersSnapshot =
      await _firestore.collection('approved_preorders').get();

      for (var doc in approvedPreordersSnapshot.docs) {
        Map<String, dynamic> preorderData = doc.data() as Map<String, dynamic>;
        preorderData['transactionId'] = doc.id;

        preorderData['date'] = preorderData['preOrderDate'] ?? Timestamp.now();

        if (preorderData.containsKey('userId') && preorderData['userId'] != null) {
          String userId = preorderData['userId'];
          DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

          if (userDoc.exists) {
            Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
            preorderData['name'] = userData['name'] ?? 'Unknown User';
            preorderData['studentId'] = userData['studentId'] ?? 'Unknown ID';
          } else {
            preorderData['name'] = 'Unknown User';
            preorderData['studentId'] = 'Unknown ID';
          }
        } else {
          preorderData['name'] = 'Unknown User';
          preorderData['studentId'] = 'Unknown ID';
        }

        approvedTransactions.add(preorderData);
      }

      approvedTransactions.sort((a, b) {
        Timestamp aDate = a['date'] as Timestamp;
        Timestamp bDate = b['date'] as Timestamp;
        return bDate.compareTo(aDate);
      });

      setState(() {
        allPendingReservations = approvedTransactions;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching approved transactions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _approveReservation(Map<String, dynamic> reservation, String orNumber) async {
    try {
      reservation['orNumber'] = orNumber;

      String userName = reservation['userName'] ?? reservation['name'] ?? 'Unknown User';
      String studentId = reservation['studentId'] ?? reservation['studentNumber'] ?? 'Unknown ID';


      if (reservation.containsKey('userId')) {
        String userId = reservation['userId'];
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          userName = userData['name'] ?? userData['studentName'] ?? userName;
          studentId = userData['studentId'] ?? userData['studentNumber'] ?? studentId;
        } else {
        }
      }

      List items = reservation['items'] ?? [];
      List<Map<String, dynamic>> itemDataList = [];
      int totalQuantity = 0;
      double totalTransactionPrice = 0.0;

      if (items.isNotEmpty) {
        for (var item in items) {
          String label = (item['label'] ?? 'No Label').trim();

          String category;
          String subCategory;
          if (reservation.containsKey('preOrderDate')) {
            category = (item['category'] ?? 'Unknown Category').trim();
            subCategory = (item['courseLabel'] ?? 'Unknown SubCategory').trim();
          } else {
            category = (item['mainCategory'] ?? 'Unknown Category').trim();
            subCategory = (item['subCategory'] ?? 'Unknown SubCategory').trim();
          }

          if (category.toLowerCase() == 'merch_and_accessories' || category.toLowerCase() == 'merch & accessories') {
            category = 'Merch & Accessories';
          }

          int quantity = item['quantity'] ?? 0;
          double pricePerPiece = double.tryParse(item['pricePerPiece']?.toString() ?? '0') ?? 0.0;
          double totalPrice = pricePerPiece * quantity;

          if (label.isEmpty || category.isEmpty || subCategory.isEmpty || quantity <= 0) {
            throw Exception('Invalid item data: missing label, category, subCategory, or quantity.');
          }

          await _deductItemQuantity(category, subCategory, label, item['itemSize'] ?? 'Unknown Size', quantity);

          itemDataList.add({
            'label': label,
            'itemSize': item['itemSize'] ?? 'Unknown Size',
            'quantity': quantity,
            'pricePerPiece': pricePerPiece,
            'totalPrice': totalPrice,
            'mainCategory': category,
            'subCategory': subCategory,
          });

          totalQuantity += quantity;
          totalTransactionPrice += totalPrice;
        }
      }

      await _firestore.collection('approved_items').add({
        'reservationDate': reservation['reservationDate'] ?? Timestamp.now(),
        'approvalDate': FieldValue.serverTimestamp(),
        'items': itemDataList,
        'name': userName,
        'studentId': studentId,
        'totalQuantity': totalQuantity,
        'totalTransactionPrice': totalTransactionPrice,
        'orNumber': orNumber,
      });

      await _firestore.collection('admin_transactions').add({
        'cartItemRef': reservation['transactionId'],
        'userName': userName,
        'studentNumber': studentId,
        'timestamp': FieldValue.serverTimestamp(),
        'orNumber': orNumber,
        'totalQuantity': totalQuantity,
        'totalTransactionPrice': totalTransactionPrice,
        'items': itemDataList,
      });

      if (reservation.containsKey('transactionId')) {
        if (reservation.containsKey('preOrderDate')) {
          await _firestore.collection('approved_preorders').doc(reservation['transactionId']).delete();
        } else {
          await _firestore.collection('approved_reservation').doc(reservation['transactionId']).delete();
        }
      }

      await fetchAllApprovedTransactions();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reservation approved and document deleted successfully!'),
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

  Future<void> _deductItemQuantity(
      String category, String subCategory, String label, String size, int quantity) async {
    try {
      if (category == null || category.isEmpty || category == 'Unknown Category') {
        throw Exception('Invalid category: $category');
      }

      category = category.trim();

      if (category == 'Merch & Accessories') {
        await _deductFromMerchAndAccessories(label, size, quantity);
      } else if (category == 'Proware & PE' || category == 'proware_and_pe') {
        await _deductFromProwareAndPE(subCategory, label, size, quantity);
      } else if (category == 'college_items') {
        await _deductFromCollegeItems(subCategory, label, size, quantity);
      } else if (category == 'senior_high_items') {
        await _deductFromSeniorHighItems(label, size, quantity);
      } else {
        throw Exception('Unknown category: $category');
      }
    } catch (e) {
      throw Exception('Failed to deduct stock: $e');
    }
  }

  Future<void> _deductFromMerchAndAccessories(String label, String size, int quantity) async {
    DocumentSnapshot merchDoc =
    await _firestore.collection('Inventory_stock').doc('Merch & Accessories').get();

    if (!merchDoc.exists) {
      throw Exception('Merch & Accessories document not found');
    }

    Map<String, dynamic> merchData = merchDoc.data() as Map<String, dynamic>;

    if (merchData.containsKey(label)) {
      Map<String, dynamic> itemData = merchData[label] as Map<String, dynamic>;

      await _processStock(itemData, label, size, quantity, 'Merch & Accessories');
    } else {
      throw Exception('Item not found in Merch & Accessories: $label');
    }
  }

  Future<void> _deductFromProwareAndPE(
      String subCategory, String label, String size, int quantity) async {
    CollectionReference subCollection = _firestore
        .collection('Inventory_stock')
        .doc('Proware & PE')
        .collection(subCategory);

    QuerySnapshot querySnapshot = await subCollection.where('label', isEqualTo: label).limit(1).get();
    if (querySnapshot.docs.isEmpty) {
      throw Exception('Item not found in Proware & PE: $label');
    }

    DocumentSnapshot itemDoc = querySnapshot.docs.first;
    await _processStock(itemDoc.data() as Map<String, dynamic>, label, size, quantity, 'Proware & PE',
        itemDoc.reference);
  }

  Future<void> _deductFromCollegeItems(
      String subCategory, String label, String size, int quantity) async {
    CollectionReference subCollection = _firestore
        .collection('Inventory_stock')
        .doc('college_items')
        .collection(subCategory);

    QuerySnapshot querySnapshot = await subCollection.where('label', isEqualTo: label).limit(1).get();
    if (querySnapshot.docs.isEmpty) {
      throw Exception('Item not found in college_items: $label');
    }

    DocumentSnapshot itemDoc = querySnapshot.docs.first;
    await _processStock(itemDoc.data() as Map<String, dynamic>, label, size, quantity, 'college_items', itemDoc.reference);
  }

  Future<void> _deductFromSeniorHighItems(String label, String size, int quantity) async {
    CollectionReference subCollection =
    _firestore.collection('Inventory_stock').doc('senior_high_items').collection('Items');

    QuerySnapshot querySnapshot = await subCollection.where('label', isEqualTo: label).limit(1).get();
    if (querySnapshot.docs.isEmpty) {throw Exception('Item not found in senior_high_items: $label');
    }

    DocumentSnapshot itemDoc = querySnapshot.docs.first;
    await _processStock(itemDoc.data() as Map<String, dynamic>, label, size, quantity, 'senior_high_items', itemDoc.reference);
  }

  Future<void> _processStock(Map<String, dynamic> itemData, String label, String size, int quantity,
      String category, [DocumentReference? docRef]) async {
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
      throw Exception('Size $size not available for item $label.');
    }
  }

  Future<void> _rejectReservation(Map<String, dynamic> reservation) async {
    try {
      await _firestore.collection('approved_reservation').doc(reservation['transactionId']).delete();

      await fetchAllApprovedTransactions();
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

  void _showORNumberDialog(Map<String, dynamic> reservation) {
    final _orNumberController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter OR Number'),
          content: TextField(
            controller: _orNumberController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter OR Number',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                String orNumber = _orNumberController.text;

                if (int.tryParse(orNumber) != null) {
                  bool orNumberExists = await _checkIfORNumberExists(orNumber);
                  if (orNumberExists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('OR Number already exists. Please use a unique OR Number.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else {
                    Navigator.pop(context);
                    _approveReservation(reservation, orNumber);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid 8-digit OR number.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _checkIfORNumberExists(String orNumber) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('admin_transactions')
          .where('orNumber', isEqualTo: orNumber)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Release Page"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchAllApprovedTransactions,
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
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Student ID')),
                    DataColumn(label: Text('Label')),
                    DataColumn(label: Text('Size')),
                    DataColumn(label: Text('Quantity')),
                    DataColumn(label: Text('Price per Piece')),
                    DataColumn(label: Text('Total Price')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: allPendingReservations.expand<DataRow>((reservation) {
                    final List items = reservation['items'] ?? [];
                    bool isBulkOrder = items.length > 1;
                    bool isExpanded = expandedBulkOrders.contains(reservation['transactionId']);

                    if (!isBulkOrder) {
                      final item = items[0];
                      int quantity = item['quantity'] ?? 1;
                      double pricePerPiece = double.tryParse(item['pricePerPiece'].toString()) ?? 0.0;
                      double totalPrice = quantity * pricePerPiece;
                      String size = item['itemSize'] ?? 'No Size';
                      String label = item['label'] ?? 'No Label';

                      return [
                        DataRow(
                          key: ValueKey('${reservation['transactionId']}_${label}'),
                          cells: [
                            DataCell(Text(reservation['name'] ?? 'Unknown User')),
                            DataCell(Text(
                              reservation['studentNumber'] != null && reservation['studentNumber'] != 'Unknown ID'
                                  ? reservation['studentNumber']
                                  : (reservation['studentId'] ?? 'Unknown ID'),
                            )),
                            DataCell(Text(label)),
                            DataCell(Text(size)),
                            DataCell(Text('$quantity')),
                            DataCell(Text('₱${pricePerPiece.toStringAsFixed(2)}')),
                            DataCell(Text('₱${totalPrice.toStringAsFixed(2)}')),
                            DataCell(
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      _showORNumberDialog(reservation);
                                    },
                                    child: Text('Approve'),
                                  ),
                                  const SizedBox(width: 8),
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
                    } else {
                      double totalQuantity = items.fold<double>(0, (sum, item) => sum + (item['quantity'] ?? 1));
                      double totalOrderPrice = items.fold<double>(
                          0, (sum, item) => sum + ((item['quantity'] ?? 1) * (double.tryParse(item['pricePerPiece']?.toString() ?? '0') ?? 0.0)));

                      List<DataRow> rows = [
                        DataRow(
                          key: ValueKey(reservation['transactionId']),
                          cells: [
                            DataCell(Text(reservation['name'] ?? 'Unknown User')),
                            DataCell(Text(reservation['studentId'] ?? 'Unknown ID')),
                            DataCell(Row(
                              children: [
                                Text('Bulk Order (${items.length} items)'),
                                IconButton(
                                  icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                                  onPressed: () {
                                    setState(() {
                                      if (isExpanded) {
                                        expandedBulkOrders.remove(reservation['transactionId']);
                                      } else {
                                        expandedBulkOrders.add(reservation['transactionId']);
                                      }
                                    });
                                  },
                                ),
                              ],
                            )),
                            DataCell(Text('')),
                            DataCell(Text('$totalQuantity')),
                            DataCell(Text('')),
                            DataCell(Text('₱${totalOrderPrice.toStringAsFixed(2)}')),
                            DataCell(
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      _showORNumberDialog(reservation);
                                    },
                                    child: Text('Approve'),
                                  ),
                                  const SizedBox(width: 8),
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
                        rows.addAll(items.asMap().entries.map<DataRow>((entry) {
                          final int index = entry.key;
                          final Map<String, dynamic> item = entry.value;
                          int quantity = item['quantity'] ?? 1;
                          double pricePerPiece = double.tryParse(item['pricePerPiece'].toString()) ?? 0.0;
                          double itemTotalPrice = quantity * pricePerPiece;
                          String label = item['label'] ?? 'No Label';
                          String size = item['itemSize'] ?? 'No Size';

                          return DataRow(
                            key: ValueKey('${reservation['transactionId']}_${index}'),
                            cells: [
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text(label)),
                              DataCell(Text(size)),
                              DataCell(Text('$quantity')),
                              DataCell(Text('₱${pricePerPiece.toStringAsFixed(2)}')),
                              DataCell(Text('₱${itemTotalPrice.toStringAsFixed(2)}')),
                              DataCell(Text('')),
                            ],
                          );
                        }).toList());
                      }
                      return rows;
                    }
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