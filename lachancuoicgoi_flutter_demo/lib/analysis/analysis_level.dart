enum AnalysisLevel {
  l1('L1', 'Cấp 1'),
  l2('L2', 'Cấp 2'),
  l2Ai('L2-AI', 'Cấp 2 AI'),
  l2Fused('L2-Fused', 'Cấp 2 hợp nhất'),
  l3('L3', 'Cấp 3 Gemini');

  const AnalysisLevel(this.id, this.displayName);

  final String id;
  final String displayName;

  static AnalysisLevel fromId(String? value) {
    final normalized = value?.trim().toUpperCase();
    return switch (normalized) {
      'L1' => AnalysisLevel.l1,
      'L2' => AnalysisLevel.l2,
      'L2AI' || 'L2-AI' => AnalysisLevel.l2Ai,
      'L2FUSED' || 'L2-FUSED' => AnalysisLevel.l2Fused,
      'L3' => AnalysisLevel.l3,
      _ => AnalysisLevel.l1,
    };
  }
}
