final RegExp _opaqueGeminiKeyPattern = RegExp(
  r'^[A-Za-z0-9_-]{2}\.[A-Za-z0-9_-]{50}$',
);

bool isSupportedGeminiKey(String value) {
  return value.startsWith('AIza') || _opaqueGeminiKeyPattern.hasMatch(value);
}

bool isReleaseGeminiKey(String value) {
  return (value.startsWith('AIza') && value.length >= 30) ||
      _opaqueGeminiKeyPattern.hasMatch(value);
}
