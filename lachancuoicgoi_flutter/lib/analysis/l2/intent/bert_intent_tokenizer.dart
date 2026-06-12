import '../../common/text_normalizer.dart';

class BertInputs {
  const BertInputs({
    required this.inputIds,
    required this.attentionMask,
    required this.tokenTypeIds,
  });

  final List<int> inputIds;
  final List<int> attentionMask;
  final List<int> tokenTypeIds;
}

class BertIntentTokenizer {
  BertIntentTokenizer(this.vocab);

  static const int maxSeqLen = 256;
  static const String clsToken = '[CLS]';
  static const String sepToken = '[SEP]';
  static const String padToken = '[PAD]';
  static const String unkToken = '[UNK]';

  final Map<String, int> vocab;

  String normalizeVietnamese(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> tokenize(String text) {
    final normalized = normalizeVietnamese(text);
    if (normalized.isEmpty) return const <String>[];

    final result = <String>[];
    for (final word in normalized.split(' ')) {
      if (word.isEmpty) continue;
      if (vocab.containsKey(word)) {
        result.add(word);
        continue;
      }

      var subwords = wordPieceTokenize(word);
      if (subwords.length == 1 && subwords.first == unkToken) {
        final accentRemoved = TextNormalizer.normalize(
          word,
          applySlang: false,
          noiseMode: NoiseMode.space,
        );
        if (accentRemoved != word) {
          subwords = vocab.containsKey(accentRemoved)
              ? <String>[accentRemoved]
              : wordPieceTokenize(accentRemoved);
        }
      }
      result.addAll(subwords);
    }
    return result;
  }

  List<String> wordPieceTokenize(String word) {
    final subTokens = <String>[];
    var start = 0;
    var isBad = false;

    while (start < word.length) {
      var end = word.length;
      String? currentSubString;

      while (start < end) {
        final substring = start > 0
            ? '##${word.substring(start, end)}'
            : word.substring(start, end);
        if (vocab.containsKey(substring)) {
          currentSubString = substring;
          break;
        }
        end -= 1;
      }

      if (currentSubString == null) {
        isBad = true;
        break;
      }
      subTokens.add(currentSubString);
      start = end;
    }

    return isBad ? const <String>[unkToken] : subTokens;
  }

  BertInputs buildInputs(List<String> tokens) {
    final clsId = vocab[clsToken] ?? 101;
    final sepId = vocab[sepToken] ?? 102;
    final padId = vocab[padToken] ?? 0;
    final unkId = vocab[unkToken] ?? 100;
    const maxTokens = maxSeqLen - 2;

    // Chiến lược Sliding Truncation (đồng bộ với Kotlin gold standard):
    // Giữ 50 token đầu tiên (chứa lời xưng danh: cảnh sát, công an, ngân hàng...)
    // + phần còn lại ở cuối (chứa đỉnh điểm kịch bản: OTP, chuyển tiền, đe dọa).
    // Không dùng tail-only vì bỏ mất thông tin xưng danh ở đầu cuộc gọi.
    const int headSize = 50;
    final truncatedTokens = tokens.length <= maxTokens
        ? tokens
        : <String>[
            ...tokens.sublist(0, headSize),
            ...tokens.sublist(tokens.length - (maxTokens - headSize)),
          ];

    final inputIds = List<int>.filled(maxSeqLen, padId);
    final attentionMask = List<int>.filled(maxSeqLen, 0);
    final tokenTypeIds = List<int>.filled(maxSeqLen, 0);

    inputIds[0] = clsId;
    attentionMask[0] = 1;

    for (var i = 0; i < truncatedTokens.length; i++) {
      inputIds[i + 1] = vocab[truncatedTokens[i]] ?? unkId;
      attentionMask[i + 1] = 1;
    }

    final sepPosition = truncatedTokens.length + 1;
    inputIds[sepPosition] = sepId;
    attentionMask[sepPosition] = 1;

    return BertInputs(
      inputIds: inputIds,
      attentionMask: attentionMask,
      tokenTypeIds: tokenTypeIds,
    );
  }
}
