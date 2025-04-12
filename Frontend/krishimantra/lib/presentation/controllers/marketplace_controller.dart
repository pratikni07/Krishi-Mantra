import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../data/services/UserService.dart';
import 'presigned_url_controller.dart';
import 'base_controller.dart';
import 'dart:async';

class MarketplaceController extends BaseController {
  final MarketplaceRepository _marketplaceRepository;
  final UserService _userService = Get.find<UserService>();
  final PresignedUrlController _presignedUrlController =
      Get.find<PresignedUrlController>();

  final RxList<dynamic> marketplaceProducts = <dynamic>[].obs;
  final Rx<dynamic> selectedProduct = Rx<dynamic>(null);

  final RxBool isCommentsLoading = false.obs;
  final RxBool isLoadingComments = false.obs;
  final RxBool hasMoreComments = true.obs;
  int currentPage = 1;

  final RxMap<String, dynamic> productDetails = RxMap();
  final RxList<Map<String, dynamic>> comments = RxList();

  final ScrollController scrollController = ScrollController();
  bool isLoadingMore = false;

  final searchController = TextEditingController();
  final RxBool isSearching = false.obs;
  final RxString selectedCategory = ''.obs;
  final RxString selectedCondition = ''.obs;
  final RxDouble minPrice = 0.0.obs;
  final RxDouble maxPrice = 1000000.0.obs;
  final RxList<String> selectedTags = <String>[].obs;
  
  Timer? _debounce;

  final RxList<Map<String, dynamic>> products = <Map<String, dynamic>>[].obs;

  MarketplaceController(this._marketplaceRepository);

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_scrollListener);
    fetchProducts();
  }

  @override
  void onClose() {
    scrollController.removeListener(_scrollListener);
    scrollController.dispose();
    _debounce?.cancel();
    searchController.dispose();
    super.onClose();
  }

  void _scrollListener() async {
    if (scrollController.position.pixels == scrollController.position.maxScrollExtent) {
      if (!isLoadingMore && hasMoreComments.value) {
        await fetchComments(productDetails['_id'], refresh: false);
      }
    }
  }

  Future<void> fetchProducts() async {
    await handleAsync<void>(
      () async {
        final response = await _marketplaceRepository.searchProducts();
        if (response['success'] == true) {
          products.value = List<Map<String, dynamic>>.from(response['data']);
        } else {
          throw Exception(response['message'] ?? 'Failed to fetch products');
        }
      },
      showLoading: products.isEmpty,
    );
  }

  Future<void> fetchMarketplaceProducts() async {
    await handleAsync<void>(
      () async {
        final products = await _marketplaceRepository.getMarketplaceProducts();
        marketplaceProducts.value = products;
      },
      showLoading: marketplaceProducts.isEmpty,
    );
  }

  Future<void> fetchProductById(String productId) async {
    await handleAsync<void>(
      () async {
        final response = await _marketplaceRepository.getProductDetails(productId);
        if (response['success'] == true) {
          productDetails.value = response['data'];
        } else {
          throw Exception(response['message'] ?? 'Failed to fetch product details');
        }
      },
      showLoading: true,
    );
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
      setError(e);
      return null;
    }
  }

  Future<bool> addProduct(
      Map<String, dynamic> productData,
      List<File> imageFiles,
      List<File> videoFiles,
      List<String> youtubeUrls) async {
      
    return await handleAsync<bool>(() async {
      // Get user ID
      final userId = await _userService.getUserId();
      productData['userId'] = userId;

      // Upload images and videos
      List<Map<String, dynamic>> media = [];

      // Upload images
      for (var imageFile in imageFiles) {
        final imageUrl = await uploadMediaFile(imageFile, false);
        if (imageUrl != null) {
          media.add({'type': 'image', 'url': imageUrl});
        }
      }

      // Upload videos
      for (var videoFile in videoFiles) {
        final videoUrl = await uploadMediaFile(videoFile, true);
        if (videoUrl != null) {
          media.add({'type': 'video', 'url': videoUrl, 'isYoutubeVideo': false});
        }
      }

      // Add YouTube URLs
      for (var youtubeUrl in youtubeUrls) {
        if (youtubeUrl.isNotEmpty) {
          media.add({'type': 'video', 'url': youtubeUrl, 'isYoutubeVideo': true});
        }
      }

      // Add media to product data
      productData['media'] = media;

      // Send request to API
      await _marketplaceRepository.addMarketplaceProduct(productData);
      return true;
    }, showLoading: true) ?? false;
  }

  Future<void> fetchComments(String productId, {bool refresh = false}) async {
    if (refresh) {
      currentPage = 1;
      comments.clear();
      hasMoreComments.value = true;
    }

    if (!hasMoreComments.value || isLoadingMore) return;
    
    await handleAsync<void>(() async {
      isLoadingMore = true;
      isLoadingComments.value = true;
      
      final response = await _marketplaceRepository.getComments(productId, currentPage);
      
      if (response['success'] == true) {
        final pagination = response['pagination'];
        hasMoreComments.value = pagination['hasNextPage'] ?? false;
        
        final List<Map<String, dynamic>> commentsList = 
          List<Map<String, dynamic>>.from(response['data'] ?? []);
        
        if (refresh) {
          comments.value = commentsList;
        } else {
          comments.addAll(commentsList);
        }
        
        currentPage++;
      } else {
        throw Exception(response['message'] ?? 'Failed to load comments');
      }
      
      isLoadingMore = false;
      isLoadingComments.value = false;
    }, showLoading: comments.isEmpty && !refresh);
  }

  Future<void> addComment(String productId, String text) async {
    await handleAsync<void>(() async {
      final userId = await _userService.getUserId();
      if (userId == null) {
        throw Exception('Please login to comment');
      }

      final response = await _marketplaceRepository.addComment(productId, text);
      
      if (response['success'] == true && response['data'] != null) {
        final Map<String, dynamic> newComment = Map<String, dynamic>.from(response['data']);
        
        newComment.addAll({
          '_id': newComment['_id'] ?? DateTime.now().toString(),
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'replies': newComment['replies'] ?? [],
        });
        
        comments.insert(0, newComment);
      } else {
        throw Exception(response['message'] ?? 'Failed to add comment');
      }
    }, showLoading: true);
  }

  Future<void> addReply(String productId, String commentId, String text) async {
    try {
      final userId = await _userService.getUserId();
      if (userId == null) {
        Get.snackbar('Error', 'Please login to reply');
        return;
      }

      final response = await _marketplaceRepository.addReply(productId, commentId, text);
      
      if (response['success'] == true && response['data'] != null) {
        final newReply = {
          ...response['data'],
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        };

        final commentIndex = comments.indexWhere((c) => c['_id'] == commentId);
        if (commentIndex != -1) {
          final updatedComment = Map<String, dynamic>.from(comments[commentIndex]);
          final replies = List<Map<String, dynamic>>.from(updatedComment['replies'] ?? []);
          replies.add(Map<String, dynamic>.from(newReply));
          updatedComment['replies'] = replies;
          comments[commentIndex] = updatedComment;
        }
        Get.snackbar('Success', 'Reply added successfully');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to add reply: $e');
    }
  }

  void onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      searchProducts(keyword: query);
    });
  }

  Future<void> searchProducts({
    String? keyword,
    bool resetFilters = false,
  }) async {
    await handleAsync<void>(
      () async {
        isSearching.value = true;

        if (resetFilters) {
          selectedCategory.value = '';
          selectedCondition.value = '';
          minPrice.value = 0.0;
          maxPrice.value = 1000000.0;
          selectedTags.clear();
        }

        final response = await _marketplaceRepository.searchProducts(
          keyword: keyword,
          category: selectedCategory.value,
          minPrice: minPrice.value,
          maxPrice: maxPrice.value,
          condition: selectedCondition.value,
          tags: selectedTags,
        );

        if (response['success'] == true) {
          marketplaceProducts.value = List<Map<String, dynamic>>.from(response['data']);
        } else {
          throw Exception(response['message'] ?? 'Failed to search products');
        }
        
        isSearching.value = false;
      },
      showLoading: true,
    );
  }
}
