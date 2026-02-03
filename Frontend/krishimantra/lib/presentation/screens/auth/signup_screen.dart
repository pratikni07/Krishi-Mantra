import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/core/constants/colors.dart';
import 'package:krishimantra/core/utils/responsive_utils.dart';
import 'package:krishimantra/presentation/controllers/auth_controller.dart';
import 'package:krishimantra/routes/app_routes.dart';
import '../../../data/services/language_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class SignupScreen extends StatefulWidget {
  final String phoneNumber;

  const SignupScreen({
    Key? key,
    required this.phoneNumber,
  }) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _authController = Get.find<AuthController>();
  late LanguageService _languageService;

  File? _profileImage;

  // Translatable text
  String completeProfileText = 'Complete Your Profile';
  String provideDetailsText = 'Please provide your details';
  String fullNameText = 'Full Name';
  String firstNameText = 'First Name';
  String lastNameText = 'Last Name';
  String phoneNumberText = 'Phone Number';
  String requiredFieldText = 'This field is required';
  String uploadPhotoText = 'Upload Photo';
  String continueText = 'Continue';
  String takePhotoText = 'Take Photo';
  String chooseFromGalleryText = 'Choose from Gallery';
  String cancelText = 'Cancel';
  String optionalText = 'Optional';

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
      _languageService.translate('Complete Your Profile'),
      _languageService.translate('Please provide your details'),
      _languageService.translate('Full Name'),
      _languageService.translate('First Name'),
      _languageService.translate('Last Name'),
      _languageService.translate('Phone Number'),
      _languageService.translate('This field is required'),
      _languageService.translate('Upload Photo'),
      _languageService.translate('Continue'),
      _languageService.translate('Take Photo'),
      _languageService.translate('Choose from Gallery'),
      _languageService.translate('Cancel'),
      _languageService.translate('Optional'),
    ]);

    setState(() {
      completeProfileText = translations[0];
      provideDetailsText = translations[1];
      fullNameText = translations[2];
      firstNameText = translations[3];
      lastNameText = translations[4];
      phoneNumberText = translations[5];
      requiredFieldText = translations[6];
      uploadPhotoText = translations[7];
      continueText = translations[8];
      takePhotoText = translations[9];
      chooseFromGalleryText = translations[10];
      cancelText = translations[11];
      optionalText = translations[12];
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 70,
    );

    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXXL)),
      ),
      builder: (context) => Padding(
        padding: RPadding.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppColors.green, size: AppSizes.iconM),
              title: Text(
                takePhotoText,
                style: TextStyle(
                  fontSize: AppSizes.fontL,
                  color: AppColors.textDark,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppColors.green, size: AppSizes.iconM),
              title: Text(
                chooseFromGalleryText,
                style: TextStyle(
                  fontSize: AppSizes.fontL,
                  color: AppColors.textDark,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel, color: AppColors.error, size: AppSizes.iconM),
              title: Text(
                cancelText,
                style: TextStyle(
                  fontSize: AppSizes.fontL,
                  color: AppColors.textDark,
                ),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final avatarRadius = ResponsiveUtils.responsive(mobile: 60.0, tablet: 80.0);
    final cameraButtonSize = ResponsiveUtils.responsive(mobile: 40.0, tablet: 48.0);

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
        child: SingleChildScrollView(
          padding: RPadding.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  completeProfileText,
                  style: TextStyle(
                    fontSize: AppSizes.fontTitle,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green,
                  ),
                ),
                SizedBox(height: AppSizes.paddingM),
                Text(
                  provideDetailsText,
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    color: AppColors.textGrey,
                  ),
                ),
                SizedBox(height: AppSizes.paddingXXL),

                // Profile Image
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _showImageSourceDialog,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: avatarRadius,
                              backgroundColor: AppColors.scaffoldBackground,
                              backgroundImage: _profileImage != null
                                  ? FileImage(_profileImage!)
                                  : null,
                              child: _profileImage == null
                                  ? Icon(
                                      Icons.person,
                                      size: avatarRadius,
                                      color: AppColors.textLight,
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                height: cameraButtonSize,
                                width: cameraButtonSize,
                                decoration: BoxDecoration(
                                  color: AppColors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: AppColors.white,
                                  size: AppSizes.iconS,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: AppSizes.paddingS),
                      Text(
                        "($optionalText)",
                        style: TextStyle(
                          fontSize: AppSizes.fontS,
                          color: AppColors.textLight,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppSizes.paddingXXL),

                // Full Name Field
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    color: AppColors.textDark,
                  ),
                  decoration: InputDecoration(
                    labelText: fullNameText,
                    labelStyle: const TextStyle(color: AppColors.textGrey),
                    prefixIcon: Icon(Icons.person, color: AppColors.green, size: AppSizes.iconM),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                      borderSide: const BorderSide(color: AppColors.green, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return requiredFieldText;
                    }
                    return null;
                  },
                ),

                SizedBox(height: AppSizes.paddingL),

                // First Name Field
                TextFormField(
                  controller: _firstNameController,
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    color: AppColors.textDark,
                  ),
                  decoration: InputDecoration(
                    labelText: firstNameText,
                    labelStyle: const TextStyle(color: AppColors.textGrey),
                    prefixIcon: Icon(Icons.person_outline, color: AppColors.green, size: AppSizes.iconM),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                      borderSide: const BorderSide(color: AppColors.green, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return requiredFieldText;
                    }
                    return null;
                  },
                ),

                SizedBox(height: AppSizes.paddingL),

                // Last Name Field
                TextFormField(
                  controller: _lastNameController,
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    color: AppColors.textDark,
                  ),
                  decoration: InputDecoration(
                    labelText: lastNameText,
                    labelStyle: const TextStyle(color: AppColors.textGrey),
                    prefixIcon: Icon(Icons.person_outline, color: AppColors.green, size: AppSizes.iconM),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                      borderSide: const BorderSide(color: AppColors.green, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return requiredFieldText;
                    }
                    return null;
                  },
                ),

                SizedBox(height: AppSizes.paddingL),

                // Phone Number Field (Disabled)
                TextFormField(
                  initialValue: widget.phoneNumber,
                  enabled: false,
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    color: AppColors.textGrey,
                  ),
                  decoration: InputDecoration(
                    labelText: phoneNumberText,
                    labelStyle: const TextStyle(color: AppColors.textGrey),
                    prefixText: '+91 ',
                    prefixIcon: Icon(Icons.phone, color: AppColors.green, size: AppSizes.iconM),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                    filled: true,
                    fillColor: AppColors.disabledBackground,
                  ),
                ),

                SizedBox(height: ResponsiveUtils.hp(5)),

                // Continue Button
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: AppSizes.buttonHeight,
                      child: ElevatedButton(
                        onPressed: _authController.isLoading.value
                            ? null
                            : () => _handleSignup(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          disabledBackgroundColor: AppColors.green.withOpacity(0.5),
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  // In _handleSignup() method of SignupScreen
  void _handleSignup() async {
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();

      // Show a loading dialog if an image is being uploaded
      if (_profileImage != null) {
        Get.dialog(
          Dialog(
            backgroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            ),
            child: Padding(
              padding: RPadding.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.green),
                  SizedBox(height: AppSizes.paddingL),
                  Text(
                    'Uploading profile image...',
                    style: TextStyle(
                      fontSize: AppSizes.fontS,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          barrierDismissible: false,
        );
      }

      final success = await _authController.signupWithPhone(
        name: _nameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNo: widget.phoneNumber,
        imageFile: _profileImage,
      );

      // Close the loading dialog if it was shown
      if (_profileImage != null && Get.isDialogOpen == true) {
        Get.back();
      }

      if (success) {
        // Registration successful, navigate to main screen
        Get.offAllNamed(AppRoutes.MAIN);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
}
