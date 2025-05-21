import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/core/constants/colors.dart';
import '../../../data/services/language_service.dart';
import '../../../core/utils/language_helper.dart';
import '../../../core/utils/error_with_translation.dart';
import '../../controllers/auth_controller.dart';
import '../language/LanguageSelectionPage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TranslationMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authController = Get.find<AuthController>();

  // Translation keys
  static const String KEY_WELCOME_BACK = 'welcome_back';
  static const String KEY_SIGN_IN = 'sign_in';
  static const String KEY_EMAIL = 'email';
  static const String KEY_ENTER_EMAIL = 'enter_email';
  static const String KEY_ENTER_EMAIL_ERROR = 'enter_email_error';
  static const String KEY_INVALID_EMAIL_ERROR = 'invalid_email';
  static const String KEY_PASSWORD = 'password';
  static const String KEY_ENTER_PASSWORD = 'enter_password';
  static const String KEY_ENTER_PASSWORD_ERROR = 'enter_password_error';
  static const String KEY_PASSWORD_LENGTH_ERROR = 'password_length_error';
  static const String KEY_LOGIN = 'login';
  static const String KEY_TERMS = 'terms_conditions';
  static const String KEY_FORGOT_PASSWORD = 'forgot_password';
  static const String KEY_DONT_HAVE_ACCOUNT = 'dont_have_account';
  static const String KEY_REGISTER = 'register';

  @override
  void initState() {
    super.initState();
    _registerTranslations();
  }

  void _registerTranslations() {
    registerTranslation(KEY_WELCOME_BACK, 'Welcome Back!');
    registerTranslation(KEY_SIGN_IN, 'Please sign in to continue');
    registerTranslation(KEY_EMAIL, 'Email');
    registerTranslation(KEY_ENTER_EMAIL, 'Enter your email');
    registerTranslation(KEY_ENTER_EMAIL_ERROR, 'Please enter your email');
    registerTranslation(KEY_INVALID_EMAIL_ERROR, 'Please enter a valid email');
    registerTranslation(KEY_PASSWORD, 'Password');
    registerTranslation(KEY_ENTER_PASSWORD, 'Enter your password');
    registerTranslation(KEY_ENTER_PASSWORD_ERROR, 'Please enter your password');
    registerTranslation(
        KEY_PASSWORD_LENGTH_ERROR, 'Password must be at least 4 characters');
    registerTranslation(KEY_LOGIN, 'Login');
    registerTranslation(
        KEY_TERMS, 'By continuing, you agree to our Terms and Conditions');
    registerTranslation(KEY_FORGOT_PASSWORD, 'Forgot Password?');
    registerTranslation(KEY_DONT_HAVE_ACCOUNT, "Don't have an account?");
    registerTranslation(KEY_REGISTER, 'Register');
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      try {
        final success = await _authController.login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (!success && mounted) {
          await TranslatedErrorHandler.showError(
              "Login failed. Please check your credentials.",
              context: context);
        }
      } catch (e) {
        await TranslatedErrorHandler.showError(e, context: context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),

                  // Logo
                  Hero(
                    tag: 'app_logo',
                    child: Image.asset(
                      'assets/Images/Logo.png',
                      height: 230,
                      width: 230,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Welcome Text
                  Column(
                    children: [
                      Text(
                        getTranslation(KEY_WELCOME_BACK),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        getTranslation(KEY_SIGN_IN),
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: getTranslation(KEY_EMAIL),
                      hintText: getTranslation(KEY_ENTER_EMAIL),
                      prefixIcon: Icon(Icons.email, color: AppColors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.green, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return getTranslation(KEY_ENTER_EMAIL_ERROR);
                      }
                      if (!GetUtils.isEmail(value!)) {
                        return getTranslation(KEY_INVALID_EMAIL_ERROR);
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Password Field
                  Obx(() => TextFormField(
                        controller: _passwordController,
                        obscureText: !_authController.isPasswordVisible.value,
                        decoration: InputDecoration(
                          labelText: getTranslation(KEY_PASSWORD),
                          hintText: getTranslation(KEY_ENTER_PASSWORD),
                          prefixIcon: Icon(Icons.lock, color: AppColors.green),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _authController.isPasswordVisible.value
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: _authController.togglePasswordVisibility,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppColors.green, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return getTranslation(KEY_ENTER_PASSWORD_ERROR);
                          }
                          if (value!.length < 4) {
                            return getTranslation(KEY_PASSWORD_LENGTH_ERROR);
                          }
                          return null;
                        },
                      )),

                  const SizedBox(height: 24),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: Obx(() => ElevatedButton(
                          onPressed: _authController.isLoading.value
                              ? null
                              : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.green,
                            disabledBackgroundColor:
                                AppColors.green.withOpacity(0.5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _authController.isLoading.value
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                )
                              : Text(
                                  getTranslation(KEY_LOGIN),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        )),
                  ),

                  const SizedBox(height: 16),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: Navigate to forgot password screen
                      },
                      child: Text(
                        getTranslation(KEY_FORGOT_PASSWORD),
                        style: TextStyle(
                          color: AppColors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Terms and Conditions
                  Text(
                    getTranslation(KEY_TERMS),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // Register
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        getTranslation(KEY_DONT_HAVE_ACCOUNT),
                        style: TextStyle(
                          color: AppColors.textGrey,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Navigate to register screen
                        },
                        child: Text(
                          getTranslation(KEY_REGISTER),
                          style: TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Language Selection
                  GestureDetector(
                    onTap: () {
                      Get.to(() => const LanguageSelectionScreen());
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.green),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.language, color: AppColors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Select Language',
                            style: TextStyle(color: AppColors.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
