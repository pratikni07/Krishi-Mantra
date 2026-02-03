import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/services/translation_service.dart';
import '../../core/utils/translation_manager.dart';

/// A widget that automatically translates text based on selected language
/// Supports both static text and dynamic text from API responses
class TranslatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;
  final String? semanticsLabel;

  const TranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
    this.semanticsLabel,
  });

  @override
  State<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
  String _translatedText = '';
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    _translatedText = widget.text;
    _translate();

    // Listen to language changes
    TranslationManager.instance.addLanguageChangeListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    TranslationManager.instance.removeLanguageChangeListener(_onLanguageChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(TranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _translatedText = widget.text;
      _translate();
    }
  }

  void _onLanguageChanged() {
    _translate();
  }

  Future<void> _translate() async {
    if (_isTranslating) return;
    _isTranslating = true;

    try {
      final service = await TranslationService.getInstance();
      final translated = await service.translate(widget.text);

      if (mounted && translated != _translatedText) {
        setState(() {
          _translatedText = translated;
        });
      }
    } finally {
      _isTranslating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _translatedText,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      softWrap: widget.softWrap,
      semanticsLabel: widget.semanticsLabel,
    );
  }
}

/// A more efficient translated text widget using GetX reactive state
class TrText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;

  const TrText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getTranslation(),
      initialData: text,
      builder: (context, snapshot) {
        return Obx(() {
          // Re-render when language changes
          final _ = TranslationManager.instance.currentLanguage.value;
          return Text(
            snapshot.data ?? text,
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
            softWrap: softWrap,
          );
        });
      },
    );
  }

  Future<String> _getTranslation() async {
    final service = await TranslationService.getInstance();
    return service.translate(text);
  }
}

/// A button with translated text
class TranslatedButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final ButtonStyle? style;
  final bool isLoading;

  const TranslatedButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.style,
    this.isLoading = false,
  });

  @override
  State<TranslatedButton> createState() => _TranslatedButtonState();
}

class _TranslatedButtonState extends State<TranslatedButton> {
  String _translatedText = '';

  @override
  void initState() {
    super.initState();
    _translatedText = widget.text;
    _translate();
    TranslationManager.instance.addLanguageChangeListener(_translate);
  }

  @override
  void dispose() {
    TranslationManager.instance.removeLanguageChangeListener(_translate);
    super.dispose();
  }

  Future<void> _translate() async {
    final service = await TranslationService.getInstance();
    final translated = await service.translate(widget.text);
    if (mounted) {
      setState(() => _translatedText = translated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: widget.isLoading ? null : widget.onPressed,
      style: widget.style,
      child: widget.isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(_translatedText),
    );
  }
}

/// A label with automatic translation
class TranslatedLabel extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final EdgeInsetsGeometry? padding;

  const TranslatedLabel(
    this.text, {
    super.key,
    this.style,
    this.padding,
  });

  @override
  State<TranslatedLabel> createState() => _TranslatedLabelState();
}

class _TranslatedLabelState extends State<TranslatedLabel> {
  String _translatedText = '';

  @override
  void initState() {
    super.initState();
    _translatedText = widget.text;
    _translate();
    TranslationManager.instance.addLanguageChangeListener(_translate);
  }

  @override
  void dispose() {
    TranslationManager.instance.removeLanguageChangeListener(_translate);
    super.dispose();
  }

  Future<void> _translate() async {
    final service = await TranslationService.getInstance();
    final translated = await service.translate(widget.text);
    if (mounted) {
      setState(() => _translatedText = translated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: Text(
        _translatedText,
        style: widget.style ??
            TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
      ),
    );
  }
}

/// Extension to make translation easier in widgets
extension TranslationExtension on String {
  Widget tr({
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return TranslatedText(
      this,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Mixin for screens that need translation support
mixin TranslationScreenMixin<T extends StatefulWidget> on State<T> {
  final Map<String, String> _translations = {};
  bool _isTranslating = false;

  /// Register text for translation
  void registerText(String key, String defaultText) {
    _translations[key] = defaultText;
  }

  /// Get translated text
  String getText(String key) => _translations[key] ?? key;

  /// Update all translations
  Future<void> updateTranslations() async {
    if (_isTranslating) return;
    _isTranslating = true;

    try {
      final service = await TranslationService.getInstance();
      final entries = _translations.entries.toList();

      for (final entry in entries) {
        final translated = await service.translate(entry.value);
        _translations[entry.key] = translated;
      }

      if (mounted) {
        setState(() {});
      }
    } finally {
      _isTranslating = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateTranslations();
    });
    TranslationManager.instance.addLanguageChangeListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    TranslationManager.instance.removeLanguageChangeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    updateTranslations();
  }
}
