import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/models/user_model.dart';
import '../../data/models/otp_response_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/UserService.dart';
import '../../data/services/feature_flag_service.dart';
import '../../routes/app_routes.dart';
import 'farm_profile_controller.dart';
import 'presigned_url_controller.dart';

class AuthController extends GetxController {
  final _storage = const FlutterSecureStorage();
  final AuthRepository _authRepository;
  final UserService _userService = Get.find<UserService>();
  final isPasswordVisible = false.obs;
  final Rx<UserModel?> user = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;

  AuthController(this._authRepository);

  /// Post-auth router. Probes the user's farm profile; if onboarding is
  /// incomplete, sends them to the multi-step onboarding flow first.
  /// Falls back to MAIN on any error so a flaky network never blocks login.
  static Future<void> navigateAfterAuth() async {
    // Refresh feature flags now that we have a token; the splash already
    // primed the cache on cold start, but a fresh fetch picks up admin
    // changes since the last session.
    bool onboardingV2Enabled = true;
    try {
      if (Get.isRegistered<FeatureFlagService>()) {
        final ff = Get.find<FeatureFlagService>();
        await ff.refresh(force: true);
        onboardingV2Enabled = ff.onboardingV2Enabled;
      }
    } catch (_) {
      // Flags are best-effort — if missing, default to onboarding-on.
    }

    try {
      if (onboardingV2Enabled && Get.isRegistered<FarmProfileController>()) {
        final fp = Get.find<FarmProfileController>();
        await fp.loadFromServer();
        final status = fp.profile.value?.onboardingStatus;
        if (status != 'completed') {
          Get.offAllNamed(AppRoutes.FARM_ONBOARDING);
          return;
        }
      }
    } catch (_) {
      // Best-effort routing — never block the user's login on this probe.
    }
    Get.offAllNamed(AppRoutes.MAIN);
  }

  void togglePasswordVisibility() =>
      isPasswordVisible.value = !isPasswordVisible.value;

  Future<void> checkAuthStatus() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final userData = await _storage.read(key: 'user_data');

      if (token != null && userData != null) {
        user.value = UserModel.fromJson(json.decode(userData));
        await navigateAfterAuth();
      } else {
        Get.offAllNamed(AppRoutes.LOGIN);
      }
    } catch (e) {
      Get.offAllNamed(AppRoutes.LOGIN);
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      isLoading.value = true;

      final result = await _authRepository.login(email, password);

      // ignore: unnecessary_null_comparison
      if (result != null) {
        user.value = result;

        final userJson = result.toJson();

        await _storage.write(
          key: 'user_data',
          value: json.encode(userJson),
        );
        await navigateAfterAuth();
        return true;
      } else {
        throw Exception('Login failed: User data is null');
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Phone authentication methods
  Future<bool> initiateAuth(String phoneNo, {String language = 'hi'}) async {
    try {
      isLoading.value = true;

      final response = await _authRepository.initiateAuth(phoneNo, language: language);
      if (response['success'] == true) {
        return true;
      } else {
        throw Exception(
            response['message'] ?? 'Failed to initiate authentication');
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<OTPVerificationResult?> verifyOTP(String phoneNo, String otp) async {
    try {
      isLoading.value = true;

      final response = await _authRepository.verifyOTP(phoneNo, otp);

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'OTP verification failed');
      }

      // Handle both response formats
      final bool isRegistered = response['isRegistered'] ??
          (response['message'] == 'Login successful');

      // Create result object
      final result = OTPVerificationResult(
        isRegistered: isRegistered,
        message: response['message'],
        phoneNo: phoneNo,
      );

      // If user is registered (login successful), store the user data
      if (response['token'] != null && response['user'] != null) {
        final token = response['token'] as String;
        final userData = response['user'] as Map<String, dynamic>;

        // Add token to user data
        userData['token'] = token;

        // Save user data
        final userModel = UserModel.fromJson(userData);
        user.value = userModel;
        await _userService.saveUser(userModel);

        // Save token
        await _storage.write(key: 'auth_token', value: token);

        // Save refresh token if provided
        if (response['refreshToken'] != null) {
          await _storage.write(key: 'refresh_token', value: response['refreshToken'] as String);
        }
      }

      return result;
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> signupWithPhone({
    required String name,
    required String firstName,
    required String lastName,
    required String phoneNo,
    File? imageFile,
  }) async {
    try {
      isLoading.value = true;

      final Map<String, dynamic> data = {
        'name': name,
        'firstName': firstName,
        'lastName': lastName,
        'phoneNo': phoneNo,
      };
      if (imageFile != null) {
        final imageUrl = await _uploadImage(imageFile);
        if (imageUrl != null) {
          data['image'] = imageUrl;
        }
      }

      final response = await _authRepository.signupWithPhone(data);

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Registration failed');
      }
      final token = response['token'] as String;
      final userData = response['user'] as Map<String, dynamic>;
      userData['token'] = token;
      final userModel = UserModel.fromJson(userData);
      user.value = userModel;
      await _userService.saveUser(userModel);
      await _storage.write(key: 'auth_token', value: token);

      // Save refresh token if provided
      if (response['refreshToken'] != null) {
        await _storage.write(key: 'refresh_token', value: response['refreshToken'] as String);
      }

      return true;
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Add this method to your AuthController class
  Future<String?> _uploadImage(File imageFile) async {
    try {
      final presignedUrlController = Get.find<PresignedUrlController>();
      // Use 'profile' as content type for user profile images
      return await presignedUrlController.uploadImage(
        imageFile: imageFile,
        contentType: 'profile',
        userId: user.value?.id, isVideo: false,
      );
    } catch (e) {
      return null;
    }
  }

  // Helper method to upload profile image
  // Future<String?> _uploadImage(File imageFile) async {
  //   try {
  //     final formData = dio.FormData.fromMap({
  //       'file': await dio.MultipartFile.fromFile(
  //         imageFile.path,
  //         filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
  //       ),
  //     });

  //     final response = await _authRepository.uploadProfileImage(formData);
  //     if (response['success'] == true && response['fileUrl'] != null) {
  //       return response['fileUrl'];
  //     }
  //     return null;
  //   } catch (e) {
  //     print('Error uploading image: $e');
  //     return null;
  //   }
  // }

  Future<void> logout() async {
    try {
      isLoading.value = true;
      await _authRepository.logout();
      await _storage.deleteAll();
      await _userService.clearAllData();
      user.value = null;
      Get.offAllNamed(AppRoutes.PHONE_NUMBER);
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
