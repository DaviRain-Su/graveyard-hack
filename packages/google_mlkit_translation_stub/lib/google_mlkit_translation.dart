/// Stub for google_mlkit_translation — allows iOS simulator builds on Apple Silicon.
/// MLImage.framework doesn't include arm64 simulator slice, so we stub the API.

class TranslateLanguage {
  final String bcpCode;
  const TranslateLanguage._(this.bcpCode);

  static const arabic = TranslateLanguage._('ar');
  static const bulgarian = TranslateLanguage._('bg');
  static const catalan = TranslateLanguage._('ca');
  static const chinese = TranslateLanguage._('zh');
  static const czech = TranslateLanguage._('cs');
  static const danish = TranslateLanguage._('da');
  static const dutch = TranslateLanguage._('nl');
  static const english = TranslateLanguage._('en');
  static const estonian = TranslateLanguage._('et');
  static const french = TranslateLanguage._('fr');
  static const german = TranslateLanguage._('de');
  static const greek = TranslateLanguage._('el');
  static const hindi = TranslateLanguage._('hi');
  static const hungarian = TranslateLanguage._('hu');
  static const indonesian = TranslateLanguage._('id');
  static const italian = TranslateLanguage._('it');
  static const japanese = TranslateLanguage._('ja');
  static const korean = TranslateLanguage._('ko');
  static const latvian = TranslateLanguage._('lv');
  static const persian = TranslateLanguage._('fa');
  static const polish = TranslateLanguage._('pl');
  static const portuguese = TranslateLanguage._('pt');
  static const russian = TranslateLanguage._('ru');
  static const spanish = TranslateLanguage._('es');
  static const swedish = TranslateLanguage._('sv');
  static const thai = TranslateLanguage._('th');
  static const turkish = TranslateLanguage._('tr');
  static const ukrainian = TranslateLanguage._('uk');
  static const urdu = TranslateLanguage._('ur');
  static const vietnamese = TranslateLanguage._('vi');

  static const values = [
    arabic, bulgarian, catalan, chinese, czech, danish, dutch, english,
    estonian, french, german, greek, hindi, hungarian, indonesian, italian,
    japanese, korean, latvian, persian, polish, portuguese, russian, spanish,
    swedish, thai, turkish, ukrainian, urdu, vietnamese,
  ];
}

class OnDeviceTranslator {
  final TranslateLanguage sourceLanguage;
  final TranslateLanguage targetLanguage;

  OnDeviceTranslator({required this.sourceLanguage, required this.targetLanguage});

  Future<String> translateText(String text) async {
    return text; // Stub: return original text
  }

  Future<void> close() async {}
}

class OnDeviceTranslatorModelManager {
  Future<bool> downloadModel(dynamic language, {bool isWifiRequired = true}) async {
    return false; // Stub: model not available
  }

  Future<bool> isModelDownloaded(dynamic language) async {
    return false;
  }

  Future<bool> deleteModel(dynamic language) async {
    return true;
  }
}
