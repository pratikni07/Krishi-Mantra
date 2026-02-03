import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:krishimantra/core/constants/colors.dart';
import 'package:krishimantra/core/utils/responsive_utils.dart';
import 'package:krishimantra/presentation/controllers/auth_controller.dart';
import 'package:krishimantra/presentation/screens/auth/signup_screen.dart';
import 'package:krishimantra/routes/app_routes.dart';
import '../../../data/services/language_service.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OTPVerificationScreen({
    Key? key,
    required this.phoneNumber,
  }) : super(key: key);

  @override
  _OTPVerificationScreenState createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final _authController = Get.find<AuthController>();
  late LanguageService _languageService;

  // For countdown timer
  int _secondsRemaining = 60;
  bool _canResend = false;

  // Translatable text
  String verificationCodeText = 'Verification Code';
  String enterCodeText = 'Enter the verification code';
  String sentToText = 'We have sent a verification code to';
  String verifyText = 'Verify';
  String resendText = 'Resend Code';
  String didntReceiveText = "Didn't receive the code?";
  String resendInText = 'Resend in';

  @override
  void initState() {
    super.initState();
    _initializeLanguage();
    _startCountdown();
  }

  Future<void> _initializeLanguage() async {
    _languageService = await LanguageService.getInstance();
    await _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    final translations = await Future.wait([
      _languageService.translate('Verification Code'),
      _languageService.translate('Enter the verification code'),
      _languageService.translate('We have sent a verification code to'),
      _languageService.translate('Verify'),
      _languageService.translate('Resend Code'),
      _languageService.translate("Didn't receive the code?"),
      _languageService.translate('Resend in'),
    ]);

    setState(() {
      verificationCodeText = translations[0];
      enterCodeText = translations[1];
      sentToText = translations[2];
      verifyText = translations[3];
      resendText = translations[4];
      didntReceiveText = translations[5];
      resendInText = translations[6];
    });
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
        _startCountdown();
      } else {
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  void _resetCountdown() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    // Calculate OTP field size based on screen width
    final otpFieldWidth = ResponsiveUtils.responsive(
      mobile: (ResponsiveUtils.screenWidth - 48 - 40) / 6, // 48 padding, 40 spacing
      tablet: 56.0,
    );
    final otpFieldHeight = otpFieldWidth * 1.2;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.green, size: AppSizes.iconM),
          onPressed: () => Get.back(),
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
                  verificationCodeText,
                  style: TextStyle(
                    fontSize: AppSizes.fontTitle,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green,
                  ),
                ),
                SizedBox(height: AppSizes.paddingM),
                Text(
                  enterCodeText,
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    color: AppColors.textGrey,
                  ),
                ),
                SizedBox(height: AppSizes.paddingS),
                Text(
                  '$sentToText +91 ${widget.phoneNumber}',
                  style: TextStyle(
                    fontSize: AppSizes.fontM,
                    color: AppColors.textGrey.withOpacity(0.7),
                  ),
                ),
                SizedBox(height: ResponsiveUtils.hp(5)),

                // OTP Input Fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    6,
                    (index) => SizedBox(
                      width: otpFieldWidth,
                      height: otpFieldHeight,
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.backspace) {
                            if (_otpControllers[index].text.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                              _otpControllers[index - 1].clear();
                            }
                          }
                        },
                        child: TextFormField(
                          controller: _otpControllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AppSizes.fontXL,
                            fontWeight: FontWeight.bold,
                          ),
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(1),
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusL),
                              borderSide: const BorderSide(color: AppColors.borderLight),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusL),
                              borderSide: const BorderSide(color: AppColors.borderLight),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusL),
                              borderSide: const BorderSide(color: AppColors.green, width: 2),
                            ),
                            filled: true,
                            fillColor: AppColors.white,
                          ),
                          onChanged: (value) {
                            if (value.length == 1 && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                          },
                          onTap: () {
                            _otpControllers[index].selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _otpControllers[index].text.length,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: ResponsiveUtils.hp(5)),

                // Resend Code Section
                Center(
                  child: Column(
                    children: [
                      Text(
                        didntReceiveText,
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: AppSizes.fontM,
                        ),
                      ),
                      SizedBox(height: AppSizes.paddingS),
                      TextButton(
                        onPressed: _canResend
                            ? () {
                                _resetCountdown();
                                _authController.initiateAuth(widget.phoneNumber);
                              }
                            : null,
                        child: Text(
                          _canResend
                              ? resendText
                              : '$resendInText ${_secondsRemaining}s',
                          style: TextStyle(
                            color: _canResend ? AppColors.green : AppColors.textGrey,
                            fontWeight: FontWeight.bold,
                            fontSize: AppSizes.fontM,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Verify Button
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: AppSizes.buttonHeight,
                      child: ElevatedButton(
                        onPressed: _authController.isLoading.value
                            ? null
                            : () => _handleVerifyOTP(),
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
                                verifyText,
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

  String _getOtpCode() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  void _handleVerifyOTP() async {
    final otpCode = _getOtpCode();

    if (otpCode.length == 6) {
      final result =
          await _authController.verifyOTP(widget.phoneNumber, otpCode);

      if (result != null) {
        if (result.isRegistered) {
          Get.offAllNamed(AppRoutes.MAIN);
        } else {
          Get.to(() => SignupScreen(phoneNumber: widget.phoneNumber));
        }
      }
    } else {
      Get.snackbar(
        'Error',
        'Please enter a valid 6-digit code',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}
