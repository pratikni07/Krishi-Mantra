import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/core/constants/colors.dart';
import 'package:krishimantra/core/utils/responsive_utils.dart';
import 'package:krishimantra/presentation/controllers/auth_controller.dart';
import '../../../data/services/language_service.dart';
import 'otp_verification_screen.dart';

class PhoneNumberScreen extends StatefulWidget {
  const PhoneNumberScreen({Key? key}) : super(key: key);

  @override
  _PhoneNumberScreenState createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _authController = Get.find<AuthController>();
  late LanguageService _languageService;

  // Translatable text
  String phoneVerificationText = 'Phone Verification';
  String enterPhoneText = 'Enter your phone number';
  String weWillSendText =
      'We will send you an SMS with a verification code';
  String phoneNumberText = 'Phone Number';
  String continueText = 'Continue';
  String invalidPhoneText = 'Please enter a valid phone number';

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
      _languageService.translate('Phone Verification'),
      _languageService.translate('Enter your phone number'),
      _languageService.translate(
          'We will send you an SMS with a verification code'),
      _languageService.translate('Phone Number'),
      _languageService.translate('Continue'),
      _languageService.translate('Please enter a valid phone number'),
    ]);

    setState(() {
      phoneVerificationText = translations[0];
      enterPhoneText = translations[1];
      weWillSendText = translations[2];
      phoneNumberText = translations[3];
      continueText = translations[4];
      invalidPhoneText = translations[5];
    });
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.green, size: AppSizes.iconM),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Get.back();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: RPadding.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phoneVerificationText,
                  style: TextStyle(
                    fontSize: AppSizes.fontTitle,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green,
                  ),
                ),
                SizedBox(height: AppSizes.paddingM),
                Text(
                  enterPhoneText,
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    color: AppColors.textGrey,
                  ),
                ),
                SizedBox(height: AppSizes.paddingS),
                Text(
                  weWillSendText,
                  style: TextStyle(
                    fontSize: AppSizes.fontM,
                    color: AppColors.textGrey.withOpacity(0.7),
                  ),
                ),
                SizedBox(height: ResponsiveUtils.hp(5)),

                // Phone number field
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    color: AppColors.textDark,
                  ),
                  decoration: InputDecoration(
                    labelText: phoneNumberText,
                    prefixText: '+91 ',
                    labelStyle: const TextStyle(color: AppColors.textGrey),
                    hintStyle: const TextStyle(color: AppColors.textLight),
                    prefixIcon: Icon(Icons.phone, color: AppColors.green, size: AppSizes.iconM),
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
                    if (value == null || value.isEmpty) {
                      return invalidPhoneText;
                    }
                    if (value.length != 10 ||
                        !RegExp(r'^[0-9]+$').hasMatch(value)) {
                      return invalidPhoneText;
                    }
                    return null;
                  },
                ),

                const Spacer(),

                // Continue Button
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: AppSizes.buttonHeight,
                      child: ElevatedButton(
                        onPressed: _authController.isLoading.value
                            ? null
                            : () => _handleContinue(),
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
                                continueText,
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: AppSizes.fontL,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    )),
                SizedBox(height: AppSizes.paddingL),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleContinue() async {
    if (_formKey.currentState?.validate() ?? false) {
      final phoneNumber = _phoneController.text.trim();
      
      // Get current language code to send OTP in user's preferred language
      final languageCode = _languageService.getLanguageCode();
      
      final success = await _authController.initiateAuth(phoneNumber, language: languageCode);

      if (success) {
        Get.to(() => OTPVerificationScreen(phoneNumber: phoneNumber));
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}
