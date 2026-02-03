import 'package:get/get.dart';
import '../../data/models/scheme_model.dart';
import '../../data/repositories/scheme_repository.dart';
import '../../data/services/language_service.dart';
import '../../data/services/engagement_service.dart';

class SchemeController extends GetxController {
  final SchemeRepository _schemeRepository;
  final EngagementService _engagementService = EngagementService();

  SchemeController(this._schemeRepository);

  // Observable variables
  RxList<SchemeModel> schemes = <SchemeModel>[].obs;
  RxList<SchemeModel> translatedSchemes = <SchemeModel>[].obs;
  RxBool isLoading = false.obs;
  RxBool isTranslating = false.obs;
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
      if (refresh) {
        schemes.clear();
        translatedSchemes.clear();
      }

      final result = await _schemeRepository.getAllSchemes();
      schemes.assignAll(result);

      // Translate schemes after fetching
      await _translateSchemes();
    } catch (e) {
      error.value = e.toString().replaceFirst('Exception: ', '');
      Get.snackbar('Error', error.value);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _translateSchemes() async {
    try {
      isTranslating.value = true;
      final languageService = await LanguageService.getInstance();

      // If English, no translation needed
      if (languageService.getLanguage() == 'English') {
        translatedSchemes.assignAll(schemes);
        return;
      }

      final List<SchemeModel> translated = [];

      for (final scheme in schemes) {
        final translatedScheme = await _translateScheme(scheme, languageService);
        translated.add(translatedScheme);
      }

      translatedSchemes.assignAll(translated);
    } catch (e) {
      // If translation fails, use original schemes
      translatedSchemes.assignAll(schemes);
      print('[SchemeController] Translation error: $e');
    } finally {
      isTranslating.value = false;
    }
  }

  Future<SchemeModel> _translateScheme(SchemeModel scheme, LanguageService languageService) async {
    try {
      // Translate main fields
      final translatedTitle = await languageService.translate(scheme.title);
      final translatedCategory = await languageService.translate(scheme.category);
      final translatedDescription = await languageService.translate(scheme.description);
      final translatedStatus = await languageService.translate(scheme.status);

      // Translate lists
      final translatedEligibility = await Future.wait(
        scheme.eligibility.map((e) => languageService.translate(e))
      );
      final translatedBenefits = await Future.wait(
        scheme.benefits.map((b) => languageService.translate(b))
      );
      final translatedDocuments = await Future.wait(
        scheme.documentRequired.map((d) => languageService.translate(d))
      );

      return SchemeModel(
        id: scheme.id,
        title: translatedTitle,
        category: translatedCategory,
        description: translatedDescription,
        eligibility: translatedEligibility,
        benefits: translatedBenefits,
        lastDate: scheme.lastDate, // Keep date as-is
        status: translatedStatus,
        applicationUrl: scheme.applicationUrl, // Keep URL as-is
        documentRequired: translatedDocuments,
      );
    } catch (e) {
      // Return original scheme if translation fails
      return scheme;
    }
  }

  Future<void> fetchSchemeById(String id) async {
    try {
      isLoading.value = true;
      error.value = '';

      final scheme = await _schemeRepository.getSchemeById(id);

      if (scheme == null) {
        error.value = 'Scheme not found';
        return;
      }

      // Track scheme view engagement
      _engagementService.trackSchemeView(id);

      // Translate the selected scheme
      final languageService = await LanguageService.getInstance();
      if (languageService.getLanguage() != 'English') {
        selectedScheme.value = await _translateScheme(scheme, languageService);
      } else {
        selectedScheme.value = scheme;
      }
    } catch (e) {
      error.value = e.toString().replaceFirst('Exception: ', '');
      Get.snackbar('Error', error.value);
    } finally {
      isLoading.value = false;
    }
  }

  /// Get schemes list - returns translated if available, otherwise original
  List<SchemeModel> get displaySchemes {
    return translatedSchemes.isNotEmpty ? translatedSchemes : schemes;
  }
}