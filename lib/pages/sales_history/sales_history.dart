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

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredSalesData = [];

  Set<String> expandedBulkOrders = Set<String>();
  Future<List<Map<String, dynamic>>>? _salesDataFuture;
  List<Map<String, dynamic>> _allSalesItems = [];
  double _totalRevenue = 0.0;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _salesDataFuture = _fetchSalesData();
    _searchController.addListener(_filterSalesData);
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
      _filteredSalesData = List.from(allSalesItems);
    });

    return allSalesItems;
  }

void _filterSalesData() {
  String query = _searchController.text.toLowerCase();
  double filteredRevenue = 0.0;

  setState(() {
    _filteredSalesData = _allSalesItems.where((sale) {
      // Check date filter
      bool matchesDate = true;
      if (_startDate != null || _endDate != null) {
        DateTime orderDate = (sale['orderDate'] as Timestamp).toDate();
        if (_startDate != null) {
          matchesDate &= orderDate.isAfter(_startDate!) ||
              orderDate.isAtSameMomentAs(_startDate!);
        }
        if (_endDate != null) {
          matchesDate &= orderDate.isBefore(_endDate!) ||
              orderDate.isAtSameMomentAs(_endDate!);
        }
      }

      // Check label filter
      if (query.isEmpty) return matchesDate;

      if (sale['isBulk'] == true) {
        // For bulk orders, only include matching items
        List matchingItems = (sale['items'] as List).where((item) {
          return (item['label'] ?? '').toString().toLowerCase().contains(query);
        }).toList();

        // If no matching items, exclude this sale
        if (matchingItems.isEmpty) return false;

        // Replace the items with only the matching ones
        sale['items'] = matchingItems;
        return matchesDate;
      } else {
        // For single orders, match the first item's label
        return matchesDate &&
            (sale['items'][0]['label'] ?? '')
                .toString()
                .toLowerCase()
                .contains(query);
      }
    }).toList();

    // Recalculate the revenue based on the filtered data
    for (var sale in _filteredSalesData) {
      filteredRevenue += sale['totalTransactionPrice'] ?? 0.0;
    }
    _totalRevenue = filteredRevenue;
  });
}

  Future<void> _generatePDF(List<Map<String, dynamic>> salesData) async {
    final pdf = pw.Document();
    const int rowsPerPage = 10;
    final String currentDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    int pageCount = (salesData.length / rowsPerPage).ceil();

    for (int page = 0; page < pageCount; page++) {
      final rowsChunk = salesData.skip(page * rowsPerPage).take(rowsPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                  pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Sales Report (Page ${page + 1} of $pageCount)',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                  pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Generated on: $currentDateTime',
                    style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(4),
                    4: const pw.FlexColumnWidth(2),
                    5: const pw.FlexColumnWidth(1),
                    6: const pw.FlexColumnWidth(2),
                    7: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Text('OR Number', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Student Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Student ID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Item Label', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Item Size', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Total Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    ..._buildTableRows(rowsChunk),
                  ],
                ),
                if (page == pageCount - 1)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 16),
                    child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        'Total Revenue: ₱${_totalRevenue.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  List<pw.TableRow> _buildTableRows(List<Map<String, dynamic>> rowsChunk) {
    List<pw.TableRow> tableRows = [];

    for (var saleItem in rowsChunk) {
      if (saleItem['isBulk'] == true && saleItem['items'] != null) {
        tableRows.add(
          pw.TableRow(
            children: [
              pw.Text(saleItem['orNumber'] ?? 'N/A'),
              pw.Text(saleItem['userName'] ?? 'N/A'),
              pw.Text(saleItem['studentNumber'] ?? 'N/A'),
              pw.Text('Bulk Order (${saleItem['items'].length} items)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(''),
              pw.Text(''),
              pw.Text(''),
              pw.Text('₱${(saleItem['totalTransactionPrice'] ?? 0.0).toStringAsFixed(2)}'),
            ],
          ),
        );

        for (var item in saleItem['items']) {
          tableRows.add(
            pw.TableRow(
              children: [
                pw.Text(''),
                pw.Text(''),
                pw.Text(''),
                pw.Text(item['label'] ?? 'N/A'),
                pw.Text(item['itemSize'] ?? 'N/A'),
                pw.Text('${item['quantity'] ?? 0}'),
                pw.Text(item['mainCategory'] ?? 'N/A'),
                pw.Text('₱${(item['totalPrice'] ?? 0.0).toStringAsFixed(2)}'),
              ],
            ),
          );
        }
      } else {
        tableRows.add(
          pw.TableRow(
            children: [
              pw.Text(saleItem['orNumber'] ?? 'N/A'),
              pw.Text(saleItem['userName'] ?? 'N/A'),
              pw.Text(saleItem['studentNumber'] ?? 'N/A'),
              pw.Text(
                  saleItem['items'] != null && saleItem['items'].isNotEmpty
                      ? saleItem['items'][0]['label']
                      : 'N/A'),
              pw.Text(
                  saleItem['items'] != null && saleItem['items'].isNotEmpty
                      ? saleItem['items'][0]['itemSize']
                      : 'N/A'),
              pw.Text(
                  saleItem['items'] != null && saleItem['items'].isNotEmpty
                      ? '${saleItem['items'][0]['quantity']}'
                      : '0'),
              pw.Text(
                  saleItem['items'] != null && saleItem['items'].isNotEmpty
                      ? saleItem['items'][0]['mainCategory']
                      : 'N/A'),
              pw.Text('₱${(saleItem['totalTransactionPrice'] ?? 0.0).toStringAsFixed(2)}'),
            ],
          ),
        );
      }
    }

    return tableRows;
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
              if (_filteredSalesData.isNotEmpty) {
                await _generatePDF(_filteredSalesData);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("No sales data to print")),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              _startDate = pickedDate;
                              _filterSalesData();
                            });
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                          child: Text(
                            _startDate != null
                                ? DateFormat('yyyy-MM-dd').format(_startDate!)
                                : 'Start Date',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16.0),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              _endDate = pickedDate;
                              _filterSalesData();
                            });
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                          child: Text(
                            _endDate != null
                                ? DateFormat('yyyy-MM-dd').format(_endDate!)
                                : 'End Date',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.0),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search by Item Label',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
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
