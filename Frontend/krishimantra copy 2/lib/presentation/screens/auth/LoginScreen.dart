import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/core/constants/colors.dart';
import '../../../data/services/language_service.dart';
import '../../controllers/auth_controller.dart';
import '../language/LanguageSelectionPage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authController = Get.find<AuthController>();
  late LanguageService _languageService;

  // Translatable text
  String welcomeBackText = 'Welcome Back!';
  String signInText = 'Please sign in to continue';
  String emailText = 'Email';
  String enterEmailText = 'Enter your email';
  String enterEmailErrorText = 'Please enter your email';
  String invalidEmailErrorText = 'Please enter a valid email';
  String passwordText = 'Password';
  String enterPasswordText = 'Enter your password';
  String enterPasswordErrorText = 'Please enter your password';
  String loginText = 'Login';
  String termsText = 'By continuing, you agree to our Terms and Conditions';

  @override
  void initState() {
    super.initState();
    _initializeLanguage();
  }

  Future<void> _initializeLanguage() async {
    _languageService = await LanguageService.getInstance();
    await _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    final translations = await Future.wait([
      _languageService.translate('Welcome Back!'),
      _languageService.translate('Please sign in to continue'),
      _languageService.translate('Email'),
      _languageService.translate('Enter your email'),
      _languageService.translate('Please enter your email'),
      _languageService.translate('Please enter a valid email'),
      _languageService.translate('Password'),
      _languageService.translate('Enter your password'),
      _languageService.translate('Please enter your password'),
      _languageService.translate('Login'),
      _languageService
          .translate('By continuing, you agree to our Terms and Conditions'),
    ]);

    setState(() {
      welcomeBackText = translations[0];
      signInText = translations[1];
      emailText = translations[2];
      enterEmailText = translations[3];
      enterEmailErrorText = translations[4];
      invalidEmailErrorText = translations[5];
      passwordText = translations[6];
      enterPasswordText = translations[7];
      enterPasswordErrorText = translations[8];
      loginText = translations[9];
      termsText = translations[10];
    });
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
                        welcomeBackText,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        signInText,
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
                      labelText: emailText,
                      hintText: enterEmailText,
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
                        return enterEmailErrorText;
                      }
                      if (!GetUtils.isEmail(value!)) {
                        return invalidEmailErrorText;
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
                          labelText: passwordText,
                          hintText: enterPasswordText,
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
                            return enterPasswordErrorText;
                          }
                          if (value!.length < 4) {
                            return 'Password must be at least 4 characters';
                          }
                          return null;
                        },
                      )),

                  const SizedBox(height: 32),

                  // Login Button
                  Obx(() => SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _authController.isLoading.value
                              ? null
                              : () => _handleLogin(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _authController.isLoading.value
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  loginText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      )),

                  const SizedBox(height: 24),

                  // Terms Text
                  Text(
                    termsText,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      final success = await _authController.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success) {
        Get.offAll(() => const LanguageSelectionScreen());
      }
    }
  }
}
