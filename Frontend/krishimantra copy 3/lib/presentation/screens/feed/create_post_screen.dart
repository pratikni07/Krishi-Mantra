import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../data/services/language_service.dart';
import '../../controllers/feed_controller.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _feedController = Get.find<FeedController>();
  late LanguageService _languageService;

  // Translatable text
  String createPostText = 'Create Post';
  String titleText = 'Title';
  String contentText = 'Content';
  String postText = 'Post';
  String errorText = 'Error';
  String fillFieldsText = 'Please fill in all fields';
  String successText = 'Success';
  String postCreatedText = 'Post created successfully';

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
      _languageService.translate('Create Post'),
      _languageService.translate('Title'),
      _languageService.translate('Content'),
      _languageService.translate('Post'),
      _languageService.translate('Error'),
      _languageService.translate('Please fill in all fields'),
      _languageService.translate('Success'),
      _languageService.translate('Post created successfully'),
    ]);

    setState(() {
      createPostText = translations[0];
      titleText = translations[1];
      contentText = translations[2];
      postText = translations[3];
      errorText = translations[4];
      fillFieldsText = translations[5];
      successText = translations[6];
      postCreatedText = translations[7];
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(createPostText),
        backgroundColor: AppColors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: titleText,
                border: const OutlineInputBorder(),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: contentText,
                border: const OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _createPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                postText,
                style: const TextStyle(fontSize: 16, color: AppColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createPost() async {
    if (_contentController.text.isEmpty ||
        _descriptionController.text.isEmpty) {
      Get.snackbar(
        errorText,
        fillFieldsText,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    await _feedController.createFeed(
      _descriptionController.text,
      _contentController.text,
    );

    Get.back();
    Get.snackbar(
      successText,
      postCreatedText,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.green,
      colorText: AppColors.white,
    );
  }
}
