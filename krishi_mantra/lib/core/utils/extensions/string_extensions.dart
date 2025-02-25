import '../../../services/language_service.dart';

extension TranslationExtension on String {
  Future<String> tr() async {
    final languageService = await LanguageService.getInstance();
    return languageService.translate(this);
  }
}
