// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/home_localizations.dart';
import '../../../core/utils/translation_manager.dart';
import '../../../data/services/language_service.dart';
import '../../controllers/disease_detection_controller.dart';

class DiseaseDetectionScreen extends StatefulWidget {
  const DiseaseDetectionScreen({super.key});

  @override
  State<DiseaseDetectionScreen> createState() => _DiseaseDetectionScreenState();
}

class _DiseaseDetectionScreenState extends State<DiseaseDetectionScreen>
    with SingleTickerProviderStateMixin {
  final DiseaseDetectionController _controller =
      Get.put(DiseaseDetectionController());
  String _languageCode = '';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _syncLanguageCode();
    TranslationManager.instance.addLanguageChangeListener(_onLanguageChanged);
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _syncLanguageCode() async {
    final ls = await LanguageService.getInstance();
    if (!mounted) return;
    setState(() => _languageCode = ls.getLanguageCode());
  }

  Future<void> _onLanguageChanged() async => _syncLanguageCode();

  String _t(String key) {
    if (_languageCode.isEmpty) return '';
    return HomeLocalizations.text(key, _languageCode);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    TranslationManager.instance
        .removeLanguageChangeListener(_onLanguageChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F5),
      appBar: AppBar(
        title: Text(
          _t('dd_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Obx(() {
        final image = _controller.selectedImage.value;
        final result = _controller.result.value;
        final scanning = _controller.isScanning.value;

        return SingleChildScrollView(
          child: Column(
            children: [
              // ── Image / Placeholder ────────────────────────
              _buildImageSection(image, scanning),

              // ── Action Buttons ─────────────────────────────
              if (!scanning) _buildActionButtons(),

              // ── Scanning Indicator ─────────────────────────
              if (scanning) _buildScanningIndicator(),

              // ── Result Card ────────────────────────────────
              if (result != null && !scanning) _buildResultCard(),

              // ── Error ──────────────────────────────────────
              if (_controller.errorMessage.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _controller.errorMessage.value,
                    style: TextStyle(color: AppColors.error, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              // ── Scan History ───────────────────────────────
              if (_controller.scanHistory.isNotEmpty && result == null)
                _buildHistory(),

              const SizedBox(height: 32),
            ],
          ),
        );
      }),
    );
  }

  // ── Image Section ──────────────────────────────────────────────
  Widget _buildImageSection(File? image, bool scanning) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scanning
              ? AppColors.green
              : AppColors.green.withOpacity(0.3),
          width: scanning ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (scanning ? AppColors.green : Colors.black)
                .withOpacity(scanning ? 0.15 : 0.06),
            blurRadius: scanning ? 20 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: image != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(image, fit: BoxFit.cover),
                  if (scanning)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (_, child) => Transform.scale(
                            scale: _pulseAnimation.value,
                            child: child,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.green.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.document_scanner,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.eco, size: 64, color: AppColors.green.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text(
                    _t('dd_placeholder'),
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t('dd_placeholder_hint'),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textLight.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }

  // ── Action Buttons ─────────────────────────────────────────────
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _actionButton(
              icon: Icons.camera_alt,
              label: _t('dd_camera'),
              onTap: () => _controller.pickFromCamera(),
              isPrimary: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _actionButton(
              icon: Icons.photo_library,
              label: _t('dd_gallery'),
              onTap: () => _controller.pickFromGallery(),
              isPrimary: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return Material(
      color: isPrimary ? AppColors.green : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: isPrimary ? 4 : 1,
      shadowColor: isPrimary
          ? AppColors.green.withOpacity(0.3)
          : Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isPrimary ? Colors.white : AppColors.green,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : AppColors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Scanning Indicator ─────────────────────────────────────────
  Widget _buildScanningIndicator() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppColors.green,
              strokeWidth: 4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _t('dd_scanning'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.green,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _t('dd_scanning_hint'),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  // ── Result Card ────────────────────────────────────────────────
  Widget _buildResultCard() {
    final r = _controller.result.value!;
    final isHealthy = r.isHealthy;
    final isUnknown = r.diseaseName == 'Unknown';
    final statusColor = isHealthy
        ? const Color(0xFF2E7D32)
        : isUnknown
            ? Colors.orange
            : AppColors.error;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(
                  isHealthy
                      ? Icons.check_circle
                      : isUnknown
                          ? Icons.help_outline
                          : Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHealthy
                            ? _t('dd_healthy')
                            : r.diseaseName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isUnknown)
                        Text(
                          '${r.cropName} • ${(r.confidence * 100).toStringAsFixed(0)}% ${_t('dd_confidence')}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                _infoSection(
                  Icons.info_outline,
                  _t('dd_description'),
                  r.description,
                ),

                if (!isHealthy && !isUnknown) ...[
                  const SizedBox(height: 16),
                  // Treatment
                  _infoSection(
                    Icons.healing,
                    _t('dd_treatment'),
                    r.treatment,
                    color: AppColors.error,
                  ),

                  if (r.prevention.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    // Prevention
                    _infoSection(
                      Icons.shield_outlined,
                      _t('dd_prevention'),
                      r.prevention,
                      color: const Color(0xFF1565C0),
                    ),
                  ],
                ],
              ],
            ),
          ),

          // Scan Again button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _controller.reset(),
                icon: const Icon(Icons.refresh),
                label: Text(_t('dd_scan_again')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.green,
                  side: BorderSide(color: AppColors.green),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoSection(IconData icon, String title, String body,
      {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (color ?? AppColors.green).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color ?? AppColors.green),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textLight,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Scan History ───────────────────────────────────────────────
  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            _t('dd_recent_scans'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ),
        ..._controller.scanHistory.take(5).map((r) => ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.error.withOpacity(0.1),
                child: Icon(Icons.bug_report, color: AppColors.error, size: 20),
              ),
              title: Text(
                r.diseaseName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(r.cropName),
              trailing: Text(
                '${(r.confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )),
      ],
    );
  }
}
