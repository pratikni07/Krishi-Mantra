// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/home_localizations.dart';
import '../../../../core/utils/translation_manager.dart';
import '../../../../data/services/language_service.dart';

/// A prominent banner for the "Consultation" feature, displayed above the
/// services grid on the home screen.
class ConsultationBanner extends StatefulWidget {
  const ConsultationBanner({super.key});

  @override
  State<ConsultationBanner> createState() => _ConsultationBannerState();
}

class _ConsultationBannerState extends State<ConsultationBanner> {
  String _languageCode = '';

  @override
  void initState() {
    super.initState();
    _syncLanguageCode();
    TranslationManager.instance.addLanguageChangeListener(_onLanguageChanged);
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
    TranslationManager.instance
        .removeLanguageChangeListener(_onLanguageChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed('/consultation'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF43A047), Color(0xFF66BB6A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.green.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                Icons.chat_bubble_outline,
                size: 120,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            Positioned(
              left: -15,
              bottom: -15,
              child: Icon(
                Icons.eco,
                size: 80,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.support_agent,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('consultation'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _t('consultation_banner_subtitle'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Arrow
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
