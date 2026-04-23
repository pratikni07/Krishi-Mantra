// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/home_localizations.dart';
import '../../../core/utils/translation_manager.dart';
import '../../../data/services/language_service.dart';
import '../../controllers/mandi_controller.dart';
import 'package:intl/intl.dart';
import 'mandi_product_detail_screen.dart';

class MandiPriceScreen extends StatefulWidget {
  const MandiPriceScreen({super.key});

  @override
  State<MandiPriceScreen> createState() => _MandiPriceScreenState();
}

class _MandiPriceScreenState extends State<MandiPriceScreen> {
  final MandiController _controller = Get.put(MandiController());
  String _languageCode = '';

  @override
  void initState() {
    super.initState();
    _syncLanguageCode();
    TranslationManager.instance.addLanguageChangeListener(_onLanguageChanged);
  }

  Future<void> _syncLanguageCode() async {
    final ls = await LanguageService.getInstance();
    if (!mounted) return;
    setState(() => _languageCode = ls.getLanguageCode());
  }

  Future<void> _onLanguageChanged() async => _syncLanguageCode();

  String _t(String key) {
    if (_languageCode.isEmpty) return '';
    return HomeLocalizations.text(key, _languageCode);
  }

  @override
  void dispose() {
    TranslationManager.instance
        .removeLanguageChangeListener(_onLanguageChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F5),
      appBar: AppBar(
        title: Text(
          _t('mandi_title'), // Mandi Prices
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.refreshPrices(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search & Filter Section ────────────────────────
          _buildFilterSection(),

          // ── Commodity List ─────────────────────────────────
          Expanded(
            child: Obx(() {
              if (_controller.isLoading.value) {
                return _buildLoadingState();
              }
              if (_controller.error.value.isNotEmpty) {
                return _buildErrorState();
              }
              if (_controller.filteredPrices.isEmpty) {
                return _buildEmptyState();
              }
              return Column(
                children: [
                   // Coverage Summary Badge
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.green.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user, color: AppColors.green, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '${_t('mandi_covering')} 3,200+ ${_t('mandi_markets_nationwide')}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.green,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_controller.allPrices.length} Records',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.green.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildPriceList()),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Search Bar
          TextField(
            onChanged: (val) => _controller.applySearch(val),
            decoration: InputDecoration(
              hintText: _t('mandi_search_hint'), // Search commodity or market
              prefixIcon: const Icon(Icons.search, color: AppColors.green),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 12),
          
          // Date Filter Strip
          _buildDateFilter(),
          const SizedBox(height: 12),

          // State & District Filters
          Row(
            children: [
              Expanded(
                child: Obx(() => _dropDownFilter(
                  label: _t('mandi_state'), 
                  value: _controller.selectedState.value.isEmpty ? null : _controller.selectedState.value,
                  items: _controller.availableStates,
                  allLabel: _t('mandi_all_states'),
                  onChanged: (val) => _controller.filterByState(val ?? ''),
                )),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(() => _dropDownFilter(
                  label: _t('mandi_district'),
                  value: _controller.selectedDistrict.value.isEmpty ? null : _controller.selectedDistrict.value,
                  items: _controller.availableDistricts,
                  allLabel: _t('mandi_all_districts'),
                  onChanged: (val) => _controller.filterByDistrict(val ?? ''),
                )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7, // Last 7 days
        itemBuilder: (context, index) {
          final date = DateTime.now().subtract(Duration(days: index));
          return Obx(() {
            final isSelected = _controller.selectedDate.value.year == date.year &&
                               _controller.selectedDate.value.month == date.month &&
                               _controller.selectedDate.value.day == date.day;
            
            String label;
            if (index == 0) {
              label = _languageCode == 'en' ? 'Today' : 'Today'; // Minimal generic label
            } else if (index == 1) {
              label = _languageCode == 'en' ? 'Yesterday' : 'Yesterday';
            } else {
              label = DateFormat('dd MMM').format(date);
            }

            return GestureDetector(
              onTap: () => _controller.filterByDate(date),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.green : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.green : Colors.grey[300]!,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textDark,
                  ),
                ),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _dropDownFilter({
    required String label,
    required String? value,
    required List<String> items,
    required String allLabel,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Text(label, style: const TextStyle(fontSize: 13)),
          items: [
            DropdownMenuItem<String>(
              value: '',
              child: Text(allLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.green)),
            ),
            ...items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildPriceList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _controller.loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: _controller.filteredPrices.length + (_controller.hasMore.value ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _controller.filteredPrices.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green)),
            );
          }
          final record = _controller.filteredPrices[index];
          return _priceCard(record);
        },
      ),
    );
  }

  Widget _priceCard(Map<String, dynamic> record) {
    final commodity = record['commodity']?.toString() ?? 'Unknown';
    final market = record['market']?.toString() ?? 'Unknown';
    final district = record['district']?.toString() ?? '';
    final state = record['state']?.toString() ?? '';
    
    final modalPrice = record['modal_price']?.toString() ?? '0';
    final minPrice = record['min_price']?.toString() ?? '0';
    final maxPrice = record['max_price']?.toString() ?? '0';
    final unit = record['unit']?.toString() ?? 'Quintal';
    
    final variety = record['variety']?.toString() ?? '';
    final grade = record['grade']?.toString() ?? '';
    
    final double msp = _controller.getMSPForCommodity(commodity);
    final double diff = _controller.getMSPDiff(record);
    
    // Status color logic (comparison with MSP)
    final bool hasMSP = msp > 0;
    final Color statusColor = !hasMSP
        ? Colors.grey[600]!
        : (diff >= 0 ? Colors.green[700]! : Colors.red[700]!);

    return GestureDetector(
      onTap: () {
        Get.to(() => MandiProductDetailScreen(record: record));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Header Section ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.green.withOpacity(0.1),
                  child: const Icon(Icons.shopping_basket, color: AppColors.green, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        commodity,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        '$market, $district, $state',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight.withOpacity(0.6),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        record['arrival_date'].toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Main Price Highlight ────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.03),
              border: Border.symmetric(horizontal: BorderSide(color: Colors.grey[100]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('mandi_market_price').toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textLight.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹$modalPrice',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '/ $unit',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textLight.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (hasMSP)
                  _mspComparisonBadge(diff, statusColor),
              ],
            ),
          ),

          // ── Bottom Details Section ──────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _detailInfo(_t('mandi_range'), '₹$minPrice - ₹$maxPrice'),
                    if (variety.isNotEmpty)
                      _detailInfo(_t('mandi_variety'), variety),
                    if (grade.isNotEmpty)
                      _detailInfo(_t('mandi_grade'), grade),
                    if (hasMSP)
                      _detailInfo('Govt MSP', '₹${msp.toStringAsFixed(0)}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _mspComparisonBadge(double diff, Color color) {
    final bool isAbove = diff >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(
            isAbove ? Icons.trending_up : Icons.trending_down,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 2),
          Text(
            isAbove ? '+₹${diff.toStringAsFixed(0)}' : '-₹${diff.abs().toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            isAbove ? _t('mandi_above_msp') : _t('mandi_below_msp'),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppColors.textLight.withOpacity(0.5)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.bold,
            color: AppColors.textDark
          ),
        ),
      ],
    );
  }

  Widget _priceInfo(String label, String value, Color color, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.textLight.withOpacity(0.6)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.green),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_controller.error.value),
          TextButton(
            onPressed: () => _controller.refreshPrices(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(_t('mandi_no_results')),
          TextButton(
            onPressed: () => _controller.clearFilters(),
            child: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }
}
