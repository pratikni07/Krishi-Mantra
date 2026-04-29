import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../data/services/UserService.dart';
import '../../data/services/engagement_service.dart';
import 'presigned_url_controller.dart';
import 'base_controller.dart';
import 'dart:async';

class MarketplaceController extends BaseController {
  final MarketplaceRepository _marketplaceRepository;
  final UserService _userService = Get.find<UserService>();
  final PresignedUrlController _presignedUrlController =
      Get.find<PresignedUrlController>();
  final EngagementService _engagement = EngagementService();

  final RxList<dynamic> marketplaceProducts = <dynamic>[].obs;
  final Rx<dynamic> selectedProduct = Rx<dynamic>(null);

  final RxBool isCommentsLoading = false.obs;
  final RxBool isLoadingComments = false.obs;
  final RxBool hasMoreComments = true.obs;
  int currentPage = 1;
  // The product whose comments populate the `comments` list. When the user
  // navigates between product details without an explicit refresh, the
  // shared `currentPage` would otherwise carry over and the next fetch
  // would request the wrong page for the new product (and append to a
  // list that still holds the previous product's comments).
  String? _commentsProductId;

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

  /// Categories fetched from the server. Empty until [fetchCategories] runs.
  /// Listeners (filter chips, add-product picker) should fall back to their
  /// own defaults when this is empty so the UI never blanks out during the
  /// initial load.
  final RxList<String> categories = <String>[].obs;

  RxString searchTerm = ''.obs;

  Timer? _debounce;

  final RxList<Map<String, dynamic>> products = <Map<String, dynamic>>[].obs;

  MarketplaceController(this._marketplaceRepository);

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_scrollListener);
    fetchProducts();
    // Best-effort — don't block first paint of the marketplace screen on
    // this call.
    fetchCategories();
  }

  /// Pull the latest category list from the server. Idempotent and silent
  /// on failure: keeps any previously-loaded list rather than blanking it.
  Future<void> fetchCategories() async {
    try {
      final list = await _marketplaceRepository.getCategories();
      if (list.isNotEmpty) {
        categories.assignAll(list);
      }
    } catch (_) {
      // Silent — picker falls back to local defaults.
    }
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
    if (scrollController.position.pixels ==
        scrollController.position.maxScrollExtent) {
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

  Future<void> fetchMarketplaceProducts({bool forceRefresh = false}) async {
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
        final response =
            await _marketplaceRepository.getProductDetails(productId);
        if (response['success'] == true) {
          productDetails.value = response['data'];
          _engagement.trackProductView(productId);
        } else {
          throw Exception(
              response['message'] ?? 'Failed to fetch product details');
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
    _engagement.trackEvent(
      EventName.marketplaceCreateStarted,
      eventCategory: EventCategory.commerce,
      properties: {
        'imageCount': imageFiles.length,
        'videoCount': videoFiles.length,
        'youtubeCount': youtubeUrls.length,
      },
    );
    return await handleAsync<bool>(() async {
          // Get user ID
          final userId = await _userService.getUserId();
          productData['userId'] = userId;

          // Upload images and videos. Track failures explicitly so the user
          // can decide whether to keep editing or proceed without the
          // failed media — silently dropping a failed image (the previous
          // behaviour) would let users post listings with missing photos
          // and no idea why.
          final media = <Map<String, dynamic>>[];
          final failedImages = <int>[];
          final failedVideos = <int>[];

          for (var i = 0; i < imageFiles.length; i++) {
            final imageUrl = await uploadMediaFile(imageFiles[i], false);
            if (imageUrl != null) {
              media.add({'type': 'image', 'url': imageUrl});
            } else {
              failedImages.add(i + 1);
            }
          }

          for (var i = 0; i < videoFiles.length; i++) {
            final videoUrl = await uploadMediaFile(videoFiles[i], true);
            if (videoUrl != null) {
              media.add(
                  {'type': 'video', 'url': videoUrl, 'isYoutubeVideo': false});
            } else {
              failedVideos.add(i + 1);
            }
          }

          if (failedImages.isNotEmpty || failedVideos.isNotEmpty) {
            final parts = <String>[];
            if (failedImages.isNotEmpty) {
              parts.add('images ${failedImages.join(', ')}');
            }
            if (failedVideos.isNotEmpty) {
              parts.add('videos ${failedVideos.join(', ')}');
            }
            // Throwing here aborts the create so the caller's "Save" button
            // stays available and the user can retry. handleAsync surfaces
            // the message via the controller's error stream.
            throw Exception(
                'Could not upload ${parts.join(' and ')}. Tap save again to retry.');
          }

          // Add YouTube URLs
          for (final youtubeUrl in youtubeUrls) {
            if (youtubeUrl.isNotEmpty) {
              media.add(
                  {'type': 'video', 'url': youtubeUrl, 'isYoutubeVideo': true});
            }
          }

          productData['media'] = media;

          await _marketplaceRepository.addMarketplaceProduct(productData);
          _engagement.trackEvent(
            EventName.marketplaceCreateCompleted,
            eventCategory: EventCategory.commerce,
            properties: {
              'mediaCount': media.length,
            },
          );

          // Refresh the marketplace list so the freshly-added product appears
          // without forcing the user to leave and re-enter the screen. Done
          // here (not in the screen) so every entry point that calls
          // addProduct gets the same behaviour.
          try {
            await fetchMarketplaceProducts(forceRefresh: true);
          } catch (_) {
            // Surface only the add-success path; refresh failure shouldn't
            // unwind the create.
          }
          return true;
        }, showLoading: true) ??
        false;
  }

  Future<void> fetchComments(String productId, {bool refresh = false}) async {
    // Treat a product switch as an implicit refresh so we don't carry over
    // pagination state or stale comments from the previous product.
    final productChanged =
        _commentsProductId != null && _commentsProductId != productId;
    final shouldReset = refresh || productChanged;

    if (shouldReset) {
      currentPage = 1;
      comments.clear();
      hasMoreComments.value = true;
    }
    _commentsProductId = productId;

    if (!hasMoreComments.value || isLoadingMore) return;

    await handleAsync<void>(() async {
      isLoadingMore = true;
      isLoadingComments.value = true;

      final response =
          await _marketplaceRepository.getComments(productId, currentPage);

      if (response['success'] == true) {
        final pagination = response['pagination'];
        hasMoreComments.value = pagination['hasNextPage'] ?? false;

        final List<Map<String, dynamic>> commentsList =
            List<Map<String, dynamic>>.from(response['data'] ?? []);

        if (shouldReset) {
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
        final Map<String, dynamic> newComment =
            Map<String, dynamic>.from(response['data']);

        // The server returns the persisted comment including its real
        // ObjectId. The previous code overwrote the _id with
        // `DateTime.now().toString()` if the server didn't include one,
        // which then collided with future comments and broke
        // delete/edit/reply lookups (those match on _id). If the server
        // truly returned no id, drop the entry rather than fabricating
        // one — a refresh will pull it from the next list fetch.
        if (newComment['_id'] == null) {
          throw Exception('Server response missing comment id');
        }

        // Backfill timestamps + replies array only if the server omitted
        // them. Don't overwrite real values.
        newComment.putIfAbsent('createdAt',
            () => DateTime.now().toUtc().toIso8601String());
        newComment.putIfAbsent('updatedAt',
            () => DateTime.now().toUtc().toIso8601String());
        newComment.putIfAbsent('replies', () => <dynamic>[]);

        comments.insert(0, newComment);
        _engagement.trackEvent(
          EventName.marketplaceComment,
          eventCategory: EventCategory.social,
          properties: {
            'contentId': productId,
            'contentType': 'product',
          },
        );
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

      final response =
          await _marketplaceRepository.addReply(productId, commentId, text);

      if (response['success'] == true && response['data'] != null) {
        final newReply = {
          ...response['data'],
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        };

        final commentIndex = comments.indexWhere((c) => c['_id'] == commentId);
        if (commentIndex != -1) {
          final updatedComment =
              Map<String, dynamic>.from(comments[commentIndex]);
          final replies =
              List<Map<String, dynamic>>.from(updatedComment['replies'] ?? []);
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
          keyword: keyword ?? searchTerm.value,
          category: selectedCategory.value,
          minPrice: minPrice.value,
          maxPrice: maxPrice.value,
          condition: selectedCondition.value,
          tags: selectedTags,
        );

        if (response['success'] == true) {
          marketplaceProducts.value =
              List<Map<String, dynamic>>.from(response['data']);
          // Only emit when the user typed a query; the no-keyword call is the
          // initial product list, not a search.
          final q = (keyword ?? searchTerm.value).trim();
          if (q.isNotEmpty) {
            _engagement.trackProductSearch(q, marketplaceProducts.length);
          }
        } else {
          throw Exception(response['message'] ?? 'Failed to search products');
        }

        isSearching.value = false;
      },
      showLoading: true,
    );
  }
}
