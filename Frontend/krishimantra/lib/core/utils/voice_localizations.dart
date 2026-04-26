/// Voice-UI string table. Same shape as `home_localizations.dart` so the
/// existing TranslationManager can be wired in if/when callers want it.
///
/// At launch we ship en/hi/mr; other languages fall back to English.
class VoiceLocalizations {
  static const Map<String, Map<String, String>> _localized = {
    'en': {
      'voice.hold_to_speak': 'Hold to speak',
      'voice.recording': 'Recording…',
      'voice.release_to_send': 'Release to send',
      'voice.slide_to_cancel': 'Slide up to cancel',
      'voice.permission_needed':
          'Allow microphone access to use voice chat',
      'voice.permission_open_settings': 'Open Settings',
      'voice.too_short': 'Hold longer to record',
      'voice.couldnt_catch': 'Couldn\'t catch that — please try again',
      'voice.replay': 'Replay',
      'voice.transcribing': 'Transcribing…',
      'voice.disabled': 'Voice unavailable right now',
      'voice.audio_expired': 'Recording cached for 24 hours only',
      'voice.network_needed': 'Voice needs internet',
      'voice.upload_failed': 'Upload failed — please try again',
      'voice.settings.title': 'Voice',
      'voice.settings.replies_enabled': 'Voice replies',
      'voice.settings.replies_subtitle':
          'Hear AI responses spoken in your language',
      'voice.settings.gender_label': 'Voice gender',
      'voice.settings.gender_female': 'Female',
      'voice.settings.gender_male': 'Male',
      'voice.settings.retain': 'Keep my voice notes for 30 days',
      'voice.settings.retain_subtitle':
          'Off by default — recordings are deleted after transcription',
      'voice.settings.delete_all': 'Delete all voice notes',
    },
    'hi': {
      'voice.hold_to_speak': 'दबाकर बोलें',
      'voice.recording': 'रिकॉर्डिंग…',
      'voice.release_to_send': 'छोड़ने पर भेजें',
      'voice.slide_to_cancel': 'रद्द करने के लिए स्वाइप करें',
      'voice.permission_needed':
          'वॉइस चैट के लिए माइक की अनुमति दें',
      'voice.permission_open_settings': 'सेटिंग खोलें',
      'voice.too_short': 'अधिक देर तक दबाकर रखें',
      'voice.couldnt_catch': 'समझ नहीं आया, फिर बोलें',
      'voice.replay': 'फिर सुनें',
      'voice.transcribing': 'लिख रहे हैं…',
      'voice.disabled': 'वॉइस अभी उपलब्ध नहीं',
      'voice.audio_expired': '24 घंटे तक ही रिकॉर्डिंग मिलती है',
      'voice.network_needed': 'वॉइस के लिए इंटरनेट चाहिए',
      'voice.upload_failed': 'अपलोड नहीं हुआ — फिर कोशिश करें',
      'voice.settings.title': 'आवाज़',
      'voice.settings.replies_enabled': 'आवाज़ में जवाब',
      'voice.settings.replies_subtitle':
          'AI के जवाब अपनी भाषा में सुनें',
      'voice.settings.gender_label': 'आवाज़',
      'voice.settings.gender_female': 'महिला',
      'voice.settings.gender_male': 'पुरुष',
      'voice.settings.retain': 'मेरी रिकॉर्डिंग 30 दिन रखें',
      'voice.settings.retain_subtitle':
          'डिफ़ॉल्ट: बंद — ट्रांसक्राइब होते ही रिकॉर्डिंग हटा दी जाती है',
      'voice.settings.delete_all': 'सभी वॉइस नोट्स हटाएँ',
    },
    'mr': {
      'voice.hold_to_speak': 'दाबून बोला',
      'voice.recording': 'रेकॉर्डिंग…',
      'voice.release_to_send': 'सोडल्यावर पाठवू',
      'voice.slide_to_cancel': 'रद्द करण्यासाठी स्वाइप करा',
      'voice.permission_needed':
          'व्हॉइस चॅटसाठी माइक परवानगी द्या',
      'voice.permission_open_settings': 'सेटिंग्ज उघडा',
      'voice.too_short': 'जास्त वेळ दाबून ठेवा',
      'voice.couldnt_catch': 'समजलं नाही, पुन्हा बोला',
      'voice.replay': 'पुन्हा ऐका',
      'voice.transcribing': 'लिहितोय…',
      'voice.disabled': 'व्हॉइस आत्ता उपलब्ध नाही',
      'voice.audio_expired': '२४ तासांसाठीच रेकॉर्डिंग साठवली जाते',
      'voice.network_needed': 'व्हॉइससाठी इंटरनेट हवं',
      'voice.upload_failed': 'अपलोड झालं नाही — पुन्हा प्रयत्न करा',
      'voice.settings.title': 'आवाज',
      'voice.settings.replies_enabled': 'आवाजात उत्तर',
      'voice.settings.replies_subtitle':
          'AI ची उत्तरं तुमच्या भाषेत ऐका',
      'voice.settings.gender_label': 'आवाज',
      'voice.settings.gender_female': 'स्त्री',
      'voice.settings.gender_male': 'पुरुष',
      'voice.settings.retain': 'माझ्या रेकॉर्डिंग ३० दिवस ठेवा',
      'voice.settings.retain_subtitle':
          'डीफॉल्ट: बंद — ट्रान्सक्राइब झाल्यावर रेकॉर्डिंग काढली जाते',
      'voice.settings.delete_all': 'सर्व व्हॉइस नोट्स काढा',
    },
  };

  static String text(String key, String langCode) {
    final lc = langCode.toLowerCase();
    final byLang = _localized[lc] ?? _localized['en']!;
    return byLang[key] ?? _localized['en']![key] ?? key;
  }
}
