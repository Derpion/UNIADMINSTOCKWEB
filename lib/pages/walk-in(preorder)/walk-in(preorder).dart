import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WalkinPagePreOrder extends StatefulWidget {
  @override
  _MainWalkInPreOrderPageState createState() => _MainWalkInPreOrderPageState();
}

class _MainWalkInPreOrderPageState extends State<WalkinPagePreOrder> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _studentNumberController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final Map<String, String?> _selectedSizes = {};
  final Map<String, int> _selectedQuantities = {};
  String? _selectedCategory;
  String? _selectedSchoolLevel;
  String? _selectedCourseLabel;
  String? _selectedSubcategory;

  Map<String, Map<String, dynamic>> _seniorHighStockQuantities = {};
  Map<String, Map<String, dynamic>> _collegeStockQuantities = {};
  Map<String, Map<String, dynamic>> _merchStockQuantities = {};
  Map<String, Map<String, dynamic>> _prowareStockQuantities = {};

  List<String> _prowareSubcategories = ['NSTP', 'PE', 'Proware'];
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

            // Only add sizes with zero quantity (out of stock)
            if (quantity == 0) {
              stockData[sizeKey] = {
                'quantity': quantity,
                'price': sizePrice,
              };
            }
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

              // Only add sizes with zero quantity (out of stock)
              if (quantity == 0) {
                stockData[sizeKey] = {
                  'quantity': quantity,
                  'price': sizePrice,
                };
              }
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

              // Only add sizes with zero quantity (out of stock)
              if (quantity == 0) {
                stockData[sizeKey] = {
                  'quantity': quantity,
                  'price': sizePrice,
                };
              }
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

  Future<void> _fetchProwareStock() async {
    try {
      List<String> subcategories = ['NSTP', 'PE', 'Proware'];
      Map<String, Map<String, Map<String, dynamic>>> prowareData = {};

      for (String subcategory in subcategories) {
        QuerySnapshot subcategorySnapshot = await FirebaseFirestore.instance
            .collection('Inventory_stock')
            .doc('Proware & PE')
            .collection(subcategory)
            .get();

        Map<String, Map<String, dynamic>> subcategoryItems = {};

        subcategorySnapshot.docs.forEach((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

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

                // Only add sizes with zero quantity (out of stock)
              if (quantity == 0) {
                stockData[sizeKey] = {
                  'quantity': quantity,
                  'price': sizePrice,
                };
              }
            }
          });
        }

          subcategoryItems[doc.id] = {
            'label': label,
            'imagePath': data['imagePath'] ?? '',
            'defaultPrice': defaultPrice,
            'sizes': stockData,
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
                  LengthLimitingTextInputFormatter(11),
                ],
              ),
              SizedBox(height: 16),
              _buildTextFormField(
                controller: _contactNumberController,
                label: 'Contact Number',
                validator: 'Please input numbers only',
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
              ),
              SizedBox(height: 32),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                onChanged: (newCategory) {
                  setState(() {
                    _selectedCategory = newCategory;
                    _selectedSchoolLevel = null;
                    _selectedCourseLabel = null;
                    _selectedSubcategory = null;
                  });
                },
                items: ['Uniform', 'Merch & Accessories', 'Proware & PE'].map((category) {
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
              if (_selectedCategory == 'Proware & PE')
                Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedSubcategory,
                      onChanged: (newSubcategory) {
                        setState(() {
                          _selectedSubcategory = newSubcategory;
                        });
                      },
                      items: _prowareSubcategories.map((subcategory) {
                        return DropdownMenuItem<String>(
                          value: subcategory,
                          child: Text(subcategory),
                        );
                      }).toList(),
                      decoration: InputDecoration(
                        labelText: 'Select Subcategory',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    if (_selectedSubcategory != null)
                      _buildProwareItems(_selectedSubcategory!),
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

  Widget _buildProwareItems(String subcategory) {
    final items = _prowareStockQuantities[subcategory] ?? {};

    return Column(
      children: [
        Text(
          'ITEMS IN $subcategory',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        if (items.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.5,
            ),
            itemCount: items.keys.length,
            itemBuilder: (context, index) {
              String itemKey = items.keys.elementAt(index);
              return _buildItemCard(items[itemKey]);
            },
          )
        else
          Text(
            'No items available in $subcategory',
            style: TextStyle(fontStyle: FontStyle.italic),
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
                  child: Text('$size: (Pre-Order)'),
                );
              }).toList(),
            )
          else
            Text('All sizes are available'),

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

                  // Allow pre-order even if the item is out of stock
                  if (currentQuantity < 100) { // You can adjust the max limit (e.g., 100 pre-orders allowed)
                    setState(() {
                      _selectedQuantities[itemLabel] = currentQuantity + 1;
                    });
                  } else {
                    Get.snackbar('Pre-order Limit', 'Cannot pre-order more than 100 units.');
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

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    bool hasSelectedItem = _selectedQuantities.values.any((quantity) => quantity > 0);
    if (!hasSelectedItem) {
      Get.snackbar('Error', 'No items selected. Please add at least one item to the order.');
      return;
    }
    String studentName = _nameController.text.trim();
    String studentNumber = _studentNumberController.text.trim();
    String contactNumber = _contactNumberController.text.trim();

    try {
      QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isEqualTo: studentName)
          .where('studentId', isEqualTo: studentNumber)
          .get();

      if (userSnapshot.docs.isEmpty) {
        throw Exception('User with the provided name and student ID not found.');
      }

      String userId = userSnapshot.docs.first.id;

      List<Map<String, dynamic>> cartItems = [];

      for (String item in _selectedQuantities.keys) {
        int quantity = _selectedQuantities[item] ?? 0;
        String? size = _selectedSizes[item];
        String category = '';
        String? courseLabel;

        if (quantity > 0 && size != null && size != 'None') {
          if (_selectedCategory == 'Uniform') {
            if (_selectedSchoolLevel == 'Senior High') {
              category = 'senior_high_items';
            } else {
              category = 'college_items';
              courseLabel = _selectedCourseLabel;
            }
          } else if (_selectedCategory == 'Merch & Accessories') {
            category = 'merch_and_accessories';
          } else if (_selectedCategory == 'Proware & PE') {
            category = 'proware_and_pe';
            courseLabel = _selectedSubcategory;
          }

          cartItems.add({
            'label': item,
            'itemSize': size,
            'quantity': quantity,
            'category': category,
            'courseLabel': courseLabel ?? 'N/A',
          });
        }
      }

      Map<String, dynamic> preOrderData = {
        'items': cartItems,
        'contactNumber': contactNumber,
        'preOrderDate': Timestamp.now(),
        'status': 'pre-order confirmed',
        'studentId': studentNumber,
        'userName': studentName,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('preorders')
          .add(preOrderData);

      Get.snackbar('Success', 'Order submitted and saved successfully!');
      _refreshData();
    } catch (e) {
      Get.snackbar('Error', 'Failed to submit the order. Please try again.');
    }
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