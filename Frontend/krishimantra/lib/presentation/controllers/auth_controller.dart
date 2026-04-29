import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/models/user_model.dart';
import '../../data/models/otp_response_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/SocketService.dart';
import '../../data/services/UserService.dart';
import '../../data/services/engagement_service.dart';
import '../../data/services/feature_flag_service.dart';
import '../../data/services/push_notification_service.dart';
import '../../routes/app_routes.dart';
import 'farm_profile_controller.dart';
import 'feed_controller.dart';
import 'message_controller.dart';
import 'notification_controller.dart';
import 'presigned_url_controller.dart';
import 'reel_controller.dart';
import 'subscription_controller.dart';
import 'video_tutorial_controller.dart';

class AuthController extends GetxController {
  final _storage = const FlutterSecureStorage();
  final AuthRepository _authRepository;
  final UserService _userService = Get.find<UserService>();
  final EngagementService _engagement = EngagementService();
  final isPasswordVisible = false.obs;
  final Rx<UserModel?> user = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;

  AuthController(this._authRepository);

  /// Post-auth router. Probes the user's farm profile; if onboarding is
  /// incomplete, sends them to the multi-step onboarding flow first.
  /// Falls back to MAIN on any error so a flaky network never blocks login,
  /// but errors are now logged and a non-blocking snackbar surfaces the
  /// degraded path so support has something to triage from a bug report.
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
    } catch (e, st) {
      // Flags are best-effort — if missing, default to onboarding-on.
      // Log so we can detect a flag-service outage from telemetry.
      // ignore: avoid_print
      print('navigateAfterAuth: feature-flag refresh failed: $e\n$st');
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
    } catch (e, st) {
      // Best-effort routing — never block the user's login on this probe.
      // Surface the degraded path to the user and log so it doesn't
      // disappear silently into a `catch (_) {}`.
      // ignore: avoid_print
      print('navigateAfterAuth: farm-profile probe failed: $e\n$st');
      try {
        Get.snackbar(
          'Heads up',
          "Couldn't load your farm profile — using cached data.",
          snackPosition: SnackPosition.BOTTOM,
        );
      } catch (_) {}
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
        final restored = UserModel.fromJson(json.decode(userData));
        user.value = restored;
        // Restore the engagement session for a returning user. init() is
        // idempotent — if the session is already live it no-ops.
        if (restored.id != null) {
          await _engagement.init(restored.id!);
        }
        await navigateAfterAuth();
      } else {
        Get.offAllNamed(AppRoutes.PHONE_NUMBER);
      }
    } catch (e) {
      Get.offAllNamed(AppRoutes.PHONE_NUMBER);
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

        // Start the engagement session and emit user_login. init() must run
        // after the token is in storage so the session-start API call carries
        // the Authorization header set by the Dio interceptor.
        if (result.id != null) {
          await _engagement.init(result.id!);
          _engagement.trackEvent(
            EventName.userLogin,
            eventCategory: EventCategory.system,
            properties: {'method': 'password'},
          );
        }

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

        // Phone-OTP login of an existing account. Start the session and
        // record the login.
        if (userModel.id != null) {
          await _engagement.init(userModel.id!);
          _engagement.trackEvent(
            EventName.userLogin,
            eventCategory: EventCategory.system,
            properties: {'method': 'phone'},
          );
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
    required String firstName,
    required String lastName,
    required String phoneNo,
    File? imageFile,
  }) async {
    try {
      isLoading.value = true;

      final Map<String, dynamic> data = {
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

      // New account created — start session and record the signup.
      if (userModel.id != null) {
        await _engagement.init(userModel.id!);
        _engagement.trackEvent(
          EventName.userSignup,
          eventCategory: EventCategory.system,
          properties: {'withImage': imageFile != null},
        );
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

  // Upload the user-picked profile image during signup. The previous
  // implementation swallowed every error and returned null, which made
  // signup silently fall back to the default avatar — confusing for
  // users who picked an image and saw it disappear with no message. Now
  // we surface a non-blocking snackbar so they know the upload failed
  // (signup itself still continues with the default avatar so the
  // attempt isn't lost).
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
      try {
        Get.snackbar(
          'Profile photo',
          'Could not upload your photo — using a default avatar for now. You can change it later in profile settings.',
          snackPosition: SnackPosition.BOTTOM,
        );
      } catch (_) {}
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

      // Record the logout and close the engagement session BEFORE clearing
      // local storage — endSession() flushes pending events and POSTs to
      // sessions/end, both of which need the JWT still in storage.
      _engagement.trackEvent(
        EventName.userLogout,
        eventCategory: EventCategory.system,
      );
      await _engagement.endSession();


      // Clear the FCM token *before* we wipe local user state. The
      // unregister call needs the user id to identify which token row
      // to clear server-side; once `clearAllData()` runs below, that id
      // is gone. The push service also calls FirebaseMessaging.deleteToken()
      // so any in-flight messages bounce instead of being delivered to
      // the post-logout account on this device.
      try {
        if (Get.isRegistered<PushNotificationService>()) {
          await Get.find<PushNotificationService>().stopAndUnregister();
        }
      } catch (_) {}

      // Best-effort backend revoke + local secure-storage wipe.
      // The repository continues even if the server is unreachable, so the
      // local state below always runs.
      await _authRepository.logout();
      await _storage.deleteAll();
      await _userService.clearAllData();
      user.value = null;

      // Tear down feature controllers so the next user (or re-login of the
      // same user) starts with fresh state. All of these are registered as
      // `lazyPut(..., fenix: true)`, so Get re-instantiates them on the
      // next `Get.find<T>()`. ApiService / UserService / SocketService are
      // permanent and intentionally not deleted.
      _disposeFeatureControllers();

      // Disconnect the socket so we drop any per-user rooms / listeners.
      // The next post-login flow will reconnect with a fresh handshake.
      try {
        if (Get.isRegistered<SocketService>()) {
          Get.find<SocketService>().disconnect();
        }
      } catch (_) {}

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

  void _disposeFeatureControllers() {
    void safeDelete<T>() {
      try {
        if (Get.isRegistered<T>()) {
          Get.delete<T>(force: true);
        }
      } catch (_) {}
    }

    safeDelete<FeedController>();
    safeDelete<MessageController>();
    safeDelete<ReelController>();
    safeDelete<VideoTutorialController>();
    safeDelete<NotificationController>();
    safeDelete<SubscriptionController>();
    safeDelete<FarmProfileController>();
    safeDelete<PresignedUrlController>();
  }
}
