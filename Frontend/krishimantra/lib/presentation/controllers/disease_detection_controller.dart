import 'dart:io';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/disease_result.dart';
import '../../data/services/disease_detection_service.dart';
import '../../data/services/engagement_service.dart';

class DiseaseDetectionController extends GetxController {
  final Rx<File?> selectedImage = Rx<File?>(null);
  final Rx<DiseaseResult?> result = Rx<DiseaseResult?>(null);
  final RxBool isScanning = false.obs;
  final RxString errorMessage = ''.obs;
  final RxList<DiseaseResult> scanHistory = <DiseaseResult>[].obs;

  final ImagePicker _picker = ImagePicker();
  final EngagementService _engagement = EngagementService();

  Future<void> pickFromCamera() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (photo != null) {
        selectedImage.value = File(photo.path);
        result.value = null;
        errorMessage.value = '';
        await _scan();
      }
    } catch (e) {
      errorMessage.value = 'Failed to open camera';
    }
  }

  Future<void> pickFromGallery() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (photo != null) {
        selectedImage.value = File(photo.path);
        result.value = null;
        errorMessage.value = '';
        await _scan();
      }
    } catch (e) {
      errorMessage.value = 'Failed to pick image';
    }
  }

  Future<void> _scan() async {
    if (selectedImage.value == null) return;
    isScanning.value = true;
    errorMessage.value = '';
    final startedAt = DateTime.now();
    try {
      final service = await DiseaseDetectionService.getInstance();
      final detection = await service.detect(selectedImage.value!);
      result.value = detection;
      if (!detection.isHealthy &&
          detection.diseaseName != 'Unknown' &&
          scanHistory.length < 20) {
        scanHistory.insert(0, detection);
      }
      // Record only diagnostic metadata. Never log image bytes or paths.
      _engagement.trackEvent(
        EventName.aiCropScan,
        eventCategory: EventCategory.ai,
        properties: {
          'success': true,
          'isHealthy': detection.isHealthy,
          'diseaseName': detection.diseaseName,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        },
      );
    } catch (e) {
      errorMessage.value = 'Scan failed. Please try again.';
      _engagement.trackEvent(
        EventName.aiCropScan,
        eventCategory: EventCategory.ai,
        properties: {
          'success': false,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        },
      );
    } finally {
      isScanning.value = false;
    }
  }

  void reset() {
    selectedImage.value = null;
    result.value = null;
    errorMessage.value = '';
    isScanning.value = false;
  }
}
