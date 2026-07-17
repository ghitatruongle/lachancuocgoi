/// Shared test-tags constants.
///
/// Use `@Tags(testTags.perf)` on slow benchmark tests so the default CI
/// invocation can exclude them with `flutter test --exclude-tags perf`.
library;

/// Tag used for slow performance/benchmark tests that should not run in
/// every CI invocation. Run them with `flutter test --tags perf`.
const List<String> perf = ['perf'];
