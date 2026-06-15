class L1Config {
  const L1Config({
    this.fuzzyEnabled = true,
    this.fuzzyMaxDistance = 1,
    this.fuzzyMinLength = 5,
    this.negationRegexPattern =
        r'\b(khong phai|dau phai|chua chac|khong co|dau co|cha phai|khong can|dung co|khong dung)\b',
    this.safeBeneficiaries = const [
      'cho me',
      'cho bo',
      'cho ba',
      'cho em',
      'cho anh',
      'cho chi',
      'cho con',
      'cho chau',
      'cho ong',
      'cho vo',
      'cho chong',
      'cho nguoi nha',
      'cho nguoi than',
      'cho ban',
      'cho dong nghiep',
    ],
    this.financialIndicatorKeywords = const [
      'chuyen tien',
      'chuyen khoan',
      'gui tien',
      'nap tien',
      'rut tien',
      'ck',
      'ban tien',
      'gui ma',
      'nap the',
      'mua the',
      'thanh toan',
    ],
    this.generalSafePhrases = const [
      'noi dua',
      'troll',
      'hoi thoi',
      'tinh cuop',
      'keo di',
      'cho biet',
      'doc theo',
      'tham khao',
      'vi du',
      'gia su',
    ],
    /// Context window size (in tokens) on each side of the match for
    /// negative-lookahead filtering. Upgraded from 4 → 8 for wider context.
    this.contextWindowSize = 8,
    /// Patterns that indicate the speaker is asking a question rather than
    /// issuing a command or describing a scam event.
    this.questionContextPatterns = const [
      r'\bcho hoi\b',
      r'\blam the nao\b',
      r'\blam sao\b',
      r'\btai sao\b',
      r'\bco phai\b',
      r'\bco dung\b',
      r'\bphai khong\b',
      r'\bdung khong\b',
      r'\bthe nao\b',
      r'\bnao vay\b',
      r'\bgi vay\b',
      r'\bsao vay\b',
      r'\bhieu the nao\b',
      r'\bnghia la gi\b',
      r'\bco ai biet\b',
      r'\bcho minh hoi\b',
    ],
    /// Family / known-person references for broader safe-beneficiary matching.
    /// Unlike [safeBeneficiaries] (which are 2-word phrases), these are
    /// single-token family terms that can appear anywhere in the suffix.
    this.familyTerms = const [
      'me', 'bo', 'ba', 'ma',
      'em', 'anh', 'chi', 'cau',
      'con', 'chau', 'ong', 'ba',
      'vo', 'chong',
      'nguoi nha', 'nguoi than',
      'ban', 'dong nghiep',
      'hang xom', 'dong mon',
    ],
  });

  final bool fuzzyEnabled;
  final int fuzzyMaxDistance;
  final int fuzzyMinLength;
  final String negationRegexPattern;
  final List<String> safeBeneficiaries;
  final List<String> financialIndicatorKeywords;
  final List<String> generalSafePhrases;
  final int contextWindowSize;
  final List<String> questionContextPatterns;
  final List<String> familyTerms;
}

class L2Config {
  const L2Config({
    this.aiHighConfidenceThreshold = 0.80,
    this.aiDirectConfidence = 0.62,
    this.aiDirectMargin = 0.15,
    this.aiAssistConfidence = 0.50,
    this.aiAssistMargin = 0.08,
    this.ensembleHighConfCutoff = 0.90,
    this.ensembleHighConfAiWeight = 0.80,
    this.ensembleDefaultAiWeight = 0.60,
  });

  final double aiHighConfidenceThreshold;
  final double aiDirectConfidence;
  final double aiDirectMargin;
  final double aiAssistConfidence;
  final double aiAssistMargin;
  final double ensembleHighConfCutoff;
  final double ensembleHighConfAiWeight;
  final double ensembleDefaultAiWeight;
}
