import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:krishimantra/core/constants/colors.dart';
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

    // Setup focus node listeners
    for (int i = 0; i < 6; i++) {
      _focusNodes[i].addListener(() {
        _handleFocusChange(i);
      });
    }
  }

  void _handleFocusChange(int index) {
    if (_focusNodes[index].hasFocus && _otpControllers[index].text.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index].unfocus();
        _focusNodes[index + 1].requestFocus();
      }
    }
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.green),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verificationCodeText,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  enterCodeText,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$sentToText +91 ${widget.phoneNumber}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textGrey.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 40),

                // OTP Input Fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    6,
                    (index) => SizedBox(
                      width: 45,
                      height: 56,
                      child: TextFormField(
                        controller: _otpControllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(1),
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
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
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          if (value.length == 1 && index < 5) {
                            FocusScope.of(context).nextFocus();
                          }
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Resend Code Section
                Center(
                  child: Column(
                    children: [
                      Text(
                        didntReceiveText,
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _canResend
                            ? () {
                                _resetCountdown();
                                _authController
                                    .initiateAuth(widget.phoneNumber);
                              }
                            : null,
                        child: Text(
                          _canResend
                              ? resendText
                              : '$resendInText ${_secondsRemaining}s',
                          style: TextStyle(
                            color: _canResend ? AppColors.green : Colors.grey,
                            fontWeight: FontWeight.bold,
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
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _authController.isLoading.value
                            ? null
                            : () => _handleVerifyOTP(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _authController.isLoading.value
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                verifyText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    )),
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
          // User exists and is logged in, go to main screen
          Get.offAllNamed(AppRoutes.MAIN);
        } else {
          // User needs to complete registration
          Get.to(() => SignupScreen(phoneNumber: widget.phoneNumber));
        }
      }
    } else {
      Get.snackbar(
        'Error',
        'Please enter a valid 6-digit code',
        snackPosition: SnackPosition.BOTTOM,
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
