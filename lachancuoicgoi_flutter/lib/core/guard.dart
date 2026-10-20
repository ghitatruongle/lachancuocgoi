class Guard {
  bool _locked = false;
  int _generation = 0;

  bool tryLock() {
    if (_locked) return false;
    _locked = true;
    return true;
  }

  void unlock() {
    _locked = false;
  }

  bool get isLocked => _locked;

  int get generation => _generation;

  int advanceGeneration() => ++_generation;

  void reset() {
    _locked = false;
    _generation = 0;
  }
}
