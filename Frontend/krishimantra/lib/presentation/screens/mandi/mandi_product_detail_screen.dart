import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/colors.dart';
import '../../../data/services/mandi_service.dart';
import '../../controllers/mandi_controller.dart';
import 'package:intl/intl.dart';

class MandiProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> record;

  const MandiProductDetailScreen({super.key, required this.record});

  @override
  State<MandiProductDetailScreen> createState() => _MandiProductDetailScreenState();
}

class _MandiProductDetailScreenState extends State<MandiProductDetailScreen> {
  final MandiService _mandiService = MandiService.getInstance();
  final MandiController _mandiController = Get.find<MandiController>();
  
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _mandiService.getHistoricalData(widget.record, days: 7);
      setState(() {
        _historyData = history;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading history: $e');
      setState(() => _isLoading = false);
    }
  }

  double _parsePrice(dynamic val) {
    return double.tryParse(val?.toString() ?? '0') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final commodity = widget.record['commodity']?.toString() ?? 'Unknown';
    final market = widget.record['market']?.toString() ?? 'Unknown';
    final district = widget.record['district']?.toString() ?? '';
    final state = widget.record['state']?.toString() ?? '';
    final unit = widget.record['unit']?.toString() ?? 'Quintal';
    final modalPrice = widget.record['modal_price']?.toString() ?? '0';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F5),
      appBar: AppBar(
        title: Text(commodity, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '$market, $district',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
                  ),
                  Text(
                    state,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '₹$modalPrice',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'per $unit',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  _buildMSPBadge(),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Graph Section
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: AppColors.green))
            else if (_historyData.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.show_chart, color: AppColors.green),
                    const SizedBox(width: 8),
                    const Text(
                      'Price Trend (Last 7 Days)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildGraph(),
              
              const SizedBox(height: 24),
              
              // History List Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: AppColors.green),
                    const SizedBox(width: 8),
                    const Text(
                      'Historical Data',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildHistoryList(),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMSPBadge() {
    final diff = _mandiController.getMSPDiff(widget.record);
    final msp = _mandiController.getMSPForCommodity(widget.record['commodity'].toString());
    
    if (msp <= 0) return const SizedBox.shrink();

    final isAbove = diff >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isAbove ? Icons.trending_up : Icons.trending_down, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            'MSP: ₹${msp.toStringAsFixed(0)} (${isAbove ? '+' : ''}${diff.toStringAsFixed(0)})',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildGraph() {
    List<FlSpot> spots = [];
    double minPrice = double.infinity;
    double maxPrice = 0;

    for (int i = 0; i < _historyData.length; i++) {
      final price = _parsePrice(_historyData[i]['modal_price']);
      spots.add(FlSpot(i.toDouble(), price));
      if (price < minPrice) minPrice = price;
      if (price > maxPrice) maxPrice = price;
    }

    // Add some padding to Y axis
    final yPadding = (maxPrice - minPrice) * 0.2;
    if (yPadding == 0) {
      minPrice -= 100;
      maxPrice += 100;
    } else {
      minPrice -= yPadding;
      maxPrice += yPadding;
    }

    return Container(
      height: 250,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.only(right: 20, top: 20, bottom: 10, left: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxPrice - minPrice) / 4 > 0 ? (maxPrice - minPrice) / 4 : 100,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[200],
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < 0 || value.toInt() >= _historyData.length) {
                    return const SizedBox.shrink();
                  }
                  // Show only 3-4 dates to avoid clutter
                  if (value.toInt() % 2 != 0 && _historyData.length > 5) return const SizedBox.shrink();
                  
                  final dateStr = _historyData[value.toInt()]['arrival_date'].toString();
                  final parts = dateStr.split('/');
                  String shortDate = dateStr;
                  if (parts.length >= 2) {
                    shortDate = '${parts[0]}/${parts[1]}';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      shortDate,
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (maxPrice - minPrice) / 4 > 0 ? (maxPrice - minPrice) / 4 : 100,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  // Format as k if > 1000
                  String text;
                  if (value >= 1000) {
                    text = '${(value / 1000).toStringAsFixed(1)}k';
                  } else {
                    text = value.toInt().toString();
                  }
                  return Text(
                    text,
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    textAlign: TextAlign.right,
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (_historyData.length - 1).toDouble(),
          minY: minPrice < 0 ? 0 : minPrice,
          maxY: maxPrice,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.green,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: AppColors.green,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.green.withOpacity(0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    // Reverse the list again so newest dates are at the top of the list view
    final displayList = _historyData.reversed.toList();
    
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: displayList.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final item = displayList[index];
        final date = item['arrival_date']?.toString() ?? '';
        final modal = item['modal_price']?.toString() ?? '0';
        final min = item['min_price']?.toString() ?? '0';
        final max = item['max_price']?.toString() ?? '0';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Range: ₹$min - ₹$max',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              Text(
                '₹$modal',
                style: const TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
