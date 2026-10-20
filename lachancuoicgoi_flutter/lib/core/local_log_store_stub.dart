class LocalLogStore {
  LocalLogStore._();

  static final LocalLogStore instance = LocalLogStore._();

  Future<void> append(String line) async {}

  Future<void> clear() async {}
}
