import 'dart:io';
import 'package:get/get.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../data/services/UserService.dart';
import 'presigned_url_controller.dart';

class MarketplaceController extends GetxController {
  final MarketplaceRepository _marketplaceRepository;
  final UserService _userService;
  final PresignedUrlController _presignedUrlController = Get.find<PresignedUrlController>();
  
  final RxBool isLoading = false.obs;
  final RxList<dynamic> marketplaceProducts = <dynamic>[].obs;
  final Rx<dynamic> selectedProduct = Rx<dynamic>(null);
  
  final RxList<dynamic> comments = <dynamic>[].obs;
  final RxBool isLoadingComments = false.obs;
  final RxBool hasMoreComments = true.obs;
  final RxInt currentPage = 1.obs;
  
  final Rx<Map<String, dynamic>> productDetails = Rx<Map<String, dynamic>>({});
  
  MarketplaceController(this._marketplaceRepository, this._userService);
  
  Future<void> fetchMarketplaceProducts() async {
    try {
      isLoading.value = true;
      final products = await _marketplaceRepository.getMarketplaceProducts();
      marketplaceProducts.value = products;
    } catch (e) {
      Get.snackbar('Error', 'Failed to fetch marketplace products: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  Future<void> fetchProductById(String productId) async {
    try {
      isLoading.value = true;
      final response = await _marketplaceRepository.getProductDetails(productId);
      productDetails.value = response['data'];
    } catch (e) {
      Get.snackbar('Error', 'Failed to fetch product details: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  Future<bool> isUserAllowedToAddProducts() async {
    final accountType = await _userService.getAccountType();
    return accountType == 'admin' || accountType == 'marketplace';
  }
  
  Future<String?> uploadMediaFile(File file, bool isVideo) async {
    try {
      final userId = await _userService.getUserId();
      return await _presignedUrlController.uploadImage(
        imageFile: file,
        contentType: 'marketplace',
        userId: userId,
        isVideo: isVideo,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to upload media: $e');
      return null;
    }
  }
  
  Future<bool> addProduct(Map<String, dynamic> productData, List<File> imageFiles, List<File> videoFiles, List<String> youtubeUrls) async {
    try {
      isLoading.value = true;
      
      // Get user ID
      final userId = await _userService.getUserId();
      productData['userId'] = userId;
      
      // Upload images and videos
      List<Map<String, dynamic>> media = [];
      
      // Upload images
      for (var imageFile in imageFiles) {
        final imageUrl = await uploadMediaFile(imageFile, false);
        if (imageUrl != null) {
          media.add({
            'type': 'image',
            'url': imageUrl
          });
        }
      }
      
      // Upload videos
      for (var videoFile in videoFiles) {
        final videoUrl = await uploadMediaFile(videoFile, true);
        if (videoUrl != null) {
          media.add({
            'type': 'video',
            'url': videoUrl,
            'isYoutubeVideo': false
          });
        }
      }
      
      // Add YouTube URLs
      for (var youtubeUrl in youtubeUrls) {
        if (youtubeUrl.isNotEmpty) {
          media.add({
            'type': 'video',
            'url': youtubeUrl,
            'isYoutubeVideo': true
          });
        }
      }
      
      // Add media to product data
      productData['media'] = media;
      
      // Send request to API
      await _marketplaceRepository.addMarketplaceProduct(productData);
      Get.snackbar('Success', 'Product added successfully');
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to add product: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchComments(String productId, {bool refresh = false}) async {
    if (refresh) {
      comments.clear();
      currentPage.value = 1;
      hasMoreComments.value = true;
    }

    if (!hasMoreComments.value || isLoadingComments.value) return;

    try {
      isLoadingComments.value = true;
      final response = await _marketplaceRepository.getProductComments(
        productId, 
        currentPage.value
      );
      
      final newComments = response['data'] as List;
      comments.addAll(newComments);
      
      final pagination = response['pagination'];
      hasMoreComments.value = pagination['hasNextPage'];
      if (hasMoreComments.value) {
        currentPage.value++;
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to fetch comments: $e');
    } finally {
      isLoadingComments.value = false;
    }
  }

  Future<void> addComment(String productId, String text) async {
    try {
      final response = await _marketplaceRepository.addComment(productId, text);
      comments.insert(0, response['data']);
      Get.snackbar('Success', 'Comment added successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to add comment: $e');
    }
  }

  Future<void> addReply(String productId, String commentId, String text) async {
    try {
      final response = await _marketplaceRepository.addReply(productId, commentId, text);
      
      final commentIndex = comments.indexWhere((c) => c['_id'] == commentId);
      if (commentIndex != -1) {
        final updatedComment = Map<String, dynamic>.from(comments[commentIndex]);
        updatedComment['replies'] = [...(updatedComment['replies'] ?? []), response['data']];
        comments[commentIndex] = updatedComment;
      }
      
      Get.snackbar('Success', 'Reply added successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to add reply: $e');
    }
  }
}