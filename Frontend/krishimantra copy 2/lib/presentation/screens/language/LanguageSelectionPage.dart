import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../../data/services/language_service.dart';



// LanguageData class remains the same
class LanguageData {
  final String name;
  final String nativeName;
  final String flagEmoji;

  LanguageData({
    required this.name,
    required this.nativeName,
    required this.flagEmoji,
  });
}

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _earthController;
  late LanguageService _languageService;
  String _chooseLanguageText = 'Choose Your Language';
  String _selectPreferredText = 'Select the language you prefer';
  String _continueButtonText = 'Continue';
  String _selectLanguageText = 'Select a language';

  final List<LanguageData> languages = [
    LanguageData(
      name: 'English',
      nativeName: 'English',
      flagEmoji: '🇺🇸',
    ),
    LanguageData(
      name: 'Hindi',
      nativeName: 'हिंदी',
      flagEmoji: '🇮🇳',
    ),
    LanguageData(
      name: 'Marathi',
      nativeName: 'मराठी',
      flagEmoji: '🇮🇳',
    ),
    LanguageData(
      name: 'Gujarati',
      nativeName: 'ગુજરાતી',
      flagEmoji: '🇮🇳',
    ),
    LanguageData(
      name: 'Bengali',
      nativeName: 'বাংলা',
      flagEmoji: '🇮🇳',
    ),
    LanguageData(
      name: 'Tamil',
      nativeName: 'தமிழ்',
      flagEmoji: '🇮🇳',
    ),
  ];

  String? selectedLanguage;

  @override
  void initState() {
    super.initState();
    _earthController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    _initializeLanguage();
  }

  Future<void> _initializeLanguage() async {
    _languageService = await LanguageService.getInstance();
    setState(() {
      selectedLanguage = _languageService.getLanguage();
    });
    await _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    if (selectedLanguage == null) return;
    
    final translations = await Future.wait([
      _languageService.translate('Choose Your Language'),
      _languageService.translate('Select the language you prefer'),
      _languageService.translate('Continue'),
      _languageService.translate('Select a language'),
    ]);

    setState(() {
      _chooseLanguageText = translations[0];
      _selectPreferredText = translations[1];
      _continueButtonText = translations[2];
      _selectLanguageText = translations[3];
    });
  }

  @override
  void dispose() {
    _earthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildLanguageList(),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _earthController,
            builder: (_, child) {
              return Transform.rotate(
                angle: _earthController.value * 2 * math.pi,
                child: const Text(
                  '🌍',
                  style: TextStyle(fontSize: 108),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            _chooseLanguageText,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _selectPreferredText,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: languages.length,
      shrinkWrap: true, // Important: Makes ListView work within Column
      physics: const BouncingScrollPhysics(), // Adds bounce effect on scroll
      itemBuilder: (context, index) {
        return _buildLanguageCard(languages[index]);
      },
    );
  }

  Widget _buildLanguageCard(LanguageData language) {
    final isSelected = selectedLanguage == language.name;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectLanguage(language.name),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.green.withOpacity(0.1) : Colors.white,
              border: Border.all(
                color: isSelected ? Colors.green : Colors.grey.withOpacity(0.2),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? Colors.green.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    language.flagEmoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        language.nativeName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: selectedLanguage != null
              ? () async {
                  final languageService = await LanguageService.getInstance();
                  await languageService.saveLanguage(selectedLanguage!);
                  await _updateTranslations();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/main');
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: selectedLanguage != null ? 4 : 0,
          ),
          child: Text(
            selectedLanguage != null ? _continueButtonText : _selectLanguageText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _selectLanguage(String language) async {
    setState(() {
      selectedLanguage = language;
    });
    await _updateTranslations();
  }
}
