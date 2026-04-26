import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/colors.dart';
import '../../controllers/action_card_controller.dart';
import '../../controllers/presigned_url_controller.dart';

/// Daily "what did you notice today?" input row at the bottom of the action
/// card. Text + camera button + save. Whatever the farmer types/photographs
/// here is the highest-priority context for tomorrow's AI builder.
///
/// Constraints (mirror the server-side validator):
///   - text ≤ 500 chars
///   - up to 3 photos per submission
///   - photos uploaded via the existing presigned-URL pipeline so the URLs
///     point to OUR S3 bucket — anti-SSRF.
class FarmerInputRow extends StatefulWidget {
  const FarmerInputRow({super.key});

  @override
  State<FarmerInputRow> createState() => _FarmerInputRowState();
}

class _FarmerInputRowState extends State<FarmerInputRow> {
  final _ctrl = TextEditingController();
  final _picker = ImagePicker();
  final _stagedImages = <File>[];
  final _uploadedUrls = <String>[];
  bool _uploadingImage = false;
  bool _expanded = false;

  ActionCardController get _c => Get.find<ActionCardController>();
  PresignedUrlController? get _presigned =>
      Get.isRegistered<PresignedUrlController>() ? Get.find<PresignedUrlController>() : null;

  @override
  void initState() {
    super.initState();
    final existing = _c.card.value?.farmerInput?.text;
    if (existing != null && existing.isNotEmpty) {
      _ctrl.text = existing;
      _expanded = true;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_stagedImages.length >= 3) {
      Get.snackbar('Limit reached', 'Up to 3 photos per note',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 2000,
      );
      if (picked == null) return;
      setState(() {
        _stagedImages.add(File(picked.path));
        _uploadingImage = true;
      });

      final p = _presigned;
      if (p == null) {
        setState(() => _uploadingImage = false);
        Get.snackbar('Upload not ready', 'Please try again in a moment',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      final url = await p.uploadFile(file: File(picked.path), contentType: 'image/jpeg');
      if (!mounted) return;
      if (url == null) {
        setState(() {
          _stagedImages.removeLast();
          _uploadingImage = false;
        });
        Get.snackbar('Upload failed', 'Please try again',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      setState(() {
        _uploadedUrls.add(url);
        _uploadingImage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_stagedImages.isNotEmpty) _stagedImages.removeLast();
        _uploadingImage = false;
      });
      Get.snackbar('Could not upload', e.toString(),
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _stagedImages.removeAt(index);
      if (index < _uploadedUrls.length) _uploadedUrls.removeAt(index);
    });
  }

  Future<void> _save() async {
    final ok = await _c.submitFarmerInput(
      text: _ctrl.text,
      imageUrls: List.of(_uploadedUrls),
    );
    if (!mounted) return;
    if (ok) {
      Get.snackbar(
        'Saved',
        'Tomorrow\'s plan will use this note.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.green,
        colorText: AppColors.white,
        duration: const Duration(seconds: 2),
      );
      setState(() {
        _stagedImages.clear();
        _uploadedUrls.clear();
        _expanded = false;
      });
    } else {
      Get.snackbar(
        'Could not save',
        _c.errorMessage.value.isEmpty
            ? 'Please try again'
            : _c.errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final fi = _c.card.value?.farmerInput;
      final hasSavedToday =
          fi != null && fi.submittedAt != null && !fi.isEmpty;
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.note_alt_outlined, size: 18, color: AppColors.green),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'आज शेतावर काय पाहिलं?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                if (hasSavedToday)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.faintGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check, size: 10, color: AppColors.green),
                        SizedBox(width: 2),
                        Text('saved',
                            style: TextStyle(fontSize: 10, color: AppColors.green)),
                      ]),
                    ),
                  ),
                IconButton(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _ctrl,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'टाईप करा... (आजचे निरीक्षण)',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  counterText: '',
                ),
              ),
              if (_stagedImages.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _stagedImages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            _stagedImages[i],
                            width: 64, height: 64, fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: -8, top: -8,
                          child: IconButton(
                            iconSize: 18,
                            icon: const CircleAvatar(
                              radius: 9,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                            onPressed: () => _removeImage(i),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: _uploadingImage || _stagedImages.length >= 3
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    color: AppColors.green,
                    tooltip: 'फोटो काढा',
                  ),
                  IconButton(
                    onPressed: _uploadingImage || _stagedImages.length >= 3
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    color: AppColors.green,
                    tooltip: 'गॅलरीतून निवडा',
                  ),
                  if (_uploadingImage)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  const Spacer(),
                  Obx(() => ElevatedButton(
                        onPressed: _c.isSubmittingInput.value || _uploadingImage
                            ? null
                            : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: _c.isSubmittingInput.value
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('साठवा'),
                      )),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
}
