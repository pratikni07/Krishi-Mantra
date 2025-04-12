import 'package:get/get.dart';
import '../../data/services/api_service.dart';
import '../../core/utils/error_handler.dart';

enum LoadingState { initial, loading, loaded, error }

class BaseController extends GetxController {
  final _loadingState = LoadingState.initial.obs;
  final _errorMessage = RxString('');
  final _errorType = Rx<ErrorType?>(null);
  final _isRefreshing = false.obs;

  LoadingState get loadingState => _loadingState.value;
  String get errorMessage => _errorMessage.value;
  ErrorType? get errorType => _errorType.value;
  bool get isRefreshing => _isRefreshing.value;
  bool get isLoading => _loadingState.value == LoadingState.loading;
  bool get hasError => _loadingState.value == LoadingState.error;

  void setLoading() {
    _loadingState.value = LoadingState.loading;
    _errorMessage.value = '';
    _errorType.value = null;
  }

  void setLoaded() {
    _loadingState.value = LoadingState.loaded;
    _errorMessage.value = '';
    _errorType.value = null;
  }

  void setError(dynamic error) {
    _loadingState.value = LoadingState.error;
    _errorType.value = ErrorHandler.handleApiError(error);
    _errorMessage.value = ErrorHandler.getErrorMessage(_errorType.value!);
  }

  void setRefreshing(bool value) {
    _isRefreshing.value = value;
  }

  Future<T?> handleAsync<T>(Future<T> Function() operation, {
    String loadingMessage = '',
    bool showLoading = true,
    bool isRefresh = false,
    bool showErrorScreen = false,
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
      
      setError(error);
      
      // Show full-screen error if specified
      if (showErrorScreen) {
        ErrorHandler.showErrorScreen(
          errorType: _errorType.value!,
          onRetry: () => handleAsync(operation, 
            showLoading: showLoading, 
            isRefresh: isRefresh,
            showErrorScreen: showErrorScreen,
          ),
        );
      }
      
      return null;
    }
  }
} 