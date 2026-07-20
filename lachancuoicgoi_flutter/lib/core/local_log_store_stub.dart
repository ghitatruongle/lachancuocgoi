/// No-op store used by Web, where app-support filesystem APIs are unavailable.
class LocalLogStore {
  LocalLogStore._();

  static final LocalLogStore instance = LocalLogStore._();

  Future<void> append(String line) async {}

  Future<void> clear() async {}
}
