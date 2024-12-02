import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:unistock/widgets/custom_text.dart';

class OverviewPage extends StatefulWidget {
  @override
  _OverviewPageState createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  int _totalSales = 0;
  String _latestSale = 'N/A';
  double _totalRevenue = 0.0;

  Map<String, double> _collegeSalesData = {};
  Map<String, double> _seniorHighSalesData = {};
  Map<String, double> _merchSalesData = {};
  Map<String, double> _prowareSalesData = {};

  String _selectedPeriod = 'Overall';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });
    await Future.wait([
      _fetchSalesStatistics(),
      _fetchTotalRevenueAndSales(),
      _fetchLatestSale(),
    ]);
    setState(() {
      _isLoading = false;
    });
  }

    Widget _buildDropdown() {
    return DropdownButton<String>(
      value: _selectedPeriod,
      items:
          <String>['Overall', 'Daily', 'Weekly', 'Monthly'].map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedPeriod = newValue!;
          _isLoading = true;
          _fetchData();
        });
      },
    );
  }


  Future<void> _fetchLatestSale() async {
    try {
      QuerySnapshot adminLatestSnapshot = await _firestore
          .collection('admin_transactions')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      String latestLabel = 'N/A';

      if (adminLatestSnapshot.docs.isNotEmpty) {
        var adminTransaction = adminLatestSnapshot.docs.first.data() as Map<String, dynamic>;
        latestLabel = adminTransaction['label'] ?? 'N/A';

        if (adminTransaction['items'] is List && (adminTransaction['items'] as List).isNotEmpty) {
          latestLabel = adminTransaction['items'][0]['label'] ?? latestLabel;
        }
      }

      setState(() {
        _latestSale = latestLabel;
      });
    } catch (e) {
      print("Error fetching latest sale: $e");
    }
  }

DateTime _getStartDate(String period) {
  DateTime now = DateTime.now();
  if (period == 'Daily') {
    return DateTime(now.year, now.month, now.day);
  } else if (period == 'Weekly') {
    return now.subtract(Duration(days: now.weekday - 1));
  } else if (period == 'Monthly') {
    return DateTime(now.year, now.month, 1);
  } else {
    return DateTime(1970); // Overall
  }
}

Future<void> _fetchSalesStatistics() async {
    try {
      Map<String, double> collegeSales = {};
      Map<String, double> seniorHighSales = {};
      Map<String, double> merchSales = {};
      Map<String, double> prowareSales = {}; // For Proware & PE

      DateTime startDate = _getStartDate(_selectedPeriod);
      Timestamp firestoreStartDate = Timestamp.fromDate(startDate);

      QuerySnapshot adminTransactionsSnapshot;
      if (_selectedPeriod == 'Overall') {
        adminTransactionsSnapshot = await _firestore
            .collection('admin_transactions')
            .orderBy('timestamp')
            .get();
      } else {
        adminTransactionsSnapshot = await _firestore
            .collection('admin_transactions')
            .where('timestamp', isGreaterThanOrEqualTo: firestoreStartDate)
            .orderBy('timestamp')
            .get();
      }

      for (var doc in adminTransactionsSnapshot.docs) {
        var transactionData = doc.data() as Map<String, dynamic>;

        if (transactionData['items'] is List) {
          for (var item in transactionData['items']) {
            String itemLabel = item['label'] ?? 'Unknown';
            double quantity = (item['quantity'] ?? 0).toDouble();
            String category = item['mainCategory'] ?? 'Unknown';

            if (category == 'senior high items' || category == 'senior_high_items') {
              seniorHighSales[itemLabel] = (seniorHighSales[itemLabel] ?? 0) + quantity;
            } else if (category == 'college_items' || category == 'college items') {
              collegeSales[itemLabel] = (collegeSales[itemLabel] ?? 0) + quantity;
            } else if (category == 'Merch & Accessories' || category == 'merch_and_accessories') {
              merchSales[itemLabel] = (merchSales[itemLabel] ?? 0) + quantity;
            } else if (category == 'Proware & PE' || category == 'proware_and_pe') { // Handle Proware & PE
              prowareSales[itemLabel] = (prowareSales[itemLabel] ?? 0) + quantity;
            }
          }
        }
      }

      setState(() {
        _collegeSalesData = collegeSales;
        _seniorHighSalesData = seniorHighSales;
        _merchSalesData = merchSales;
        _prowareSalesData = prowareSales; // Save the data for Proware & PE
      });
    } catch (e) {
      print("Error fetching sales statistics: $e");
    }
  }

Future<void> _fetchTotalRevenueAndSales() async {
  try {
    double totalRevenue = 0.0;
    int totalSales = 0;

    DateTime startDate = _getStartDate(_selectedPeriod);
    Timestamp firestoreStartDate = Timestamp.fromDate(startDate);

    QuerySnapshot adminTransactionsSnapshot;
    if (_selectedPeriod == 'Overall') {
      adminTransactionsSnapshot = await _firestore.collection('admin_transactions').get();
    } else {
      adminTransactionsSnapshot = await _firestore
          .collection('admin_transactions')
          .where('timestamp', isGreaterThanOrEqualTo: firestoreStartDate)
          .get();
    }

    for (var doc in adminTransactionsSnapshot.docs) {
      var transactionData = doc.data() as Map<String, dynamic>;

      totalRevenue += transactionData['totalTransactionPrice'] ?? 0.0;
      totalSales += (transactionData['totalQuantity'] ?? 0) as int;
    }

    setState(() {
      _totalRevenue = totalRevenue;
      _totalSales = totalSales;
    });
  } catch (e) {
    print("Error fetching total revenue and sales: $e");
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Overview"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _fetchData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CustomText(text: "Sales Overview", size: 24, weight: FontWeight.bold),
            SizedBox(height: 20),
            Row(
              children: [
                CustomText(text: "Select Sales Period: "),
                _buildDropdown(),
              ],
            ),
            SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3, // Number of columns
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2, // Adjust the aspect ratio for the card dimensions
              physics: NeverScrollableScrollPhysics(), // Prevents nested scrolling
              children: [
                _buildOverviewCard(Icons.payments, 'Total Revenue', '₱${_totalRevenue.toStringAsFixed(2)}'),
                _buildOverviewCard(Icons.shopping_cart, 'Total Sales', '$_totalSales'),
                _buildOverviewCard(Icons.new_releases, 'Latest Sale', '$_latestSale'),
              ],
            ),
            SizedBox(height: 30),
            Center(
              child: CustomText(text: "Sales Statistics", size: 24, weight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Center(
              child: Column(
                children: [
                  CustomText(text: "College Sales", size: 20, weight: FontWeight.bold),
                  _buildMiniChartWithLegend(_collegeSalesData),
                ],
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  CustomText(text: "Senior High Sales", size: 20, weight: FontWeight.bold),
                  _buildMiniChartWithLegend(_seniorHighSalesData),
                ],
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  CustomText(text: "Merch & Accessories Sales", size: 20, weight: FontWeight.bold),
                  _buildMiniChartWithLegend(_merchSalesData),
                ],
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  CustomText(text: "Proware & PE Sales", size: 20, weight: FontWeight.bold), // New Section
                  _buildMiniChartWithLegend(_prowareSalesData), // Use Proware Data
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(IconData icon, String title, String value) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.blueAccent),
            SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChartWithLegend(Map<String, double> salesData) {
    if (salesData.isEmpty) {
      return Center(child: Text("No sales data available"));
    }

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            flex: 2, // Adjust the flex value if needed
            child: SizedBox(
              height: 350,
              child: PieChart(
                PieChartData(
                  sections: salesData.entries.map((entry) {
                    return PieChartSectionData(
                      color: _getDistinctColor(entry.key),
                      value: entry.value,
                      title: '${entry.value.toInt()}',
                      radius: 100,
                    );
                  }).toList(),
                  centerSpaceRadius: 35,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ),
          SizedBox(width: 20),
          Flexible(
            flex: 1, // Adjust the flex value to balance the layout
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: salesData.entries.map((entry) {
                return Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      color: _getDistinctColor(entry.key),
                    ),
                    SizedBox(width: 8),
                    Text(entry.key, overflow: TextOverflow.ellipsis),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDistinctColor(String label) {
    final colors = <Color>[
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.yellow,
      Colors.brown,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
      Colors.cyan,
    ];
    return colors[label.hashCode % colors.length];
  }
}
