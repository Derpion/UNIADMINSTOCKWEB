import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

class InventorySummaryPage extends StatefulWidget {
  @override
  _InventorySummaryPageState createState() => _InventorySummaryPageState();
}

class _InventorySummaryPageState extends State<InventorySummaryPage> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  String? _selectedSubcategory;
  Map<String, Map<String, dynamic>> _seniorHighStock = {};
  Map<String, Map<String, dynamic>> _collegeStock = {};
  Map<String, Map<String, dynamic>> _merchStock = {};
  Map<String, Map<String, dynamic>> _prowareStock = {};
  Map<String, Map<String, Map<String, int>>> _soldData = {};
  Map<String, Map<String, dynamic>> _filteredSeniorHighStock = {};
  Map<String, Map<String, dynamic>> _filteredCollegeStock = {};
  Map<String, Map<String, dynamic>> _filteredMerchStock = {};
  Map<String, Map<String, dynamic>> _filteredProwareStock = {};
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _loading = true;
  final List<String> sortedSizeOrder = ['XS', 'Small', 'Medium', 'Large', 'XL', '2XL', '3XL', '4XL', '5XL', '6XL', '7XL'];

  @override
  void initState() {
    _searchController.addListener(_filterInventory);
    super.initState();
    _fetchInventoryData();
  }

  Future<void> _fetchInventoryData() async {
    try {
      setState(() {
        _loading = true;
      });

      await Future.wait([
        _fetchSeniorHighStock(),
        _fetchCollegeStock(),
        _fetchMerchStock(),
        _fetchProwareStock(),
        _fetchSoldData(),
      ]);

      setState(() {
        _filteredSeniorHighStock = _seniorHighStock;
        _filteredCollegeStock = _collegeStock;
        _filteredMerchStock = _merchStock;
        _filteredProwareStock = _prowareStock;

        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  void debugSoldData() {
    _soldData.forEach((key, value) {
    });
  }

  Future<void> _fetchSoldData() async {
    try {
      QuerySnapshot snapshot = await firestore.collection('admin_transactions').get();
      Map<String, Map<String, Map<String, int>>> newSoldData = {};

      for (var doc in snapshot.docs) {
        var docData = doc.data() as Map<String, dynamic>;
        if (docData['items'] is List) {
          List items = docData['items'];
          for (var item in items) {
            if (item is Map<String, dynamic>) {
              String category = (item['mainCategory'] ?? '').toLowerCase().trim();
              String label = (item['label'] ?? '').toLowerCase().trim();
              String size = (item['itemSize'] ?? '').toLowerCase().trim();
              int quantity = item['quantity'] ?? 0;
              newSoldData.putIfAbsent(category, () => {});
              newSoldData[category]!.putIfAbsent(label, () => {});
              newSoldData[category]![label]!.update(size, (value) => value + quantity, ifAbsent: () => quantity);
            }
          }
        }
      }

      setState(() {
        _soldData = newSoldData;
      });
    } catch (e) {
    }
  }

  Future<void> _fetchSeniorHighStock() async {
    try {
      QuerySnapshot snapshot = await firestore
          .collection('Inventory_stock')
          .doc('senior_high_items')
          .collection('Items')
          .get();

      Map<String, Map<String, dynamic>> data = {};
      for (var doc in snapshot.docs) {
        Map<String, dynamic> docData = doc.data() as Map<String, dynamic>;

        Map<String, dynamic> stockData = {};
        if (docData.containsKey('sizes') && docData['sizes'] is Map) {
          Map<String, dynamic> sizes = docData['sizes'] as Map<String, dynamic>;
          sizes.forEach((sizeKey, sizeValue) {
            if (sizeValue is Map && sizeValue.containsKey('quantity')) {
              stockData[sizeKey] = {
                'quantity': sizeValue['quantity'],
                'price': sizeValue['price'] ?? 0.0,
              };
            }
          });
        }

        data[doc.id] = {
          'label': docData['label'] ?? doc.id,
          'stock': stockData,
        };
      }

      setState(() {
        _seniorHighStock = data;
      });
    } catch (e) {
    }
  }

  Future<void> _fetchCollegeStock() async {
    try {
      Map<String, Map<String, dynamic>> data = {};
      List<String> courseLabels = ['BACOMM', 'HRM & Culinary', 'IT&CPE', 'Tourism', 'BSA & BSBA'];

      for (String courseLabel in courseLabels) {
        QuerySnapshot snapshot = await firestore
            .collection('Inventory_stock')
            .doc('college_items')
            .collection(courseLabel)
            .get();

        Map<String, Map<String, dynamic>> courseData = {};
        for (var doc in snapshot.docs) {
          Map<String, dynamic> docData = doc.data() as Map<String, dynamic>;

          Map<String, dynamic> stockData = {};
          if (docData.containsKey('sizes') && docData['sizes'] is Map) {
            Map<String, dynamic> sizes = docData['sizes'] as Map<String, dynamic>;
            sizes.forEach((sizeKey, sizeValue) {
              if (sizeValue is Map && sizeValue.containsKey('quantity')) {
                stockData[sizeKey] = {
                  'quantity': sizeValue['quantity'] ?? 0,
                  'price': sizeValue['price'] ?? 0.0,
                };
              }
            });
          }

          courseData[doc.id] = {
            'label': docData['label'] ?? doc.id,
            'stock': stockData,
          };
        }
        data[courseLabel] = courseData;
      }

      setState(() {
        _collegeStock = data;
      });
    } catch (e) {
    }
  }

  Future<void> _fetchMerchStock() async {
    try {
      DocumentSnapshot doc = await firestore
          .collection('Inventory_stock')
          .doc('Merch & Accessories')
          .get();

      Map<String, dynamic> docData = doc.data() as Map<String, dynamic>;
      Map<String, Map<String, dynamic>> data = {};

      docData.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          Map<String, dynamic> stockData = {};
          if (value.containsKey('sizes') && value['sizes'] is Map) {
            Map<String, dynamic> sizes = value['sizes'] as Map<String, dynamic>;
            sizes.forEach((sizeKey, sizeValue) {
              if (sizeValue is Map && sizeValue.containsKey('quantity')) {
                stockData[sizeKey] = {
                  'quantity': sizeValue['quantity'],
                  'price': sizeValue['price'] ?? 0.0,
                };
              }
            });
          }

          data[key] = {
            'label': value['label'] ?? key,
            'stock': stockData,
          };
        }
      });

      setState(() {
        _merchStock = data;
      });
    } catch (e) {
    }
  }

  Future<void> _fetchProwareStock() async {
    try {
      List<String> subcategories = ['NSTP', 'PE', 'Proware'];
      Map<String, Map<String, dynamic>> prowareData = {};

      for (String subcategory in subcategories) {
        QuerySnapshot subcategorySnapshot = await firestore
            .collection('Inventory_stock')
            .doc('Proware & PE')
            .collection(subcategory)
            .get();

        Map<String, Map<String, dynamic>> subcategoryItems = {};
        for (var doc in subcategorySnapshot.docs) {
          Map<String, dynamic> docData = doc.data() as Map<String, dynamic>;

          Map<String, dynamic> stockData = {};
          if (docData.containsKey('sizes') && docData['sizes'] is Map) {
            Map<String, dynamic> sizes = docData['sizes'] as Map<String, dynamic>;
            sizes.forEach((sizeKey, sizeValue) {
              if (sizeValue is Map && sizeValue.containsKey('quantity')) {
                stockData[sizeKey] = {
                  'quantity': sizeValue['quantity'] ?? 0,
                  'price': sizeValue['price'] ?? 0.0,
                };
              }
            });
          }

          subcategoryItems[doc.id] = {
            'label': docData['label'] ?? doc.id,
            'stock': stockData,
            'subcategory': subcategory,
          };
        }

        prowareData[subcategory] = subcategoryItems;
      }

      setState(() {
        _prowareStock = prowareData;
      });
    } catch (e) {
    }
  }

  Widget _buildStockSummary(String category, Map<String, Map<String, dynamic>>? stockData) {

    final categoryMapping = {
      'Senior High': 'senior_high_items',
      'College': 'college_items',
      'Merch & Accessories': 'merch & accessories',
      'Proware & PE': 'proware_and_pe',
    };

    String soldDataCategory = categoryMapping[category] ?? category.toLowerCase();
    final categorySoldData = _soldData[soldDataCategory] ?? {};

    if (stockData == null || stockData.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Text(
              '$category Summary',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              textAlign: TextAlign.center,
            ),
          ),
          Center(
            child: Text('No items available', style: TextStyle(fontStyle: FontStyle.italic)),
          ),
          Divider(thickness: 1),
        ],
      );
    }

    if (category == 'College') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Text(
              '$category Summary',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              textAlign: TextAlign.center,
            ),
          ),
          ...stockData.keys.map((courseKey) {
            final courseItems = stockData[courseKey] ?? {};
            if (courseItems.isEmpty) return SizedBox.shrink();

            return ExpansionTile(
              title: Center(
                child: Text(courseKey, style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              children: courseItems.keys.map((itemKey) {
                final item = courseItems[itemKey];
                final label = item?['label'] ?? itemKey;
                final stock = item?['stock'] as Map<String, dynamic>? ?? {};
                final normalizedLabel = label.toString().toLowerCase().trim();
                Map<String, int> soldItems = categorySoldData[normalizedLabel] ?? {};

                final sortedSizes = stock.keys.toList()
                ..sort((a, b) {
                  int indexA = sortedSizeOrder.indexOf(a);
                  int indexB = sortedSizeOrder.indexOf(b);
                  if (indexA == -1) return 1;
                  if (indexB == -1) return -1;
                  return indexA.compareTo(indexB);
                });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(
                      child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Center(
                      child: DataTable(
                        columns: [
                          DataColumn(label: Center(child: Text('Size'))),
                          DataColumn(label: Center(child: Text('Quantity On Hand'))),
                          DataColumn(label: Center(child: Text('Quantity Sold'))),
                          DataColumn(label: Center(child: Text('Price'))),
                        ],
                        rows: sortedSizes.map((sizeKey) {
                          final size = stock[sizeKey];
                          final soldQuantity = soldItems[sizeKey.toLowerCase()] ?? 0;
                          return DataRow(cells: [
                            DataCell(Center(child: Text(sizeKey))),
                            DataCell(Center(child: Text('${size['quantity']}'))),
                            DataCell(Center(child: Text('$soldQuantity'))),
                            DataCell(Center(child: Text('₱${size['price'].toStringAsFixed(2)}'))),
                          ]);
                        }).toList(),
                      ),
                    ),
                    Divider(thickness: 1),
                  ],
                );
              }).toList(),
            );
          }).toList(),
        ],
      );
    }

    if (category == 'Proware & PE') {
      final subcategories = stockData?.keys.toList() ?? [];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Text(
              '$category Summary',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 8),
          DropdownButton<String>(
            value: _selectedSubcategory,
            hint: Text('Select Subcategory'),
            onChanged: (value) {
              setState(() {
                _selectedSubcategory = value;
              });


              final subcategorySoldData = _extractSoldDataForSubcategory(value, _soldData['proware & pe'] ?? {});
            },
            items: subcategories.map((subcategory) {
              return DropdownMenuItem<String>(
                value: subcategory,
                child: Text(subcategory),
              );
            }).toList(),
          ),
          if (_selectedSubcategory != null)
            ..._buildProwareSubcategoryItems(
              stockData[_selectedSubcategory!] ?? {},
              _extractSoldDataForSubcategory(_selectedSubcategory, _soldData['proware & pe'] ?? {}),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Text(
            '$category Summary',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            textAlign: TextAlign.center,
          ),
        ),
        ...stockData.keys.map((itemKey) {
          final item = stockData[itemKey];
          final label = item?['label'] ?? itemKey;
          final stock = item?['stock'] as Map<String, dynamic>? ?? {};
          final normalizedLabel = label.toString().toLowerCase().trim();
          Map<String, int> soldItems = categorySoldData[normalizedLabel] ?? {};

          final sortedSizes = stock.keys.toList()
          ..sort((a, b) {
            int indexA = sortedSizeOrder.indexOf(a);
            int indexB = sortedSizeOrder.indexOf(b);
            if (indexA == -1) return 1;
            if (indexB == -1) return -1;
            return indexA.compareTo(indexB);
          });
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Center(
                child: DataTable(
                  columns: [
                    DataColumn(label: Center(child: Text('Size'))),
                    DataColumn(label: Center(child: Text('Quantity On Hand'))),
                    DataColumn(label: Center(child: Text('Quantity Sold'))),
                    DataColumn(label: Center(child: Text('Price'))),
                  ],
                  rows: sortedSizes.map((sizeKey) {
                    final size = stock[sizeKey];
                    final soldQuantity = soldItems[sizeKey.toLowerCase()] ?? 0;
                    return DataRow(cells: [
                      DataCell(Center(child: Text(sizeKey))),
                      DataCell(Center(child: Text('${size['quantity']}'))),
                      DataCell(Center(child: Text('$soldQuantity'))),
                      DataCell(Center(child: Text('₱${size['price'].toStringAsFixed(2)}'))),
                    ]);
                  }).toList(),
                ),
              ),
              Divider(thickness: 1),
            ],
          );
        }).toList(),
      ],
    );
  }

  Map<String, Map<String, int>> _extractSoldDataForSubcategory(String? subcategory, Map<String, Map<String, int>> soldData) {
    if (subcategory == null) return {};

    final normalizedSubcategory = normalizeKey(subcategory);

    final filteredSoldData = <String, Map<String, int>>{};
    soldData.forEach((soldKey, soldSizes) {
      if (normalizeKey(soldKey).contains(normalizedSubcategory)) {
        filteredSoldData[soldKey] = soldSizes;
      }
    });

    return filteredSoldData;
  }

  String normalizeKey(String key) => key.toLowerCase().trim();

  Map<String, int> matchSoldData(String label, Map<String, Map<String, int>> soldData) {
    final normalizedLabel = normalizeKey(label);
    return soldData.entries
        .firstWhere((entry) => normalizeKey(entry.key) == normalizedLabel, orElse: () => MapEntry("", {}))
        .value;
  }

  List<Widget> _buildProwareSubcategoryItems(Map<String, dynamic> subcategoryData, Map<String, Map<String, int>> soldData) {
    return subcategoryData.keys.map((itemKey) {
      final item = subcategoryData[itemKey];
      final label = item['label'] ?? itemKey;
      final stock = item['stock'] as Map<String, dynamic>? ?? {};
      final normalizedLabel = normalizeKey(label);

      final soldItems = soldData[normalizedLabel] ?? {};

      final sortedSizes = stock.keys.toList()
      ..sort((a, b) {
        int indexA = sortedSizeOrder.indexOf(a);
        int indexB = sortedSizeOrder.indexOf(b);
        if (indexA == -1) return 1; // Unknown sizes go last
        if (indexB == -1) return -1;
        return indexA.compareTo(indexB);
      });

      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Center(
            child: DataTable(
              columns: [
                DataColumn(label: Center(child: Text('Size'))),
                DataColumn(label: Center(child: Text('Quantity On Hand'))),
                DataColumn(label: Center(child: Text('Quantity Sold'))),
                DataColumn(label: Center(child: Text('Price'))),
              ],
              rows: sortedSizes.map((sizeKey) {
                final size = stock[sizeKey];
                final soldQuantity = soldItems[sizeKey.toLowerCase()] ?? 0;
                return DataRow(cells: [
                  DataCell(Center(child: Text(sizeKey))),
                  DataCell(Center(child: Text('${size['quantity']}'))),
                  DataCell(Center(child: Text('$soldQuantity'))),
                  DataCell(Center(child: Text('₱${size['price'].toStringAsFixed(2)}'))),
                ]);
              }).toList(),
            ),
          ),
          Divider(thickness: 1),
        ],
      );
    }).toList();
  }

  Future<void> _printSummary() async {
    final pdf = pw.Document();
    final String currentDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    bool isFirstPage = true;
    
    print("Starting to process category summaries...");

    List<Map<String, dynamic>> categorySummaries = [
      {"title": "Senior High Summary", "data": _seniorHighStock, "soldCategory": "senior_high_items"},
      {"title": "College Summary", "data": _collegeStock, "soldCategory": "college_items"},
      {"title": "Merch & Accessories Summary", "data": _merchStock, "soldCategory": "merch & accessories"},
      {"title": "Proware & PE Summary", "data": _prowareStock, "soldCategory": "proware & pe"},
    ];
    
    for (var category in categorySummaries) {
      String categoryTitle = category["title"];
      Map<String, Map<String, dynamic>>? stockData = category["data"];
      String soldCategory = category["soldCategory"];
      final categorySoldData = _soldData[soldCategory] ?? {};

      print("Processing category: $categoryTitle");
      print("Stock data for $categoryTitle: $stockData");

      if (stockData == null || stockData.isEmpty) {
        print("$categoryTitle has no stock data. Skipping...");
        continue;
      }

      final categoryWidgets = <pw.Widget>[];

    // Adding title and current time at the beginning of the page
    if (isFirstPage) {
      categoryWidgets.add(
        pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Generated on: $currentDateTime',
            style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
          ),
        ),
      );

      categoryWidgets.add(
        pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Inventory Report',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
        ),
      );

      categoryWidgets.add(
        pw.SizedBox(height: 20), // Adding some space after the title and date
      );

      isFirstPage = false; // Set to false after processing the first page
    }

      categoryWidgets.add(
        pw.Text(
          categoryTitle,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      );

      if (categoryTitle == "College Summary") {
        print("Processing College Summary...");
        final processedItems = <String>{}; // To track processed items and avoid duplication

        stockData.forEach((courseLabel, courseItems) {
          print("Course Label: $courseLabel");
          print("Course Items: $courseItems");

          categoryWidgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 12),
              child: pw.Text(
                courseLabel,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
          );

          courseItems.forEach((itemKey, item) {
            if (processedItems.contains(itemKey)) {
              print("Skipping duplicate item: $itemKey");
              return;
            }
            processedItems.add(itemKey);

            final label = item['label'] ?? itemKey;
            final stock = item['stock'] as Map<String, dynamic>? ?? {};
            final normalizedLabel = label.toString().toLowerCase().trim();
            Map<String, int> soldItems = categorySoldData[normalizedLabel] ?? {};

            print("Processing item: $label");
            print("Stock data: $stock");
            print("Sold data: $soldItems");

            categoryWidgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8),
                child: pw.Text(
                  label,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ),
            );

            // Apply sorting here
            final sortedSizes = stock.keys.toList()
              ..sort((a, b) {
                int indexA = sortedSizeOrder.indexOf(a);
                int indexB = sortedSizeOrder.indexOf(b);
                if (indexA == -1) return 1; // Unknown sizes go last
                if (indexB == -1) return -1;
                return indexA.compareTo(indexB);
              });

            categoryWidgets.add(
              pw.Table.fromTextArray(
                headers: ['Size', 'Quantity On Hand', 'Quantity Sold', 'Price'],
                data: sortedSizes.map((sizeKey) {
                  final size = stock[sizeKey];
                  final normalizedSize = sizeKey.toLowerCase();
                  final soldQuantity = soldItems[normalizedSize] ?? 0;

                  print("Size: $sizeKey, Stock: ${size['quantity']}, Sold: $soldQuantity, Price: ${size['price']}");

                  return [
                    sizeKey,
                    size['quantity'].toString(),
                    soldQuantity.toString(),
                    '₱${size['price'].toStringAsFixed(2)}'
                  ];
                }).toList(),
                border: pw.TableBorder.all(),
                cellAlignment: pw.Alignment.centerLeft,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: pw.TextStyle(fontSize: 10),
              ),
            );
          });
        });
      } else if (categoryTitle == "Proware & PE Summary") {
        print("Processing Proware & PE Summary...");
        stockData.forEach((subcategory, subcategoryItems) {
          print("Subcategory: $subcategory");
          print("Subcategory Items: $subcategoryItems");

          if (subcategoryItems.isEmpty) {
            print("Skipping empty subcategory: $subcategory");
            return;
          }

          categoryWidgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 12),
              child: pw.Text(
                subcategory,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
          );

          subcategoryItems.forEach((itemKey, item) {
            final label = item['label'] ?? itemKey;
            final stock = item['stock'] as Map<String, dynamic>? ?? {};
            final normalizedLabel = normalizeKey(label);
            Map<String, int> soldItems = categorySoldData[normalizedLabel] ?? {};

            if (stock.isEmpty) {
              print("Skipping item with no stock: $label");
              return;
            }

            print("Processing item: $label");
            print("Stock data: $stock");
            print("Sold data: $soldItems");

            categoryWidgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8),
                child: pw.Text(
                  label,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ),
            );

            // Apply sorting here
            final sortedSizes = stock.keys.toList()
              ..sort((a, b) {
                int indexA = sortedSizeOrder.indexOf(a);
                int indexB = sortedSizeOrder.indexOf(b);
                if (indexA == -1) return 1;
                if (indexB == -1) return -1;
                return indexA.compareTo(indexB);
              });

            categoryWidgets.add(
              pw.Table.fromTextArray(
                headers: ['Size', 'Quantity On Hand', 'Quantity Sold', 'Price'],
                data: sortedSizes.map((sizeKey) {
                  final size = stock[sizeKey];
                  final normalizedSize = sizeKey.toLowerCase();
                  final soldQuantity = soldItems[normalizedSize] ?? 0;

                  print("Size: $sizeKey, Stock: ${size['quantity']}, Sold: $soldQuantity, Price: ${size['price']}");

                  return [
                    sizeKey,
                    size['quantity'].toString(),
                    soldQuantity.toString(),
                    '₱${size['price'].toStringAsFixed(2)}',
                  ];
                }).toList(),
                border: pw.TableBorder.all(),
                cellAlignment: pw.Alignment.centerLeft,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: pw.TextStyle(fontSize: 10),
              ),
            );
          });
        });
      } else {
        // General case for Senior High and Merch
        stockData.forEach((itemKey, item) {
          print("Processing item in $categoryTitle: $itemKey");
          print("Item details: $item");

          final label = item['label'] ?? itemKey;
          final stock = item['stock'] as Map<String, dynamic>? ?? {};
          final normalizedLabel = label.toString().toLowerCase().trim();
          Map<String, int> soldItems = categorySoldData[normalizedLabel] ?? {};

          categoryWidgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                label,
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            ),
          );

          // Apply sorting here
          final sortedSizes = stock.keys.toList()
            ..sort((a, b) {
              int indexA = sortedSizeOrder.indexOf(a);
              int indexB = sortedSizeOrder.indexOf(b);
              if (indexA == -1) return 1;
              if (indexB == -1) return -1;
              return indexA.compareTo(indexB);
            });

          categoryWidgets.add(
            pw.Table.fromTextArray(
              headers: ['Size', 'Quantity On Hand', 'Quantity Sold', 'Price'],
              data: sortedSizes.map((sizeKey) {
                final size = stock[sizeKey];
                final normalizedSize = sizeKey.toLowerCase();
                final soldQuantity = soldItems[normalizedSize] ?? 0;

                print("Size: $sizeKey, Stock: ${size['quantity']}, Sold: $soldQuantity, Price: ${size['price']}");

                return [
                  sizeKey,
                  size['quantity'].toString(),
                  soldQuantity.toString(),
                  '₱${size['price'].toStringAsFixed(2)}'
                ];
              }).toList(),
              border: pw.TableBorder.all(),
              cellAlignment: pw.Alignment.centerLeft,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: pw.TextStyle(fontSize: 10),
            ),
          );
        });
      }

      // Debug the categoryWidgets before adding to the PDF
      print("Category Widgets for $categoryTitle:");
      categoryWidgets.forEach((widget) {
        print(widget.toString());
      });

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: categoryWidgets,
            ),
          ],
        ),
      );
    }

    print("Finished processing all categories.");

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  void _filterInventory() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();

      _filteredSeniorHighStock = _filterByQuery(_seniorHighStock);
      _filteredCollegeStock = _filterByQuery(_collegeStock, nested: true);
      _filteredMerchStock = _filterByQuery(_merchStock);
      _filteredProwareStock = _filterByQuery(_prowareStock, nested: true);
    });
  }

  Map<String, Map<String, dynamic>> _filterByQuery(
      Map<String, Map<String, dynamic>> stockData, {
        bool nested = false,
      }) {
    if (_searchQuery.isEmpty) {
      return stockData;
    }

    Map<String, Map<String, dynamic>> filtered = {};
    stockData.forEach((key, value) {
      if (nested) {
        Map<String, dynamic> nestedItems = {};
        value.forEach((itemKey, itemValue) {
          if ((itemValue['label'] ?? '').toString().toLowerCase().contains(_searchQuery)) {
            nestedItems[itemKey] = itemValue;
          }
        });
        if (nestedItems.isNotEmpty) {
          filtered[key] = nestedItems;
        }
      } else {
        if ((value['label'] ?? '').toString().toLowerCase().contains(_searchQuery)) {
          filtered[key] = value;
        }
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Loading Inventory...'),
          centerTitle: true,
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Summary'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.print),
            onPressed: _printSummary,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by label...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStockSummary('Senior High', _filteredSeniorHighStock),
                  _buildStockSummary('College', _filteredCollegeStock),
                  _buildStockSummary('Merch & Accessories', _filteredMerchStock),
                  _buildStockSummary('Proware & PE', _filteredProwareStock),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}