import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SalesStatisticsPage extends StatefulWidget {
  @override
  _SalesStatisticsPageState createState() => _SalesStatisticsPageState();
}

class _SalesStatisticsPageState extends State<SalesStatisticsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  Map<String, double> _collegeSalesData = {};
  Map<String, double> _seniorHighSalesData = {};
  Map<String, double> _merchSalesData = {};
  String _selectedPeriod = 'Overall';

  @override
  void initState() {
    super.initState();
    _fetchSalesData();
  }

  Widget _buildDropdown() {
    return DropdownButton<String>(
      value: _selectedPeriod,
      items: <String>['Overall', 'Daily', 'Weekly', 'Monthly'].map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedPeriod = newValue!;
          _isLoading = true;
          _fetchSalesData();
        });
      },
    );
  }

  Future<void> _fetchSalesData() async {
    try {
      Map<String, double> collegeSales = {};
      Map<String, double> seniorHighSales = {};
      Map<String, double> merchSales = {};

      DateTime now = DateTime.now();
      DateTime startDate;

      // Adjust start date based on the selected period
      if (_selectedPeriod == 'Daily') {
        startDate = DateTime(now.year, now.month, now.day); // Start of today
      } else if (_selectedPeriod == 'Weekly') {
        startDate = now.subtract(
            Duration(days: now.weekday)); // Start of the week (Monday)
      } else if (_selectedPeriod == 'Monthly') {
        startDate =
            DateTime(now.year, now.month - 1, 1); // Start of the previous month
      } else {
        startDate = DateTime(1970); // 'Overall' - includes all data
      }

      Timestamp firestoreStartDate = Timestamp.fromDate(startDate);

      QuerySnapshot adminTransactionsSnapshot;
      if (_selectedPeriod == 'Overall') {
        // Get all data without filtering by date, just order by timestamp
        adminTransactionsSnapshot = await _firestore
            .collection('admin_transactions')
            .orderBy('timestamp')
            .get(); // Force a fresh fetch, not using cached data
      } else {
        // Filter by date range using the startDate and force fresh data fetch
        adminTransactionsSnapshot = await _firestore
            .collection('admin_transactions')
            .where('timestamp', isGreaterThanOrEqualTo: firestoreStartDate)
            .orderBy('timestamp')
            .get(); // Force a fresh fetch, not using cached data
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
            } else if (category == 'college_items' || category == 'senior_high_items') {
              collegeSales[itemLabel] = (collegeSales[itemLabel] ?? 0) + quantity;
            } else if (category == 'Merch & Accessories' || category == 'merch_and_accessories') {
              merchSales[itemLabel] = (merchSales[itemLabel] ?? 0) + quantity;
            }
          }
        }
      }

      setState(() {
        _collegeSalesData = collegeSales;
        _seniorHighSalesData = seniorHighSales;
        _merchSalesData = merchSales;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching sales data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sales Statistics'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _fetchSalesData();
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Select Sales Period:"),
              _buildDropdown(),
              SizedBox(height: 20),
              Text(
                "College Item Sales Distribution (${_selectedPeriod})",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 20),
              _buildPieChart(_collegeSalesData),
              SizedBox(height: 50),
              Divider(thickness: 2),
              SizedBox(height: 50),
              Text(
                "Senior High Item Sales Distribution (${_selectedPeriod})",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 20),
              _buildPieChart(_seniorHighSalesData),
              SizedBox(height: 50),
              Divider(thickness: 2),
              SizedBox(height: 50),
              Text(
                "Merch & Accessories Sales Distribution (${_selectedPeriod})",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 20),
              _buildPieChart(_merchSalesData),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(Map<String, double> salesData) {
    return Center(
      child: salesData.isEmpty
          ? Text("No data available for this section")
          : Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            flex: 2,
            child: SizedBox(
              height: 300,
              child: PieChart(
                PieChartData(
                  sections: salesData.entries.map((entry) {
                    return PieChartSectionData(
                      color: _getDistinctColor(entry.key),
                      value: entry.value,
                      title: '${entry.value.toInt()}',
                      titleStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      radius: 100,
                    );
                  }).toList(),
                  centerSpaceRadius: 50,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ),
          SizedBox(width: 20),
          Flexible(
            flex: 1,
            child: _buildLegend(salesData),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Map<String, double> salesData) {
    return Column(
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
            Expanded(
              child: Text(
                entry.key,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      }).toList(),
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
    ];
    return colors[label.hashCode % colors.length];
  }
}
