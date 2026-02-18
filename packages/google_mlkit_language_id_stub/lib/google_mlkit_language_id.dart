/// Stub for google_mlkit_language_id — allows iOS simulator builds on Apple Silicon.

class LanguageIdentifier {
  final double confidenceThreshold;

  LanguageIdentifier({this.confidenceThreshold = 0.5});

  Future<String> identifyLanguage(String text) async {
    // Stub: return undetermined
    return 'und';
  }

  Future<List<IdentifiedLanguage>> identifyPossibleLanguages(String text) async {
    return [];
  }

  Future<void> close() async {}
}

class IdentifiedLanguage {
  final String languageTag;
  final double confidence;

  IdentifiedLanguage({required this.languageTag, required this.confidence});
}
