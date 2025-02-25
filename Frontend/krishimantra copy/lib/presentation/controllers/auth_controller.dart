// lib/presentation/controllers/auth_controller.dart

import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../routes/app_routes.dart';

class AuthController extends GetxController {
  final _storage = const FlutterSecureStorage();
  final AuthRepository _authRepository;
  final isPasswordVisible = false.obs;
  final Rx<UserModel?> user = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;

  AuthController(this._authRepository);

  void togglePasswordVisibility() =>
      isPasswordVisible.value = !isPasswordVisible.value;

  Future<void> checkAuthStatus() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final userData = await _storage.read(key: 'user_data');

      if (token != null && userData != null) {
        user.value = UserModel.fromJson(json.decode(userData));
        Get.offAllNamed(AppRoutes.MAIN);
      } else {
        Get.offAllNamed(AppRoutes.LOGIN);
      }
    } catch (e) {
      Get.offAllNamed(AppRoutes.LOGIN);
    }
  }

  Future<void> login(String email, String password) async {
    try {
      isLoading.value = true;

      final result = await _authRepository.login(email, password);

      if (result != null) {
        print('✅ Login successful, storing user data');
        user.value = result;

        final userJson = result.toJson();
        print('💾 User JSON to store: $userJson');

        await _storage.write(
          key: 'user_data',
          value: json.encode(userJson),
        );
        Get.offAllNamed(AppRoutes.MAIN);
      } else {
        throw Exception('Login failed: User data is null');
      }
    } catch (e, stackTrace) {
      print('⚠️ Error during login: $e');
      print('�stack: $stackTrace');
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      isLoading.value = true;
      await _authRepository.logout();
      await _storage.deleteAll();
      user.value = null;
      Get.offAllNamed(AppRoutes.LOGIN);
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
