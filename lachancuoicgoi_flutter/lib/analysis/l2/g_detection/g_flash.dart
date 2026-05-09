import '../../common/text_normalizer.dart';

class GFlash {
  GFlash._();

  static void loadSlangConfig(Map<String, String> config) {
    TextNormalizer.loadSlangConfig(config);
  }

  static List<String> tokenize(String text) {
    return TextNormalizer.tokenize(
      text,
      applySlang: true,
      noiseMode: NoiseMode.space,
    );
  }
}
