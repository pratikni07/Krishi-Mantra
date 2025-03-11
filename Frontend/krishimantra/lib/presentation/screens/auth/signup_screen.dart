import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/core/constants/colors.dart';
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppColors.green),
              title: Text(takePhotoText),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppColors.green),
              title: Text(chooseFromGalleryText),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel, color: Colors.red),
              title: Text(cancelText),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  completeProfileText,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  provideDetailsText,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 30),

                // Profile Image
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _showImageSourceDialog,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _profileImage != null
                                  ? FileImage(_profileImage!)
                                  : null,
                              child: _profileImage == null
                                  ? Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey[400],
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "($optionalText)",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Full Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: fullNameText,
                    prefixIcon: Icon(Icons.person, color: AppColors.green),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.green, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return requiredFieldText;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // First Name Field
                TextFormField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                    labelText: firstNameText,
                    prefixIcon:
                        Icon(Icons.person_outline, color: AppColors.green),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.green, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return requiredFieldText;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Last Name Field
                TextFormField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                    labelText: lastNameText,
                    prefixIcon:
                        Icon(Icons.person_outline, color: AppColors.green),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.green, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return requiredFieldText;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Phone Number Field (Disabled)
                TextFormField(
                  initialValue: widget.phoneNumber,
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: phoneNumberText,
                    prefixText: '+91 ',
                    prefixIcon: Icon(Icons.phone, color: AppColors.green),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),

                const SizedBox(height: 40),

                // Continue Button
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _authController.isLoading.value
                            ? null
                            : () => _handleSignup(),
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
                                continueText,
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

  // In _handleSignup() method of SignupScreen
  void _handleSignup() async {
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();

      // Show a loading dialog if an image is being uploaded
      if (_profileImage != null) {
        Get.dialog(
          Dialog(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.green),
                  SizedBox(height: 16),
                  Text('Uploading profile image...'),
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
