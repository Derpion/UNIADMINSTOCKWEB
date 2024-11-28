import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WalkinPage extends StatefulWidget {
  @override
  _MainWalkInPageState createState() => _MainWalkInPageState();
}

class _MainWalkInPageState extends State<WalkinPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _studentNumberController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final Map<String, String?> _selectedSizes = {};
  final Map<String, int> _selectedQuantities = {};
  String? _selectedCategory;
  String? _selectedSchoolLevel;
  String? _selectedCourseLabel;

  Map<String, Map<String, dynamic>> _seniorHighStockQuantities = {};
  Map<String, Map<String, dynamic>> _collegeStockQuantities = {};
  Map<String, Map<String, dynamic>> _merchStockQuantities = {};

  List<String> _courseLabels = ['BACOMM', 'HRM & Culinary', 'IT&CPE', 'Tourism', 'BSA & BSBA'];
  List<String> _schoolLevels = ['College', 'Senior High'];

  bool _loading = true;

  @override
  void initState() {
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

  Future<void> _fetchSeniorHighStock() async {
    try {
      QuerySnapshot seniorHighSnapshot = await FirebaseFirestore.instance
          .collection('Inventory_stock')
          .doc('senior_high_items')
          .collection('Items')
          .get();

      Map<String, Map<String, dynamic>> seniorHighData = {};

      seniorHighSnapshot.docs.forEach((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String? imagePath = data['imagePath'] as String?;
        String label = data['itemLabel'] != null ? data['itemLabel'] as String : doc.id;

        double defaultPrice = data['price'] != null ? data['price'] as double : 0.0;

        Map<String, dynamic> stockData = {};
        if (data.containsKey('sizes') && data['sizes'] is Map) {
          Map<String, dynamic> sizes = data['sizes'] as Map<String, dynamic>;
          sizes.forEach((sizeKey, sizeValue) {
            if (sizeValue is Map) {
              int quantity = sizeValue['quantity'] ?? 0;
              double sizePrice = sizeValue['price'] ?? defaultPrice;

              stockData[sizeKey] = {
                'quantity': quantity,
                'price': sizePrice,
              };
            }
          });
        }

        seniorHighData[doc.id] = {
          'itemLabel': label,
          'imagePath': imagePath ?? '',
          'defaultPrice': defaultPrice,
          'sizes': stockData,
        };
      });

      setState(() {
        _seniorHighStockQuantities = seniorHighData;
      });

    } catch (e) {
    }
  }

  Future<void> _fetchCollegeStock() async {
    try {
      Map<String, Map<String, dynamic>> collegeData = {};

      for (String courseLabel in _courseLabels) {
        QuerySnapshot courseSnapshot = await FirebaseFirestore.instance
            .collection('Inventory_stock')
            .doc('college_items')
            .collection(courseLabel)
            .get();

        Map<String, Map<String, dynamic>> courseItems = {};
        courseSnapshot.docs.forEach((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          // Use the 'label' field and fallback to the document ID if missing
          String label = data['label'] != null && data['label'] != ''
              ? data['label'] as String
              : doc.id;

          double defaultPrice = data['price'] != null ? data['price'] as double : 0.0;

          Map<String, dynamic> stockData = {};
          if (data.containsKey('sizes') && data['sizes'] is Map) {
            Map<String, dynamic> sizes = data['sizes'] as Map<String, dynamic>;
            sizes.forEach((sizeKey, sizeValue) {
              if (sizeValue is Map) {
                int quantity = sizeValue['quantity'] ?? 0;
                double sizePrice = sizeValue['price'] ?? defaultPrice;

                stockData[sizeKey] = {
                  'quantity': quantity,
                  'price': sizePrice,
                };
              }
            });
          }

          courseItems[doc.id] = {
            'label': label,
            'imageUrl': data['imageUrl'] ?? '',
            'defaultPrice': defaultPrice,
            'sizes': stockData,
          };
        });

        collegeData[courseLabel] = courseItems;
      }

      setState(() {
        _collegeStockQuantities = collegeData;
      });

    } catch (e) {
      print("Error fetching college stock: $e");
    }
  }

  Future<void> _fetchMerchStock() async {
    try {
      DocumentSnapshot merchSnapshot = await FirebaseFirestore.instance
          .collection('Inventory_stock')
          .doc('Merch & Accessories')
          .get();

      Map<String, dynamic> merchData = merchSnapshot.data() as Map<String, dynamic>;
      Map<String, Map<String, dynamic>> processedMerchData = {};

      merchData.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          String? imagePath = value['imagePath'] as String?;
          double defaultPrice = value['price'] != null ? value['price'] as double : 0.0;

          Map<String, dynamic> stockData = {};
          if (value.containsKey('sizes') && value['sizes'] is Map) {
            Map<String, dynamic> sizes = value['sizes'] as Map<String, dynamic>;
            sizes.forEach((sizeKey, sizeValue) {
              if (sizeValue is Map) {
                int quantity = sizeValue['quantity'] ?? 0;
                double sizePrice = sizeValue['price'] ?? defaultPrice;

                stockData[sizeKey] = {
                  'quantity': quantity,
                  'price': sizePrice,
                };
              }
            });
          }

          processedMerchData[key] = {
            'itemLabel': key,
            'imagePath': imagePath ?? '',
            'defaultPrice': defaultPrice,
            'sizes': stockData,
          };
        }
      });

      setState(() {
        _merchStockQuantities = processedMerchData;
      });
    } catch (e) {
    }
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String validator,
    List<TextInputFormatter>? inputFormatters
  }) {
    return TextFormField(
      controller: controller,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return validator;
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                'Walk-In Order Form',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 24),
              _buildTextFormField(
                controller: _nameController,
                label: 'Student Name',
                validator: '',
              ),
              SizedBox(height: 16),
              _buildTextFormField(
                controller: _studentNumberController,
                label: 'Student Number',
                validator: 'Please input numbers only',
                inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),]
              ),
              SizedBox(height: 16),
              _buildTextFormField(
                controller: _contactNumberController,
                label: 'Contact Number',
                validator: 'Please input numbers only',
                inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),]
              ),
              SizedBox(height: 32),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                onChanged: (newCategory) {
                  setState(() {
                    _selectedCategory = newCategory;
                    _selectedSchoolLevel = null;
                    _selectedCourseLabel = null;
                  });
                },
                items: ['Uniform', 'Merch & Accessories'].map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                decoration: InputDecoration(
                  labelText: 'Select Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: 16),
              if (_selectedCategory == 'Uniform')
                Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedSchoolLevel,
                      onChanged: (newValue) {
                        setState(() {
                          _selectedSchoolLevel = newValue;
                          _selectedCourseLabel = null;
                        });
                      },
                      items: _schoolLevels.map((level) {
                        return DropdownMenuItem<String>(
                          value: level,
                          child: Text(level),
                        );
                      }).toList(),
                      decoration: InputDecoration(
                        labelText: 'Select School Level',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    if (_selectedSchoolLevel == 'Senior High') _buildSeniorHighItems(),
                    if (_selectedSchoolLevel == 'College')
                      Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedCourseLabel,
                            onChanged: (newValue) {
                              setState(() {
                                _selectedCourseLabel = newValue;
                              });
                            },
                            items: _courseLabels.map((courseLabel) {
                              return DropdownMenuItem<String>(
                                value: courseLabel,
                                child: Text(courseLabel),
                              );
                            }).toList(),
                            decoration: InputDecoration(
                              labelText: 'Select Course Label',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          if (_selectedCourseLabel != null)
                            _buildCollegeItems(_selectedCourseLabel!),
                        ],
                      ),
                  ],
                ),
              if (_selectedCategory == 'Merch & Accessories')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'MERCH & ACCESSORIES',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    _buildMerchGrid(),
                  ],
                ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitOrder,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text('Submit Order'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeniorHighItems() {
    return Column(
      children: [
        Text(
          'ITEMS IN Senior High',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.5,
          ),
          itemCount: _seniorHighStockQuantities.keys.length,
          itemBuilder: (context, index) {
            String itemKey = _seniorHighStockQuantities.keys.elementAt(index);
            return _buildItemCard(_seniorHighStockQuantities[itemKey]!);
          },
        ),
      ],
    );
  }

  Widget _buildCollegeItems(String courseLabel) {
    return Column(
      children: [
        Text(
          'ITEMS IN $courseLabel',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.5,
          ),
          itemCount: _collegeStockQuantities[courseLabel]?.keys.length ?? 0,
          itemBuilder: (context, index) {
            String itemKey = _collegeStockQuantities[courseLabel]!.keys.elementAt(index);
            return _buildItemCard(_collegeStockQuantities[courseLabel]![itemKey]!);
          },
        ),
      ],
    );
  }

  Widget _buildMerchGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.5,
      ),
      itemCount: _merchStockQuantities.keys.length,
      itemBuilder: (context, index) {
        String item = _merchStockQuantities.keys.elementAt(index);
        return _buildItemCard(_merchStockQuantities[item]!);
      },
    );
  }

  Widget _buildItemCard(Map<String, dynamic>? itemData) {
    // Dynamically determine the label field based on available keys
    String itemLabel = itemData?['label'] ?? itemData?['itemLabel'] ?? 'Unknown';
    double defaultPrice = itemData?['defaultPrice'] ?? 0;
    Map<String, dynamic>? sizes = itemData?['sizes'];

    List<String> availableSizes = sizes != null ? sizes.keys.toList() : [];
    String? selectedSize = _selectedSizes[itemLabel];
    _selectedQuantities[itemLabel] = _selectedQuantities[itemLabel] ?? 0;

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
            itemLabel,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          if (selectedSize != null && sizes != null && sizes.containsKey(selectedSize))
            Text(
              'Price: ₱${sizes[selectedSize]?['price'] ?? defaultPrice}',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            )
          else
            Text(
              'Default Price: ₱$defaultPrice',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          SizedBox(height: 8),

          if (availableSizes.isNotEmpty)
            DropdownButton<String>(
              value: selectedSize,
              hint: Text('Select Size'),
              onChanged: (newSize) {
                setState(() {
                  _selectedSizes[itemLabel] = newSize;
                  _selectedQuantities[itemLabel] = 0;
                });
              },
              items: availableSizes.map((size) {
                int currentQuantity = sizes![size]['quantity'] ?? 0;
                return DropdownMenuItem<String>(
                  value: size,
                  child: Text('$size: $currentQuantity available'),
                );
              }).toList(),
            )
          else
            Text('No sizes available'),

          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.remove),
                onPressed: () {
                  int quantity = _selectedQuantities[itemLabel] ?? 0;
                  if (quantity > 0) {
                    setState(() {
                      _selectedQuantities[itemLabel] = quantity - 1;
                    });
                  }
                },
              ),
              Text(
                '${_selectedQuantities[itemLabel] ?? 0}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(Icons.add),
                onPressed: () {
                  if (selectedSize != null) {
                    int currentQuantity = _selectedQuantities[itemLabel] ?? 0;
                    int availableQuantity = sizes![selectedSize]['quantity'] ?? 0;

                    if (currentQuantity < availableQuantity) {
                      setState(() {
                        _selectedQuantities[itemLabel] = currentQuantity + 1;
                      });
                    } else {
                      Get.snackbar('Quantity Limit', 'Cannot exceed available quantity for $selectedSize.');
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendSMSToUser(String contactNumber, String studentName, String studentNumber, double totalAmount, List<Map<String, dynamic>> cartItems) async {
    try {
      String message = "Hello $studentName (Student ID: $studentNumber), your order has been placed successfully. Total amount: ₱$totalAmount. Items: ";

      for (var item in cartItems) {
        message += "${item['itemLabel']} (x${item['quantity']}), ";
      }
      message = message.trimRight().replaceAll(RegExp(r',\s*$'), '');

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
        print("Failed to send SMS: ${response.body}");
      }
    } catch (e) {
      print("Error sending SMS: $e");
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) {
      print('Form validation failed.');
      return;
    }

    bool hasSelectedItem = _selectedQuantities.values.any((quantity) => quantity > 0);
    if (!hasSelectedItem) {
      print('No items selected.');
      Get.snackbar('Error', 'No items selected. Please add at least one item to the order.');
      return;
    }

    print('Starting order submission...');
    String studentName = _nameController.text;
    String studentNumber = _studentNumberController.text;
    String contactNumber = _contactNumberController.text;

    try {
      List<Map<String, dynamic>> cartItems = [];
      double totalAmount = 0.0;

      for (String item in _selectedQuantities.keys) {
        int quantity = _selectedQuantities[item] ?? 0;
        String? size = _selectedSizes[item];
        if (quantity > 0 && size != null && size != 'None') {
          String category;
          String? courseLabel;

          if (_selectedCategory == 'Uniform') {
            if (_selectedSchoolLevel == 'Senior High') {
              category = 'senior_high_items';
            } else {
              category = 'college_items';
              courseLabel = _selectedCourseLabel;
            }
          } else {
            category = 'Merch & Accessories';
          }

          double itemPrice = await _getItemPrice(category, item, courseLabel, size);
          double total = itemPrice * quantity;

          print('Item: $item, Size: $size, Quantity: $quantity, PricePerPiece: $itemPrice, Total: $total');

          totalAmount += total;

          cartItems.add({
            'label': item,
            'itemSize': size,
            'mainCategory': category,
            'pricePerPiece': itemPrice,
            'quantity': quantity,
            'subCategory': courseLabel ?? 'N/A',
          });
        }
      }

      print('Cart Items: $cartItems');
      print('Total Amount: $totalAmount');

      CollectionReference approvedReservationsRef =
      FirebaseFirestore.instance.collection('approved_reservation');
      await approvedReservationsRef.add({
        'approvalDate': FieldValue.serverTimestamp(),
        'name': studentName,
        'studentNumber': studentNumber,
        'contactNumber': contactNumber,
        'items': cartItems,
      });

      print('Order stored in Firestore.');

      await _sendSMSToUser(contactNumber, studentName, studentNumber, totalAmount, cartItems);

      print('SMS sent successfully.');
      Get.snackbar('Success', 'Order submitted and SMS sent successfully!');
      _refreshData();
    } catch (e) {
      print('Error in _submitOrder: $e');
      Get.snackbar('Error', 'Failed to submit the order. Please try again.');
    }
  }

  Future<double> _getItemPrice(String category, String itemLabel, String? courseLabel, String selectedSize) async {
    double price = 0.0;

    print('Fetching price for: $itemLabel, Category: $category, Size: $selectedSize, CourseLabel: $courseLabel');

    if (category == 'senior_high_items') {
      // Fetch from senior high stock
      final itemData = _seniorHighStockQuantities[itemLabel];
      if (itemData != null) {
        price = itemData['sizes']?[selectedSize]?['price'] ?? itemData['defaultPrice'] ?? 0.0;
      }
      print('Senior High Price: $price');
    } else if (category == 'college_items' && courseLabel != null) {
      // Fetch from college items
      try {
        final courseCollection = FirebaseFirestore.instance
            .collection('Inventory_stock')
            .doc(category)
            .collection(courseLabel);

        // Query the collection for the matching label
        QuerySnapshot querySnapshot = await courseCollection.where('label', isEqualTo: itemLabel).get();

        if (querySnapshot.docs.isNotEmpty) {
          final itemData = querySnapshot.docs.first.data() as Map<String, dynamic>;
          price = itemData['sizes']?[selectedSize]?['price'] ?? itemData['price'] ?? 0.0;
          print('College Price for $itemLabel (Size: $selectedSize): $price');
        } else {
          print('Item not found in college_items for $itemLabel under course $courseLabel');
        }
      } catch (e) {
        print('Error fetching college_items: $e');
      }
    } else if (category == 'Merch & Accessories') {
      // Fetch from merch stock
      final itemData = _merchStockQuantities[itemLabel];
      if (itemData != null) {
        price = itemData['sizes']?[selectedSize]?['price'] ?? itemData['defaultPrice'] ?? 0.0;
      }
      print('Merch Price: $price');
    } else {
      print('Unknown category: $category');
    }

    if (price == 0.0) {
      print('Price not found for item: $itemLabel, Size: $selectedSize');
    }

    return price;
  }

  String _findDocumentIdForItem(String itemLabel) {
    Map<String, String> labelToIdMap = {
      "Blouse with Vest": "SHS_BLOUSE_WITH_VEST",
      "Polo with Vest": "SHS_POLO_WITH_VEST",
      "SHS APRON": "SHS_APRON",
      "SHS NECKTIE": "SHS_NECKTIE",
      "SHS PANTS": "SHS_PANTS",
      "SHS PE PANTS": "SHS_PE_PANTS",
      "SHS PE SHIRT": "SHS_PE_SHIRT",
      "SHS Skirt": "SHS_SKIRT",
      "SHS Washday": "SHS_WASHDAY",
      "STI Checkered Beanie": "STI_CHECKERED_BEANIE",
      "STI Checkered Pants": "STI_LONG_CHECKERED_PANTS",
      "STI Chef's Blouse": "STI_WHITE_CHEF_LONG_SLEEVE_BLOUSE"
    };
    return labelToIdMap[itemLabel] ?? itemLabel;
  }

  void _refreshData() {
    setState(() {
      _selectedSizes.clear();
      _selectedQuantities.clear();
      _loading = true;
    });

    _fetchInventoryData().then((_) {
      setState(() {
        _loading = false;
      });
    });
  }
}