import 'package:get/get.dart';

import '../../data/models/company_model.dart';
import '../../data/repositories/company_repository.dart';
import '../../data/services/engagement_service.dart';

class CompanyController extends GetxController {
  final CompanyRepository _repository;
  final EngagementService _engagement = EngagementService();

  CompanyController(this._repository);

  final companies = <CompanyModel>[].obs;
  final selectedCompany = Rx<CompanyModel?>(null);
  final isLoading = false.obs;
  final error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAllCompanies();
  }

  Future<void> fetchAllCompanies({bool refresh = false}) async {
    if (refresh) {
      isLoading.value = true;
      error.value = '';
    }
    
    try {
      final result = await _repository.getAllCompanies();
      companies.value = result;
      error.value = '';
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchCompanyDetails(String id) async {
    isLoading.value = true;
    error.value = '';

    try {
      final result = await _repository.getCompanyById(id);
      selectedCompany.value = result;
      error.value = '';
      _engagement.trackEvent(
        'company_view',
        eventCategory: EventCategory.content,
        properties: {
          'contentId': id,
          'contentType': 'company',
        },
      );
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void trackContact(String companyId, {String? channel}) {
    _engagement.trackEvent(
      'company_contact',
      eventCategory: EventCategory.communication,
      properties: {
        'contentId': companyId,
        'contentType': 'company',
        if (channel != null) 'channel': channel,
      },
    );
  }
}
