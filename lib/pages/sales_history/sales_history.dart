import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:unistock/widgets/custom_text.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SalesHistoryPage extends StatefulWidget {
  @override
  _SalesHistoryPageState createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  final TextEditingController _searchController = TextEditingController(); // Search Controller
  List<Map<String, dynamic>> _filteredSalesData = []; // Filtered Sales Data

  Set<String> expandedBulkOrders = Set<String>();
  Future<List<Map<String, dynamic>>>? _salesDataFuture;
  List<Map<String, dynamic>> _allSalesItems = []; // All Sales Items
  double _totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _salesDataFuture = _fetchSalesData();
    _searchController.addListener(_filterSalesData); // Add listener to search input
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchSalesData() async {
    List<Map<String, dynamic>> allSalesItems = [];
    double totalRevenue = 0.0;

    QuerySnapshot adminTransactionsSnapshot = await _firestore
        .collection('admin_transactions')
        .orderBy('timestamp', descending: true)
        .get();

    for (var transactionDoc in adminTransactionsSnapshot.docs) {
      var transactionData = transactionDoc.data() as Map<String, dynamic>;
      totalRevenue += (transactionData['totalTransactionPrice'] ?? 0.0) as double;

      if (transactionData['items'] is List) {
        List<dynamic> items = transactionData['items'];
        allSalesItems.add({
          'orNumber': transactionData['orNumber'] ?? 'N/A',
          'userName': transactionData['userName'] ?? 'N/A',
          'studentNumber': transactionData['studentNumber'] ?? 'N/A',
          'isBulk': items.length > 1,
          'items': items.map((item) {
            return {
              'label': item['label'] ?? 'N/A',
              'itemSize': item['itemSize'] ?? 'N/A',
              'quantity': item['quantity'] ?? 0,
              'mainCategory': item['mainCategory'] ?? 'N/A',
              'totalPrice': item['totalPrice'] ?? 0.0,
            };
          }).toList(),
          'totalTransactionPrice': transactionData['totalTransactionPrice'] ?? 0.0,
          'orderDate': transactionData['timestamp'],
        });
      }
    }

    setState(() {
      _totalRevenue = totalRevenue;
      _allSalesItems = allSalesItems;
      _filteredSalesData = List.from(allSalesItems); // Initialize filtered data
    });

    return allSalesItems;
  }

  void _filterSalesData() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSalesData = List.from(_allSalesItems); // Reset to all data
      } else {
        _filteredSalesData = _allSalesItems.where((sale) {
          if (sale['isBulk'] == true) {
            // Check each item in bulk orders
            return (sale['items'] as List).any((item) =>
                (item['label'] ?? '').toString().toLowerCase().contains(query));
          } else {
            // Check single orders
            return (sale['items'][0]['label'] ?? '')
                .toString()
                .toLowerCase()
                .contains(query);
          }
        }).toList();
      }
    });
  }

  Future<void> _generatePDF(List<Map<String, dynamic>> salesData) async {
    final pdf = pw.Document();
    const int rowsPerPage = 10; // 10 data rows + 1 header row
    final String currentDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    int pageCount = (salesData.length / rowsPerPage).ceil();
    for (int page = 0; page < pageCount; page++) {
      final rowsChunk = salesData.skip(page * rowsPerPage).take(rowsPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.copyWith(
            width: PdfPageFormat.a4.height,
            height: PdfPageFormat.a4.width,
          ),
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Text('Generated on: $currentDateTime', style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic),),
                pw.Text('Sales Report (Page ${page + 1} of $pageCount)', style: pw.TextStyle(fontSize: 20)),
                pw.SizedBox(height: 4),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                  columnWidths: {
                    for (int i = 0; i < 7; i++)
                      i: const pw.FixedColumnWidth(
                          80),
                  },
                  children: [
                    // Header row
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('OR Number', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Student Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Student ID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Item Label', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Item Size', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Quantity', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Total Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    // Data rows with aggregation for bulk orders
                    ...rowsChunk.map((saleItem) {
                      if (saleItem['items'] != null &&
                          saleItem['items'] is List &&
                          (saleItem['items'] as List).length > 1) {
                        // For bulk orders with more than one item
                        List<pw.TableRow> bulkRows = [
                          // Bulk order summary row
                          pw.TableRow(
                            children: [
                              pw.Text(saleItem['orNumber'] ?? 'N/A'),
                              pw.Text(saleItem['userName'] ?? 'N/A'),
                              pw.Text(saleItem['studentNumber'] ?? 'N/A'),
                              pw.Text('Bulk Order (${saleItem['items'].length} items)'),
                              pw.Text(''),
                              pw.Text(''),
                              pw.Text(''),
                              pw.Text('₱${(saleItem['totalTransactionPrice'] ?? 0.0).toStringAsFixed(2)}'),
                            ],
                          ),
                        ];

                        // Individual rows for each item in the bulk order
                        bulkRows.addAll((saleItem['items'] as List).map<pw.TableRow>((item) {
                          return pw.TableRow(
                            children: [
                              pw.Text(''),
                              pw.Text(''),
                              pw.Text(''),
                              pw.Text(item['label'] ?? 'N/A'),
                              pw.Text(item['itemSize'] ?? 'N/A'),
                              pw.Text(item['quantity'].toString()),
                              pw.Text(item['mainCategory'] ?? 'N/A'),
                              pw.Text('₱${(item['totalPrice'] ?? 0.0).toStringAsFixed(2)}'),
                            ],
                          );
                        }).toList());

                        return bulkRows;
                      } else {
                        // For single orders or bulk orders with only one item
                        return [
                          pw.TableRow(
                            children: [
                              pw.Text(saleItem['orNumber'] ?? 'N/A'),
                              pw.Text(saleItem['userName'] ?? 'N/A'),
                              pw.Text(saleItem['studentNumber'] ?? 'N/A'),
                              pw.Text(saleItem['items'] != null && saleItem['items'] is List && saleItem['items'].length == 1
                                  ? saleItem['items'][0]['label'] ?? 'N/A'
                                  : saleItem['itemLabel'] ?? 'N/A'),
                              pw.Text(saleItem['items'] != null && saleItem['items'] is List && saleItem['items'].length == 1
                                  ? saleItem['items'][0]['itemSize'] ?? 'N/A'
                                  : saleItem['itemSize'] ?? 'N/A'),
                              pw.Text(saleItem['items'] != null && saleItem['items'] is List && saleItem['items'].length == 1
                                  ? saleItem['items'][0]['quantity'].toString()
                                  : saleItem['quantity'].toString()),
                              pw.Text(saleItem['items'] != null && saleItem['items'] is List && saleItem['items'].length == 1
                                  ? saleItem['items'][0]['mainCategory'] ?? 'N/A'
                                  : saleItem['category'] ?? 'N/A'),
                              pw.Text(saleItem['items'] != null && saleItem['items'] is List && saleItem['items'].length == 1
                                  ? '₱${(saleItem['items'][0]['totalPrice'] ?? 0.0).toStringAsFixed(2)}'
                                  : '₱${(saleItem['totalPrice'] ?? 0.0).toStringAsFixed(2)}'),
                            ],
                          ),
                        ];
                      }
                    }).expand((rows) => rows),
                  ],
                ),
                if (page == pageCount - 1) // Add total revenue on the last page
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 16),
                    child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        'Total Revenue: ₱${_totalRevenue.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Sales Report"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _salesDataFuture = _fetchSalesData();
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.print),
            onPressed: () async {
              final allSalesItems = await _salesDataFuture;
              if (allSalesItems != null && allSalesItems.isNotEmpty) {
                await _generatePDF(allSalesItems);
              } else {
                print("No sales data to display in PDF");
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Add Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by Item Label',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),

          // Sales Data Table
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _salesDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: CustomText(text: "Error fetching sales history"));
                } else if (snapshot.hasData && _filteredSalesData.isEmpty) {
                  return Center(child: CustomText(text: "No sales history found for your query"));
                } else if (snapshot.hasData) {
                  return Scrollbar(
                    controller: _verticalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 16.0,
                          columns: [
                            DataColumn(label: Text('OR Number')),
                            DataColumn(label: Text('Student Name')),
                            DataColumn(label: Text('Student ID')),
                            DataColumn(label: Text('Item Label')),
                            DataColumn(label: Text('Item Size')),
                            DataColumn(label: Text('Quantity')),
                            DataColumn(label: Text('Category')),
                            DataColumn(label: Text('Total Price')),
                            DataColumn(label: Text('Order Date')),
                          ],
                          rows: _filteredSalesData.expand<DataRow>((sale) {
                            bool isBulkOrder = sale['isBulk'];
                            bool isExpanded = expandedBulkOrders.contains(sale['orNumber']);
                            List<DataRow> rows = [];

                            // Main row for each transaction
                            rows.add(
                              DataRow(
                                key: ValueKey('${sale['orNumber']}_main'),
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        isBulkOrder
                                            ? IconButton(
                                          icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                                          onPressed: () {
                                            setState(() {
                                              if (isExpanded) {
                                                expandedBulkOrders.remove(sale['orNumber']);
                                              } else {
                                                expandedBulkOrders.add(sale['orNumber']);
                                              }
                                            });
                                          },
                                        )
                                            : SizedBox(width: 24),
                                        Text(sale['orNumber'] ?? 'N/A'),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(sale['userName'] ?? 'N/A')),
                                  DataCell(Text(sale['studentNumber'] ?? 'N/A')),
                                  DataCell(Text(
                                    isBulkOrder
                                        ? 'Bulk Order (${sale['items'].length} items)'
                                        : sale['items'][0]['label'] ?? 'N/A',
                                  )),
                                  DataCell(Text(isBulkOrder ? '' : sale['items'][0]['itemSize'] ?? 'N/A')),
                                  DataCell(Text(isBulkOrder ? '' : '${sale['items'][0]['quantity']}')),
                                  DataCell(Text(isBulkOrder ? '' : sale['items'][0]['mainCategory'] ?? 'N/A')),
                                  DataCell(Text('₱${(sale['totalTransactionPrice'] ?? 0.0).toStringAsFixed(2)}')),
                                  DataCell(Text(
                                    sale['orderDate'] != null && sale['orderDate'] is Timestamp
                                        ? DateFormat('yyyy-MM-dd HH:mm:ss').format((sale['orderDate'] as Timestamp).toDate())
                                        : 'No Date Provided',
                                  )),
                                ],
                              ),
                            );

                            // Expanded rows for bulk orders
                            if (isExpanded) {
                              rows.addAll((sale['items'] as List).map<DataRow>((item) {
                                return DataRow(
                                  key: ValueKey('${sale['orNumber']}_${item['label']}_${item['itemSize']}'),
                                  cells: [
                                    DataCell(Text('')),
                                    DataCell(Text('')),
                                    DataCell(Text('')),
                                    DataCell(Text(item['label'] ?? 'N/A')),
                                    DataCell(Text(item['itemSize'] ?? 'N/A')),
                                    DataCell(Text('${item['quantity']}')),
                                    DataCell(Text(item['mainCategory'] ?? 'N/A')),
                                    DataCell(Text('₱${(item['totalPrice'] ?? 0.0).toStringAsFixed(2)}')),
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
                  );
                } else {
                  return Center(child: CustomText(text: "No data available"));
                }
              },
            ),
          ),

          // Total Revenue Display
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total Revenue: ₱${_totalRevenue.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
