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

  @override
  void onInit() {
    super.onInit();
    fetchAllCrops();
  }

  Future<void> fetchAllCrops({bool refresh = false}) async {
    try {
      isLoading.value = true;
      error.value = '';
      if (refresh) crops.clear(); // Clear existing data for refresh
      final result = await _cropRepository.getAllCrops();
      crops.assignAll(result);
    } catch (e) {
      error.value = e.toString().replaceFirst('Exception: ', '');
      Get.snackbar('Error', error.value); // Show error to user
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchCropCalendar(String cropId) async {
    isLoadingCalendar.value = true;
    calendarError.value = '';
    cropCalendar.value = null;

    try {
      final calendar = await _cropRepository.getCropCalendar(cropId);
      cropCalendar.value = calendar;
      Get.to(() => const CropDetailScreen());
    } catch (e) {
      calendarError.value = e.toString().replaceFirst('Exception: ', '');
      Get.snackbar('Error', calendarError.value);
    } finally {
      isLoadingCalendar.value = false;
    }
  }

  Future<void> searchCrops(String search, String season) async {
    try {
      isLoading.value = true;
      error.value = '';
      final result = await _cropRepository.searchCrops(
        search: search,
        season: season,
      );
      searchResults.assignAll(result);
    } catch (e) {
      error.value = e.toString().replaceFirst('Exception: ', '');
      Get.snackbar('Error', error.value);
    } finally {
      isLoading.value = false;
    }
  }

  void clearSearch() {
    searchResults.clear();
    error.value = '';
  }
}
