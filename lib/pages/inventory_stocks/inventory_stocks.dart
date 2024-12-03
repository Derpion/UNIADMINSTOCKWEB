import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unistock/pages/inventory_stocks/InventorySummaryPage.dart';


class InventoryPage extends StatefulWidget {
  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  Map<String, Map<String, dynamic>> _seniorHighStockQuantities = {};
  Map<String, Map<String, dynamic>> _collegeStockQuantities = {};
  Map<String, Map<String, dynamic>> _merchStockQuantities = {};
  Map<String, Map<String, dynamic>> _prowareStockQuantities = {};

  bool _loading = true;
  String? _selectedCourseLabel;
  String? _selectedSize;
  String? _selectedProwareSubcategory;

  final List<String> _prowareSubcategories = ['NSTP', 'PE', 'Proware'];
  final List<String> _courseLabels = ['BACOMM', 'HRM & Culinary', 'IT&CPE', 'Tourism', 'BSA & BSBA'];
  final List<String> _availableSizes = ['Default', 'XS', 'Small', 'Medium', 'Large', 'XL', '2XL', '3XL', '4XL', '5XL', '6XL', '7XL', '2.5 Yards', '2.7 Yards', '3 Yards',];
  final List<String> sortedSizeOrder = ['XS', 'Small', 'Medium', 'Large', 'XL', '2XL', '3XL', '4XL', '5XL', '6XL', '7XL'];

  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  List<Map<String, dynamic>> _filteredItems = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInventoryData();
    _searchController.addListener(_filterItems);
  }

  Future<void> _fetchInventoryData() async {
    try {
      setState(() {
        _loading = true;
      });

      await Future.wait(<Future>[
        _fetchSeniorHighStock(),
        _fetchCollegeStock(),
        _fetchMerchStock(),
        _fetchProwareStock(),
      ]);

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _filterItems() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = [
        ..._seniorHighStockQuantities.entries.map((entry) {
          return {
            'id': entry.key,
            'label': entry.value['label'],
            'stock': entry.value['stock'],
            'category': 'senior_high_items',
          };
        }),
        ..._collegeStockQuantities.entries.expand((entry) {
          return entry.value.entries.map((itemEntry) {
            return {
              'id': itemEntry.key,
              'label': itemEntry.value['label'],
              'stock': itemEntry.value['stock'],
              'category': entry.key,
            };
          });
        }),
        ..._merchStockQuantities.entries.map((entry) {
          return {
            'id': entry.key,
            'label': entry.value['label'],
            'stock': entry.value['stock'],
            'category': 'Merch & Accessories',
          };
        }),
        ..._prowareStockQuantities.entries.expand((subcategoryEntry) {
          return subcategoryEntry.value.entries.map((itemEntry) {
            return {
              'id': itemEntry.key,
              'label': itemEntry.value['label'],
              'stock': itemEntry.value['stock'],
              'category': subcategoryEntry.key,
            };
          });
        }),
      ].where((item) {
        return (item['label'] as String).toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _fetchSeniorHighStock() async {
    try {
      QuerySnapshot seniorHighSnapshot = await firestore
          .collection('Inventory_stock')
          .doc('senior_high_items')
          .collection('Items')
          .get();

      Map<String, Map<String, dynamic>> seniorHighData = {};
      seniorHighSnapshot.docs.forEach((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> stockData = {};
        String? imagePath = data['imagePath'] as String?;
        String label = data['label'] != null ? data['label'] as String : doc.id;

        if (data.containsKey('sizes') && data['sizes'] is Map) {
          Map<String, dynamic> sizes = data['sizes'] as Map<String, dynamic>;
          sizes.forEach((sizeKey, sizeValue) {
            if (sizeValue is Map && sizeValue.containsKey('quantity')) {
              stockData[sizeKey] = {
                'quantity': sizeValue['quantity'],
                'price': sizeValue['price'] ?? 0.0,
              };
            }
          });
        }

        seniorHighData[doc.id] = {
          'stock': stockData,
          'imagePath': imagePath ?? '',
          'label': label,
          'price': data['price'] ?? 0.0,
        };
      });

      setState(() {
        _seniorHighStockQuantities = seniorHighData;
      });
    } catch (e) {}
  }

  Future<void> _fetchCollegeStock() async {
    try {
      Map<String, Map<String, dynamic>> collegeData = {};
      for (String courseLabel in _courseLabels) {
        QuerySnapshot courseSnapshot = await firestore
            .collection('Inventory_stock')
            .doc('college_items')
            .collection(courseLabel)
            .get();

        Map<String, Map<String, dynamic>> courseItems = {};
        courseSnapshot.docs.forEach((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String label = data['label'] ?? doc.id;
          Map<String, dynamic> stockData = {};

          if (data.containsKey('sizes') && data['sizes'] is Map) {
            Map<String, dynamic> sizes = data['sizes'] as Map<String, dynamic>;
            sizes.forEach((sizeKey, sizeValue) {
              if (sizeValue is Map && sizeValue.containsKey('quantity')) {
                stockData[sizeKey] = {
                  'quantity': sizeValue['quantity'] ?? 0,
                  'price': sizeValue['price'] ?? 0.0,
                };
              }
            });
          }

          courseItems[doc.id] = {
            'label': label,
            'stock': stockData,
            'price': data['price'] ?? 0.0,
          };
        });

        collegeData[courseLabel] = courseItems;
      }

      setState(() {
        _collegeStockQuantities = collegeData;
      });
    } catch (e) {
    }
  }

  Future<void> _fetchMerchStock() async {
    try {
      DocumentSnapshot merchSnapshot = await firestore
          .collection('Inventory_stock')
          .doc('Merch & Accessories')
          .get();

      Map<String, dynamic> merchData = merchSnapshot.data() as Map<
          String,
          dynamic>;
      Map<String, Map<String, dynamic>> processedMerchData = {};

      merchData.forEach((key, value) {
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

          processedMerchData[key] = {
            'label': key,
            'imagePath': value['imagePath'] ?? '',
            'stock': stockData,
          };
        }
      });

      setState(() {
        _merchStockQuantities = processedMerchData;
      });
    } catch (e) {}
  }

  Future<void> _fetchProwareStock() async {
    try {
      List<String> subcategories = ["NSTP", "PE", "Proware"];
      Map<String, Map<String, dynamic>> prowareData = {};

      for (String subcategory in subcategories) {
        QuerySnapshot subcategorySnapshot = await firestore
            .collection('Inventory_stock')
            .doc('Proware & PE')
            .collection(subcategory)
            .get();

        Map<String, Map<String, dynamic>> subcategoryItems = {};
        subcategorySnapshot.docs.forEach((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String label = data['label'] ?? doc.id;
          String imagePath = data['imagePath'] ?? '';
          Map<String, dynamic> stockData = {};

          if (data.containsKey('sizes') && data['sizes'] is Map) {
            Map<String, dynamic> sizes = data['sizes'] as Map<String, dynamic>;
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
            'label': label,
            'imagePath': imagePath,
            'stock': stockData,
            'subcategory': subcategory,
          };
        });

        prowareData[subcategory] = subcategoryItems;
      }

      setState(() {
        _prowareStockQuantities = prowareData;
      });
    } catch (e) {
    }
  }

  void _showAddSizeDialog(String itemKey, Map<String, dynamic> itemData, String collectionType, [String? subcategory]) {
    _selectedSize = null;
    _priceController.clear();
    _quantityController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Size and Price'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedSize,
                items: _availableSizes.map((String size) {
                  return DropdownMenuItem<String>(
                    value: size,
                    child: Text(size),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedSize = newValue;
                  });
                },
                decoration: InputDecoration(labelText: 'Size'),
              ),
              TextField(
                controller: _priceController,
                decoration: InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: _quantityController,
                decoration: InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_selectedSize != null) {
                  _addCustomSize(itemKey, itemData, collectionType, subcategory);
                  Navigator.of(context).pop();
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addCustomSize(String itemKey, Map<String, dynamic> itemData, String collectionType, [String? subcategory]) {

    if (collectionType == 'Proware & PE' && (subcategory == null || subcategory.isEmpty)) {
      return;
    }

    String size = _selectedSize ?? '';
    double? price = _priceController.text.isNotEmpty ? double.tryParse(_priceController.text) : null;
    int? newQuantity = _quantityController.text.isNotEmpty ? int.tryParse(_quantityController.text) : null;
    if (itemData['stock'].containsKey(size)) {
      int currentQuantity = itemData['stock'][size]['quantity'];
      double currentPrice = itemData['stock'][size]['price'];

      itemData['stock'][size] = {
        'quantity': (newQuantity ?? 0) + currentQuantity,
        'price': price ?? currentPrice,
      };
    } else {
      itemData['stock'][size] = {
        'quantity': newQuantity ?? 0,
        'price': price ?? 0.0,
      };
    }

    DocumentReference docRef;
    Map<String, dynamic> updateData = {
      if (newQuantity != null) 'sizes.$size.quantity': FieldValue.increment(newQuantity),
      if (price != null) 'sizes.$size.price': price,
    };

    if (collectionType == 'senior_high_items') {
      docRef = firestore
          .collection('Inventory_stock')
          .doc('senior_high_items')
          .collection('Items')
          .doc(itemKey);
    } else if (collectionType == 'college_items') {
      docRef = firestore
          .collection('Inventory_stock')
          .doc('college_items')
          .collection(_selectedCourseLabel!)
          .doc(itemKey);
    } else if (collectionType == 'Merch & Accessories') {
      docRef = firestore
          .collection('Inventory_stock')
          .doc('Merch & Accessories')
          .collection('Items')
          .doc(itemKey);
    } else if (collectionType == 'Proware & PE') {
      docRef = firestore
          .collection('Inventory_stock')
          .doc('Proware & PE')
          .collection(subcategory!)
          .doc(itemKey);
    } else {
      return;
    }

    docRef.update(updateData).then((_) {
      setState(() {
        if (collectionType == 'Proware & PE') {
          _fetchProwareStock();
        } else {
          _fetchInventoryData();
        }
      });
    }).catchError((error) {
    });
  }

  void _updateQuantity(String itemKey, String size, int change, String collectionType, [String? subcategory]) {
    if (collectionType == 'Proware & PE' && subcategory == null) {
      return;
    }

    // Declare docRef only once at the top
    late DocumentReference docRef;

    // Define the update data (common for all types)
    Map<String, dynamic> updateData = {
      'sizes.$size.quantity': FieldValue.increment(change),
    };

    // Initialize docRef based on collectionType
    if (collectionType == 'senior_high_items') {
      docRef = firestore
          .collection('Inventory_stock')
          .doc('senior_high_items')
          .collection('Items')
          .doc(itemKey);

      setState(() {
        int currentQuantity = _seniorHighStockQuantities[itemKey]?['stock'][size]['quantity'] ?? 0;
        _seniorHighStockQuantities[itemKey]?['stock'][size]['quantity'] = currentQuantity + change;
      });
    } else if (collectionType == 'college_items') {
      docRef = firestore
          .collection('Inventory_stock')
          .doc('college_items')
          .collection(_selectedCourseLabel!)
          .doc(itemKey);

      setState(() {
        int currentQuantity = _collegeStockQuantities[_selectedCourseLabel!]?[itemKey]?['stock'][size]['quantity'] ?? 0;
        _collegeStockQuantities[_selectedCourseLabel!]?[itemKey]?['stock'][size]['quantity'] = currentQuantity + change;
      });
    } else if (collectionType == 'Merch & Accessories') {
      docRef = firestore
          .collection('Inventory_stock')
          .doc('Merch & Accessories');

      // Define and perform the update
      docRef.update({
        '${itemKey}.sizes.${size}.quantity': FieldValue.increment(change),
      }).then((_) {
        setState(() {
          int currentQuantity = _merchStockQuantities[itemKey]?['stock'][size]['quantity'] ?? 0;
          _merchStockQuantities[itemKey]?['stock'][size]['quantity'] = currentQuantity + change;
        });
      }).catchError((error) {
        print("Failed to update quantity: $error");
      });

      // Exit early since update is performed here
      return;
    } else if (collectionType == 'Proware & PE') {
      docRef = firestore
          .collection('Inventory_stock')
          .doc('Proware & PE')
          .collection(subcategory!)
          .doc(itemKey);

      setState(() {
        int currentQuantity = _prowareStockQuantities[subcategory]?[itemKey]?['stock'][size]['quantity'] ?? 0;
        _prowareStockQuantities[subcategory]?[itemKey]?['stock'][size]['quantity'] = currentQuantity + change;
      });
    } else {
      return;
    }

    // Perform the update for other collection types
    docRef.update(updateData).catchError((error) {
      print("Failed to update quantity: $error");
    });
  }

  Widget _buildItemCard(String itemKey, Map<String, dynamic> itemData, String collectionType) {
    String label = itemData['label'] ?? 'Unknown Item';
    String imagePath = itemData['imagePath'] ?? '';
    Map<String, dynamic> stock = itemData['stock'] ?? {};
    String? subcategory = collectionType == 'Proware & PE' ? itemData['subcategory'] : null;

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "$label",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          if (imagePath.isNotEmpty)
            Image.network(
              imagePath,
              height: 100,
              errorBuilder: (_, __, ___) => Icon(Icons.broken_image),
            )
          else
            Icon(Icons.image_not_supported, size: 100),
          SizedBox(height: 8),
          if (stock.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (stock.keys.toList()
                    ..sort((a, b) {
                      int indexA = sortedSizeOrder.indexOf(a);
                      int indexB = sortedSizeOrder.indexOf(b);
                      if (indexA == -1) return 1;
                      if (indexB == -1) return -1;
                      return indexA.compareTo(indexB);
                    }))
                      .map((size) {
                    int currentQuantity = stock[size]['quantity'] ?? 0;
                    double currentPrice = stock[size]['price']?.toDouble() ?? 0.0;

                    Color quantityColor = currentQuantity == 0
                        ? Colors.red
                        : (currentQuantity < 10 ? Colors.orange : Colors.black);

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$size: $currentQuantity available, ₱$currentPrice',
                            style: TextStyle(color: quantityColor),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: currentQuantity > 0
                              ? () {
                            _updateQuantity(itemKey, size, -1, collectionType, subcategory);
                          }
                              : null,
                        ),
                        IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () {
                            _updateQuantity(itemKey, size, 1, collectionType, subcategory);
                          },
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            )
          else
            Text('No sizes available'),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              _showAddSizeDialog(itemKey, itemData, collectionType, subcategory);
            },
            child: Text('Add Size'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        labelText: 'Search by Label',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Page'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _fetchInventoryData();
            },
          ),
          IconButton(
            icon: Icon(Icons.list),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => InventorySummaryPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSearchBar(),
            SizedBox(height: 16),

            _searchController.text.isNotEmpty
                ? _filteredItems.isEmpty
                ? Expanded(
                child: Center(child: Text('No items match your search')))
                : Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.8,
                children: _filteredItems.map((item) {
                  return _buildItemCard(item['id'], item, item['category']);
                }).toList(),
              ),
            )
                : Expanded(
              child: ListView(
                children: [
                  Text(
                    'Senior High Inventory',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                  ),
                  _seniorHighStockQuantities.isEmpty
                      ? Center(child: Text('No items available'))
                      : GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.8,
                    children: _seniorHighStockQuantities.keys.map((itemKey) {
                      Map<String, dynamic> itemData =
                      _seniorHighStockQuantities[itemKey]!;
                      return _buildItemCard(
                          itemKey, itemData, 'senior_high_items');
                    }).toList(),
                  ),
                  SizedBox(height: 16),

                  Text(
                    'College Inventory',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                  ),
                  DropdownButton<String>(
                    value: _selectedCourseLabel,
                    hint: Text('Select Course Label'),
                    items: _courseLabels.map((String label) {
                      return DropdownMenuItem<String>(
                        value: label,
                        child: Text(label),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedCourseLabel = newValue;
                      });
                    },
                  ),
                  _selectedCourseLabel != null &&
                      _collegeStockQuantities[_selectedCourseLabel!] != null
                      ? GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.8,
                    children: _collegeStockQuantities[_selectedCourseLabel!]!
                        .keys
                        .map((itemKey) {
                      Map<String, dynamic> itemData =
                      _collegeStockQuantities[_selectedCourseLabel!]![itemKey]!;
                      return _buildItemCard(
                          itemKey, itemData, 'college_items');
                    }).toList(),
                  )
                      : Center(
                      child: Text('Select a course to view inventory')),
                  SizedBox(height: 16),
                  Text(
                    'Proware & PE Inventory',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                  ),
                  DropdownButton<String>(
                    value: _selectedProwareSubcategory,
                    hint: Text('Select Subcategory'),
                    items: _prowareSubcategories.map((String subcategory) {
                      return DropdownMenuItem<String>(
                        value: subcategory,
                        child: Text(subcategory),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedProwareSubcategory = newValue;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  _selectedProwareSubcategory != null &&
                      _prowareStockQuantities[_selectedProwareSubcategory!] != null
                      ? GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.8,
                    children: _prowareStockQuantities[_selectedProwareSubcategory!]!
                        .keys
                        .map((itemKey) {
                      Map<String, dynamic> itemData =
                      _prowareStockQuantities[_selectedProwareSubcategory!]![itemKey]!;
                      return _buildItemCard(itemKey, itemData, 'Proware & PE');
                    }).toList(),
                  ) : Center(child: Text('Select a subcategory to view inventory')),
                  SizedBox(height: 16),

                  Text(
                    'Merch & Accessories Inventory',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                  ),
                  _merchStockQuantities.isEmpty
                      ? Center(child: Text('No items available'))
                      : GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.8,
                    children: _merchStockQuantities.keys.map((itemKey) {
                      Map<String, dynamic> itemData =
                      _merchStockQuantities[itemKey]!;
                      return _buildItemCard(
                          itemKey, itemData, 'Merch & Accessories');
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}