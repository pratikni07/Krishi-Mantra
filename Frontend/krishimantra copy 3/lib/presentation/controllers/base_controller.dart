import 'package:get/get.dart';
import '../../../data/services/api_service.dart';

enum LoadingState { initial, loading, loaded, error }

class BaseController extends GetxController {
  final _loadingState = LoadingState.initial.obs;
  final _errorMessage = RxString('');
  final _isRefreshing = false.obs;

  LoadingState get loadingState => _loadingState.value;
  String get errorMessage => _errorMessage.value;
  bool get isRefreshing => _isRefreshing.value;
  bool get isLoading => _loadingState.value == LoadingState.loading;
  bool get hasError => _loadingState.value == LoadingState.error;

  void setLoading() {
    _loadingState.value = LoadingState.loading;
    _errorMessage.value = '';
  }

  void setLoaded() {
    _loadingState.value = LoadingState.loaded;
    _errorMessage.value = '';
  }

  void setError(String message) {
    _loadingState.value = LoadingState.error;
    _errorMessage.value = message;
  }

  void setRefreshing(bool value) {
    _isRefreshing.value = value;
  }

  Future<T?> handleAsync<T>(Future<T> Function() operation, {
    String loadingMessage = '',
    bool showLoading = true,
    bool isRefresh = false,
  }) async {
    try {
      if (isRefresh) {
        setRefreshing(true);
      } else if (showLoading) {
        setLoading();
      }

      final result = await operation();
      
      if (isRefresh) {
        setRefreshing(false);
      } else {
        setLoaded();
      }
      
      return result;
    } catch (error) {
      if (isRefresh) {
        setRefreshing(false);
      }
      setError(error.toString());
      return null;
    }
  }

  String getErrorMessage(dynamic error) {
    if (error is NoInternetException) {
      return 'No internet connection. Please check your connection and try again.';
    } else if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    } else if (error is UnauthorizedException) {
      return 'Session expired. Please login again.';
    } else if (error is ServerException) {
      return 'Server error occurred. Please try again later.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
} 