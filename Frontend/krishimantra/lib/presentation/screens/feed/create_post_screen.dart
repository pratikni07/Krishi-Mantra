import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../data/services/language_service.dart';
import '../../controllers/feed_controller.dart';
import '../../controllers/background_upload_controller.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _feedController = Get.find<FeedController>();
  final _uploadController = Get.find<BackgroundUploadController>();
  late LanguageService _languageService;
  
  List<File> _selectedMedia = [];
  final _picker = ImagePicker();
  final PageController _pageController = PageController();
  int _currentPage = 0;

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
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    try {
      final source = await Get.bottomSheet<String>(
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Media Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceOption(
                    icon: Icons.photo_library,
                    label: 'Images',
                    onTap: () => Get.back(result: 'images'),
                  ),
                  _buildSourceOption(
                    icon: Icons.videocam,
                    label: 'Video',
                    onTap: () => Get.back(result: 'video'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      if (source == 'images') {
        // Multi-image selection
        final List<XFile> files = await _picker.pickMultiImage();
        if (files.isNotEmpty) {
          final List<File> validFiles = [];
          for (final file in files) {
            final fileSize = await File(file.path).length();
            if (fileSize > 100 * 1024 * 1024) {
              Get.snackbar(
                'Error',
                'File ${file.name} exceeds 100MB limit, skipped',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.red,
                colorText: Colors.white,
              );
              continue;
            }
            validFiles.add(File(file.path));
          }
          if (validFiles.isNotEmpty) {
            setState(() {
              _selectedMedia.addAll(validFiles);
            });
          }
        }
      } else {
        // Single video selection
        final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
        if (file != null) {
          final fileSize = await File(file.path).length();
          if (fileSize > 100 * 1024 * 1024) {
            Get.snackbar(
              'Error',
              'File size exceeds 100MB limit',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
            return;
          }
          setState(() {
            _selectedMedia = [File(file.path)];
          });
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick media: $e');
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);
      if (_currentPage >= _selectedMedia.length && _selectedMedia.isNotEmpty) {
        _currentPage = _selectedMedia.length - 1;
      }
    });
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.green, size: 30),
              ),
              const SizedBox(height: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
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
            const SizedBox(height: 16),
            _buildMediaPreview(),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickMedia,
              icon: const Icon(Icons.add_a_photo),
              label: Text(_selectedMedia.isEmpty ? 'Add Media' : 'Add More'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.green,
                side: const BorderSide(color: AppColors.green),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
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

  Widget _buildMediaPreview() {
    if (_selectedMedia.isEmpty) return const SizedBox.shrink();

    if (_selectedMedia.length == 1) {
      // Single media — simple preview
      return _buildSingleMediaPreview(_selectedMedia.first, 0);
    }

    // Multiple media — carousel with dots
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _selectedMedia.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildSingleMediaPreview(_selectedMedia[index], index),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_selectedMedia.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentPage == index ? 10 : 7,
              height: _currentPage == index ? 10 : 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index
                    ? AppColors.green
                    : Colors.grey.shade400,
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          '${_currentPage + 1} / ${_selectedMedia.length}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSingleMediaPreview(File file, int index) {
    final bool isVideo = file.path.toLowerCase().endsWith('.mp4') ||
        file.path.toLowerCase().endsWith('.mov');

    return Stack(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isVideo
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.video_library, size: 50, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          file.path.split('/').last,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : Image.file(file, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => _removeMedia(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  void _createPost() async {
    if (_descriptionController.text.isEmpty) {
      print('Validation failed - description (title) is empty');
      Get.snackbar(
        errorText,
        fillFieldsText,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (_contentController.text.isEmpty && _selectedMedia.isEmpty) {
      print('Validation failed - both content and media are empty');
      Get.snackbar(
        errorText,
        fillFieldsText,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Start background upload
    _uploadController.startUpload(
      description: _descriptionController.text,
      content: _contentController.text,
      mediaFiles: _selectedMedia.isNotEmpty ? _selectedMedia : null,
    );

    Get.back(); // Move back immediately
  }
}
