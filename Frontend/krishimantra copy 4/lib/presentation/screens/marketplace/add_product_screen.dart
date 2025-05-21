import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/core/constants/colors.dart';
import 'package:krishimantra/presentation/controllers/marketplace_controller.dart';
import 'package:krishimantra/data/services/language_service.dart';
import 'package:krishimantra/core/utils/error_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({Key? key}) : super(key: key);

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final MarketplaceController _controller = Get.find<MarketplaceController>();
  late LanguageService _languageService;
  
  final List<File> _selectedImages = [];
  final List<File> _selectedVideos = [];
  final List<String> _youtubeUrls = [''];
  
  // Form controllers
  final _titleController = TextEditingController();
  final _shortDescController = TextEditingController();
  final _detailedDescController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _contactController = TextEditingController();
  final _categoryController = TextEditingController();
  final _conditionController = TextEditingController();
  final _locationController = TextEditingController();
  final _tagsController = TextEditingController();
  
  // Translations
  String addProductText = "Add Product";
  String titleText = "Title";
  String shortDescText = "Short Description";
  String detailedDescText = "Detailed Description";
  String imagesText = "Images";
  String videosText = "Videos";
  String priceRangeText = "Price Range (₹)";
  String contactNumberText = "Contact Number";
  String categoryText = "Category";
  String conditionText = "Condition";
  String locationText = "Location";
  String tagsText = "Tags (comma separated)";
  String saveText = "Save";
  String requiredFieldText = "This field is required";
  String addYouTubeText = "Add YouTube URL";
  String addMoreText = "Add More";
  
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
      _languageService.translate('Add Product'),
      _languageService.translate('Title'),
      _languageService.translate('Short Description'),
      _languageService.translate('Detailed Description'),
      _languageService.translate('Images'),
      _languageService.translate('Videos'),
      _languageService.translate('Price Range (₹)'),
      _languageService.translate('Contact Number'),
      _languageService.translate('Category'),
      _languageService.translate('Condition'),
      _languageService.translate('Location'),
      _languageService.translate('Tags (comma separated)'),
      _languageService.translate('Save'),
      _languageService.translate('This field is required'),
      _languageService.translate('Add YouTube URL'),
      _languageService.translate('Add More'),
    ]);
    
    setState(() {
      addProductText = translations[0];
      titleText = translations[1];
      shortDescText = translations[2];
      detailedDescText = translations[3];
      imagesText = translations[4];
      videosText = translations[5];
      priceRangeText = translations[6];
      contactNumberText = translations[7];
      categoryText = translations[8];
      conditionText = translations[9];
      locationText = translations[10];
      tagsText = translations[11];
      saveText = translations[12];
      requiredFieldText = translations[13];
      addYouTubeText = translations[14];
      addMoreText = translations[15];
    });
  }
  
  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((image) => File(image.path)).toList());
      });
    }
  }
  
  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    
    if (video != null) {
      setState(() {
        _selectedVideos.add(File(video.path));
      });
    }
  }
  
  void _addYoutubeUrl() {
    setState(() {
      _youtubeUrls.add('');
    });
  }
  
  void _updateYoutubeUrl(int index, String url) {
    setState(() {
      _youtubeUrls[index] = url;
    });
  }
  
  void _removeYoutubeUrl(int index) {
    setState(() {
      _youtubeUrls.removeAt(index);
    });
  }
  
  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      // Prepare product data
      final productData = {
        'title': _titleController.text,
        'shortDescription': _shortDescController.text,
        'detailedDescription': _detailedDescController.text,
        'priceRange': {
          'min': int.parse(_minPriceController.text),
          'max': int.parse(_maxPriceController.text),
          'currency': 'INR'
        },
        'contactNumber': _contactController.text,
        'category': _categoryController.text,
        'condition': _conditionController.text,
        'location': _locationController.text,
        'tags': _tagsController.text.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList(),
      };
      
      // Filter out empty YouTube URLs
      final validYoutubeUrls = _youtubeUrls.where((url) => url.isNotEmpty).toList();
      
      // Add product
      final success = await _controller.addProduct(
        productData, 
        _selectedImages, 
        _selectedVideos,
        validYoutubeUrls
      );
      
      if (success) {
        Get.back(); // Go back to marketplace screen
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(addProductText),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
      body: Obx(() {
        if (_controller.isLoading) {
          return Center(child: CircularProgressIndicator(color: AppColors.green));
        }
        
        if (_controller.hasError) {
          return ErrorHandler.getErrorWidget(
            errorType: _controller.errorType ?? ErrorType.unknown,
            onRetry: () => Get.back(),
            showRetry: true,
          );
        }
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: titleText,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return requiredFieldText;
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                
                // Short Description
                TextFormField(
                  controller: _shortDescController,
                  decoration: InputDecoration(
                    labelText: shortDescText,
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return requiredFieldText;
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                
                // Detailed Description
                TextFormField(
                  controller: _detailedDescController,
                  decoration: InputDecoration(
                    labelText: detailedDescText,
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return requiredFieldText;
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),
                
                // Images
                Text(
                  imagesText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                if (_selectedImages.isNotEmpty)
                  Container(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              margin: EdgeInsets.only(right: 8),
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(_selectedImages[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImages.removeAt(index);
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _pickImages,
                  icon: Icon(Icons.add_photo_alternate),
                  label: Text(_selectedImages.isEmpty ? 'Add Images' : 'Add More Images'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black87,
                  ),
                ),
                SizedBox(height: 24),
                
                // Videos
                Text(
                  videosText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                
                // Selected Videos
                if (_selectedVideos.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < _selectedVideos.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.video_file, color: Colors.grey[700]),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Video ${i + 1}',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _selectedVideos.removeAt(i);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _pickVideo,
                  icon: Icon(Icons.video_call),
                  label: Text(_selectedVideos.isEmpty ? 'Add Video' : 'Add More Videos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black87,
                  ),
                ),
                SizedBox(height: 16),
                
                // YouTube URLs
                Text(
                  '$addYouTubeText (${_languageService.translate('optional')})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                for (int i = 0; i < _youtubeUrls.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _youtubeUrls[i],
                            decoration: InputDecoration(
                              labelText: 'YouTube URL ${i + 1}',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => _updateYoutubeUrl(i, value),
                          ),
                        ),
                        SizedBox(width: 8),
                        if (_youtubeUrls.length > 1)
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeYoutubeUrl(i),
                          ),
                      ],
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: _addYoutubeUrl,
                  icon: Icon(Icons.add),
                  label: Text(addMoreText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black87,
                  ),
                ),
                SizedBox(height: 24),
                
                // Price Range
                Text(
                  priceRangeText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minPriceController,
                        decoration: InputDecoration(
                          labelText: 'Min (₹)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return requiredFieldText;
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _maxPriceController,
                        decoration: InputDecoration(
                          labelText: 'Max (₹)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return requiredFieldText;
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                
                // Contact Number
                TextFormField(
                  controller: _contactController,
                  decoration: InputDecoration(
                    labelText: contactNumberText,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return requiredFieldText;
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                
                // Category
                TextFormField(
                  controller: _categoryController,
                  decoration: InputDecoration(
                    labelText: categoryText,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return requiredFieldText;
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                
                // Condition
                TextFormField(
                  controller: _conditionController,
                  decoration: InputDecoration(
                    labelText: conditionText,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return requiredFieldText;
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                
                // Location
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: locationText,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return requiredFieldText;
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                
                // Tags
                TextFormField(
                  controller: _tagsController,
                  decoration: InputDecoration(
                    labelText: tagsText,
                    border: OutlineInputBorder(),
                    hintText: 'e.g. seed drill, planting, farming',
                  ),
                ),
                SizedBox(height: 32),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      saveText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 32),
              ],
            ),
          ),
        );
      }),
    );
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _shortDescController.dispose();
    _detailedDescController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _contactController.dispose();
    _categoryController.dispose();
    _conditionController.dispose();
    _locationController.dispose();
    _tagsController.dispose();
    super.dispose();
  }
} 