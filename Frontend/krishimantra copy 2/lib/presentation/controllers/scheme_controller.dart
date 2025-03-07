import 'package:get/get.dart';
import '../../data/models/scheme_model.dart';
import '../../data/repositories/scheme_repository.dart';

class SchemeController extends GetxController {
  final SchemeRepository _schemeRepository;

  SchemeController(this._schemeRepository);

  // Observable variables
  RxList<SchemeModel> schemes = <SchemeModel>[].obs;
  RxBool isLoading = false.obs;
  RxString error = ''.obs;
  Rx<SchemeModel?> selectedScheme = Rx<SchemeModel?>(null);

  @override
  void onInit() {
    super.onInit();
    fetchAllSchemes();
  }

  Future<void> fetchAllSchemes({bool refresh = false}) async {
    try {
      isLoading.value = true;
      error.value = '';
      if (refresh) schemes.clear();
      
      final result = await _schemeRepository.getAllSchemes();
      schemes.assignAll(result);
    } catch (e) {
      error.value = e.toString().replaceFirst('Exception: ', '');
      Get.snackbar('Error', error.value);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchSchemeById(String id) async {
    try {
      isLoading.value = true;
      error.value = '';
      
      final scheme = await _schemeRepository.getSchemeById(id);
      selectedScheme.value = scheme;
    } catch (e) {
      error.value = e.toString().replaceFirst('Exception: ', '');
      Get.snackbar('Error', error.value);
    } finally {
      isLoading.value = false;
    }
  }
}