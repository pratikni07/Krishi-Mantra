import 'package:get/get.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/services/engagement_service.dart';

class ProductController extends GetxController {
  final ProductRepository _productRepository;
  final EngagementService _engagementService = EngagementService();

  ProductController(this._productRepository);

  RxList<ProductModel> products = <ProductModel>[].obs;
  RxBool isLoading = false.obs;
  RxString error = ''.obs;
  Rx<ProductModel?> selectedProduct = Rx<ProductModel?>(null);

  @override
  void onInit() {
    super.onInit();
    fetchAllProducts();
  }

  Future<void> fetchAllProducts() async {
    try {
      isLoading.value = true;
      error.value = '';
      final result = await _productRepository.getAllProducts();
      products.assignAll(result);
    } catch (e) {
      error.value = e.toString().replaceFirst('Exception: ', '');
      Get.snackbar('Error', error.value);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchProductById(String id) async {
    try {
      isLoading.value = true;
      error.value = '';
      final product = await _productRepository.getProductById(id);
      selectedProduct.value = product;

      // Track product view engagement
      _engagementService.trackProductView(id);
    } catch (e) {
      error.value = e.toString().replaceFirst('Exception: ', '');
      Get.snackbar('Error', error.value);
    } finally {
      isLoading.value = false;
    }
  }

  /// Track product search
  void trackProductSearch(String query, int resultsCount) {
    _engagementService.trackProductSearch(query, resultsCount);
  }
} 