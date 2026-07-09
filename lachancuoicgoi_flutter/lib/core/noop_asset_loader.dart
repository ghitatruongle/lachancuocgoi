// BUG-L2-5 fix: Noop AssetLoader that returns empty/safe defaults.
//
// Used as a safe default when no real AssetLoader is provided. Prevents
// StateError throws in production code. L2 analyzers will gracefully degrade
// to zero-vocabulary mode (only L1 + L3 analysis will run).

import 'dart:typed_data';
import 'asset_loader.dart';

/// No-op implementation of [AssetLoader] that always returns empty data.
///
/// This is a safe fallback when no real asset loader is provided to L2
/// analysis components. Rather than throwing StateError, the system will
/// continue with degraded functionality (vocabulary-based detection disabled).
class NoopAssetLoader implements AssetLoader {
  const NoopAssetLoader();

  @override
  Future<String> loadString(String key) async {
    return '{}';
  }

  @override
  Future<ByteData> load(String key) async {
    // Return empty ByteData (2 bytes for "{}")
    final list = Uint8List.fromList([123, 125]); // ASCII for "{}"
    return ByteData.view(list.buffer);
  }
}
