import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/core/constants/colors.dart';
import 'package:krishimantra/core/utils/responsive_utils.dart';
import '../../../data/services/language_service.dart';
import '../../../core/utils/language_helper.dart';
import '../../../core/utils/error_with_translation.dart';
import '../../../routes/app_routes.dart';
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
    ResponsiveUtils.init(context);

    final logoSize = ResponsiveUtils.responsive(
      mobile: ResponsiveUtils.wp(50),
      tablet: ResponsiveUtils.wp(35),
    );

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: RPadding.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: ResponsiveUtils.hp(8)),

                  // Logo
                  Hero(
                    tag: 'app_logo',
                    child: Image.asset(
                      'assets/Images/krishimantra-logo.png',
                      height: logoSize,
                      width: logoSize,
                    ),
                  ),

                  SizedBox(height: AppSizes.paddingXXL),

                  // Welcome Text
                  Column(
                    children: [
                      Text(
                        getTranslation(KEY_WELCOME_BACK),
                        style: TextStyle(
                          fontSize: AppSizes.fontTitle,
                          fontWeight: FontWeight.bold,
                          color: AppColors.green,
                        ),
                      ),
                      SizedBox(height: AppSizes.paddingS),
                      Text(
                        getTranslation(KEY_SIGN_IN),
                        style: TextStyle(
                          fontSize: AppSizes.fontL,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: ResponsiveUtils.hp(5)),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(
                      fontSize: AppSizes.fontL,
                      color: AppColors.textDark,
                    ),
                    decoration: InputDecoration(
                      labelText: getTranslation(KEY_EMAIL),
                      hintText: getTranslation(KEY_ENTER_EMAIL),
                      labelStyle: const TextStyle(color: AppColors.textGrey),
                      hintStyle: const TextStyle(color: AppColors.textLight),
                      prefixIcon: Icon(Icons.email, color: AppColors.green, size: AppSizes.iconM),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusL),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusL),
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusL),
                        borderSide: const BorderSide(color: AppColors.green, width: 2),
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

                  SizedBox(height: AppSizes.paddingXL),

                  // Password Field
                  Obx(() => TextFormField(
                        controller: _passwordController,
                        obscureText: !_authController.isPasswordVisible.value,
                        style: TextStyle(
                          fontSize: AppSizes.fontL,
                          color: AppColors.textDark,
                        ),
                        decoration: InputDecoration(
                          labelText: getTranslation(KEY_PASSWORD),
                          hintText: getTranslation(KEY_ENTER_PASSWORD),
                          labelStyle: const TextStyle(color: AppColors.textGrey),
                          hintStyle: const TextStyle(color: AppColors.textLight),
                          prefixIcon: Icon(Icons.lock, color: AppColors.green, size: AppSizes.iconM),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _authController.isPasswordVisible.value
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: AppColors.textLight,
                              size: AppSizes.iconM,
                            ),
                            onPressed: _authController.togglePasswordVisibility,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusL),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusL),
                            borderSide: const BorderSide(color: AppColors.borderLight),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusL),
                            borderSide: const BorderSide(color: AppColors.green, width: 2),
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

                  SizedBox(height: AppSizes.paddingXL),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: AppSizes.buttonHeight,
                    child: Obx(() => ElevatedButton(
                          onPressed: _authController.isLoading.value
                              ? null
                              : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.green,
                            disabledBackgroundColor: AppColors.green.withOpacity(0.5),
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusL),
                            ),
                            elevation: 2,
                          ),
                          child: _authController.isLoading.value
                              ? SizedBox(
                                  height: AppSizes.iconS,
                                  width: AppSizes.iconS,
                                  child: const CircularProgressIndicator(
                                    color: AppColors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  getTranslation(KEY_LOGIN),
                                  style: TextStyle(
                                    fontSize: AppSizes.fontL,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.white,
                                  ),
                                ),
                        )),
                  ),

                  SizedBox(height: AppSizes.paddingL),

                  // Forgot Password — recovery on this app is phone+OTP, so
                  // route to the phone-number screen rather than a dead
                  // email reset flow.
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Get.offAllNamed(AppRoutes.PHONE_NUMBER);
                      },
                      child: Text(
                        getTranslation(KEY_FORGOT_PASSWORD),
                        style: TextStyle(
                          color: AppColors.green,
                          fontWeight: FontWeight.w500,
                          fontSize: AppSizes.fontM,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: AppSizes.paddingXL),

                  // Terms and Conditions
                  Text(
                    getTranslation(KEY_TERMS),
                    style: TextStyle(
                      fontSize: AppSizes.fontM,
                      color: AppColors.textGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: AppSizes.paddingXL),

                  // Register
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        getTranslation(KEY_DONT_HAVE_ACCOUNT),
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: AppSizes.fontM,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Registration on this app is phone+OTP-based; the
                          // phone-number screen handles both new and returning
                          // users by branching on isRegistered after OTP verify.
                          Get.offAllNamed(AppRoutes.PHONE_NUMBER);
                        },
                        child: Text(
                          getTranslation(KEY_REGISTER),
                          style: TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: AppSizes.fontM,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: AppSizes.paddingL),

                  // Language Selection
                  GestureDetector(
                    onTap: () {
                      Get.to(() => const LanguageSelectionScreen());
                    },
                    child: Container(
                      padding: RPadding.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.green),
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.language, color: AppColors.green, size: AppSizes.iconM),
                          SizedBox(width: AppSizes.paddingS),
                          Text(
                            'Select Language',
                            style: TextStyle(
                              color: AppColors.green,
                              fontSize: AppSizes.fontM,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: AppSizes.paddingXL),
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
