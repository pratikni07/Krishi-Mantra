// crop_controller.dart
import 'package:get/get.dart';
import '../../data/models/crop_model.dart';
import '../../data/models/crop_calendar_model.dart';
import '../../data/repositories/crop_repository.dart';
import '../screens/cropcalendar/crop_detail_screen.dart';

class CropController extends GetxController {
  final CropRepository _cropRepository;

  CropController(this._cropRepository);

  // Observable variables
  RxList<CropModel> crops = <CropModel>[].obs;
  RxList<CropModel> searchResults = <CropModel>[].obs;
  RxBool isLoading = false.obs;
  RxString error = ''.obs;
  Rx<CropModel?> selectedCrop = Rx<CropModel?>(null);

  // New properties for crop calendar
  Rx<CropCalendarModel?> cropCalendar = Rx<CropCalendarModel?>(null);
  RxBool isLoadingCalendar = false.obs;
  RxString calendarError = ''.obs;
  
  // Cache variables 
  bool _hasLoadedCrops = false;
  DateTime _lastFetchTime = DateTime(2000); // Initialize with an old date
  
  @override
  void onInit() {
    super.onInit();
    fetchAllCrops();
  }

  Future<void> fetchAllCrops({bool refresh = false}) async {
    // Check if we need to fetch or can use cached data
    final now = DateTime.now();
    final cacheExpired = now.difference(_lastFetchTime).inMinutes > 30; // Cache for 30 minutes
    
    if (!refresh && _hasLoadedCrops && !cacheExpired && crops.isNotEmpty) {
      // Use cached data
      return;
    }
    
    try {
      isLoading.value = true;
      error.value = '';
      if (refresh) crops.clear(); // Clear existing data for refresh
      
      final result = await _cropRepository.getAllCrops();
      
      if (result.isEmpty) {
        error.value = 'No crops found';
      } else {
        crops.assignAll(result);
        _hasLoadedCrops = true;
        _lastFetchTime = now;
      }
    } catch (e) {
      error.value = e.toString().replaceFirst('Exception: ', '');
      Get.snackbar('Error', error.value, duration: const Duration(seconds: 3)); 
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchCropCalendar(String cropId) async {
    // Find the crop in our list first
    final crop = crops.firstWhereOrNull((crop) => crop.id == cropId);
    if (crop != null) {
      selectedCrop.value = crop;
    }
    
    isLoadingCalendar.value = true;
    calendarError.value = '';
    cropCalendar.value = null;

    try {
      final calendar = await _cropRepository.getCropCalendar(cropId);
      cropCalendar.value = calendar;
      Get.to(() => const CropDetailScreen());
    } catch (e) {
      calendarError.value = e.toString().replaceFirst('Exception: ', '');
      Get.snackbar('Error', calendarError.value, duration: const Duration(seconds: 3));
    } finally {
      isLoadingCalendar.value = false;
    }
  }

  Future<void> searchCrops(String search, String season) async {
    if (search.isEmpty && season.isEmpty) {
      clearSearch();
      return;
    }
    
    try {
      isLoading.value = true;
      error.value = '';
      final result = await _cropRepository.searchCrops(
        search: search,
        season: season,
      );
      
      if (result.isEmpty) {
        error.value = 'No crops found matching your search';
      }
      
      searchResults.assignAll(result);
    } catch (e) {
      error.value = e.toString().replaceFirst('Exception: ', '');
      Get.snackbar('Error', error.value, duration: const Duration(seconds: 3));
    } finally {
      isLoading.value = false;
    }
  }

  void clearSearch() {
    searchResults.clear();
    error.value = '';
  }
  
  // Method to handle retries
  void retryLastOperation() {
    if (searchResults.isNotEmpty) {
      // We were in search mode
      searchCrops('', ''); // Reset search
    } else {
      // We were in normal fetch mode
      fetchAllCrops(refresh: true);
    }
  }
}
