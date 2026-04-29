import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../data/services/mandi_service.dart';
import '../../data/services/LocationService.dart';
import '../../data/services/engagement_service.dart';
import '../../data/msp_data.dart';

class MandiController extends GetxController {
  final MandiService _mandiService = MandiService.getInstance();
  final LocationService _locationService = LocationService();
  final EngagementService _engagement = EngagementService();
  bool _firstLoadEmitted = false;

  final RxList<Map<String, dynamic>> allPrices = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredPrices = <Map<String, dynamic>>[].obs;
  
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;
  
  // Current Filter States
  final RxString selectedState = ''.obs;
  final RxString selectedDistrict = ''.obs;
  final RxString searchQuery = ''.obs;
  final Rx<DateTime> selectedDate = DateTime.now().obs;
  
  final RxList<String> availableStates = <String>[].obs;
  final RxList<String> availableDistricts = <String>[].obs;

  // Pagination support
  final RxInt currentPage = 1.obs;
  static const int itemsPerPage = 20;
  final RxBool hasMore = true.obs;

  @override
  void onInit() {
    super.onInit();
    refreshPrices();
  }

  Future<void> refreshPrices() async {
    isLoading.value = true;
    error.value = '';
    
    try {
      // 1. Try to get user district for default filtering
      if (selectedDistrict.isEmpty) {
        final position = await _locationService.getCurrentPosition();
        if (position != null) {
          // In a real app, we'd reverse geocode here to get district name
          // For now, we'll keep it empty or default to general state list
        }
      }

      // 2. Fetch prices allowing for the selected date
      final prices = await _mandiService.fetchMandiPrices(
        state: selectedState.value,
        district: selectedDistrict.value,
        date: selectedDate.value,
      );

      allPrices.value = prices;

      if (!_firstLoadEmitted) {
        _engagement.trackEvent(
          EventName.mandiListView,
          eventCategory: EventCategory.content,
          properties: {
            'recordCount': prices.length,
            if (selectedState.value.isNotEmpty) 'state': selectedState.value,
            if (selectedDistrict.value.isNotEmpty) 'district': selectedDistrict.value,
          },
        );
        _firstLoadEmitted = true;
      }

      // 3. Update filter options based on available data
      _updateFilterOptions(prices);

      // 4. Initial search application with resetting pagination
      currentPage.value = 1;
      hasMore.value = true;
      applySearch(searchQuery.value, resetPagination: true);
    } catch (e) {
      error.value = 'Failed to load market prices. Please try again.';
      print('MandiController Error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _updateFilterOptions(List<Map<String, dynamic>> prices) {
    final states = prices.map((e) => e['state'].toString()).toSet().toList()..sort();
    availableStates.value = states;

    if (selectedState.isNotEmpty) {
      final districts = prices
          .where((e) => e['state'].toString() == selectedState.value)
          .map((e) => e['district'].toString())
          .toSet()
          .toList()
        ..sort();
      availableDistricts.value = districts;
    } else {
      // If no state is selected, show all unique districts across all states
      final districts = prices
          .map((e) => e['district'].toString())
          .toSet()
          .toList()
        ..sort();
      availableDistricts.value = districts;
    }
  }

  void filterByState(String state) {
    selectedState.value = state;
    selectedDistrict.value = ''; // Reset district when state changes
    refreshPrices();
  }

  void filterByDistrict(String district) {
    selectedDistrict.value = district;
    refreshPrices();
  }

  void applySearch(String query, {bool resetPagination = true}) {
    searchQuery.value = query;
    if (resetPagination) {
      currentPage.value = 1;
      hasMore.value = true;
    }

    final q = query.toLowerCase();
    final results = allPrices.where((item) {
      final commodity = item['commodity'].toString().toLowerCase();
      final market = item['market'].toString().toLowerCase();
      final district = item['district'].toString().toLowerCase();
      final state = item['state'].toString().toLowerCase();

      return commodity.contains(q) ||
             market.contains(q) ||
             district.contains(q) ||
             state.contains(q);
    }).toList();

    // Apply pagination to search results
    final endIndex = currentPage.value * itemsPerPage;
    if (results.isEmpty) {
      filteredPrices.clear();
      hasMore.value = false;
    } else if (endIndex >= results.length) {
      filteredPrices.assignAll(results);
      hasMore.value = false;
    } else {
      filteredPrices.assignAll(results.sublist(0, endIndex));
      hasMore.value = true;
    }

    // Only emit when this is a real user-typed search (skip the initial
    // empty-query call that runs after every refreshPrices()).
    if (resetPagination && query.trim().isNotEmpty) {
      _engagement.trackEvent(
        'search_query',
        eventCategory: EventCategory.content,
        properties: {
          'searchType': 'mandi',
          'searchQuery': query,
          'resultsCount': results.length,
        },
      );
    }
  }

  /// Called from the UI when a user taps a specific mandi-price row to view
  /// details. Captures the "what are you actually checking" signal that the
  /// list-level events miss.
  void trackPriceCheck(Map<String, dynamic> record) {
    _engagement.trackEvent(
      EventName.mandiPriceCheck,
      eventCategory: EventCategory.content,
      properties: {
        'commodity': record['commodity']?.toString(),
        'state': record['state']?.toString(),
        'district': record['district']?.toString(),
        'market': record['market']?.toString(),
      },
    );
  }

  void loadMore() {
    if (!hasMore.value || isLoading.value) return;
    
    currentPage.value++;
    applySearch(searchQuery.value, resetPagination: false);
  }

  void filterByDate(DateTime date) {
    selectedDate.value = date;
    refreshPrices();
  }

  /// Calculates comparison with MSP for a single record
  double getMSPDiff(Map<String, dynamic> record) {
    final commodity = record['commodity'].toString();
    final modalPrice = double.tryParse(record['modal_price'].toString()) ?? 0.0;
    final msp = MSPData.getMSP(commodity);
    
    if (msp > 0 && modalPrice > 0) {
      return modalPrice - msp;
    }
    return 0.0;
  }

  double getMSPForCommodity(String commodity) {
    return MSPData.getMSP(commodity);
  }

  void clearFilters() {
    selectedState.value = '';
    selectedDistrict.value = '';
    searchQuery.value = '';
    selectedDate.value = DateTime.now();
    refreshPrices();
  }
}
