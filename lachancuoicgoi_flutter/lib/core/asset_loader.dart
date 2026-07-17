import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract class AssetLoader {
  Future<String> loadString(String key);
  Future<ByteData> load(String key);
}

/// Wraps an [AssetLoader] with an in-memory cache for `loadString` results.
/// Text assets (JSON, vocab, config) are read once and cached — subsequent
/// reads return instantly without touching disk or the asset bundle.
///
/// Binary `load()` calls are NOT cached (TFLite model, Vosk model — large,
/// used once at init, and ByteData is already memory-backed by the OS).
class CachingAssetLoader implements AssetLoader {
  CachingAssetLoader(this._delegate);

  final AssetLoader _delegate;
  final Map<String, String> _stringCache = {};

  @override
  Future<String> loadString(String key) async {
    final cached = _stringCache[key];
    if (cached != null) return cached;
    final result = await _delegate.loadString(key);
    _stringCache[key] = result;
    return result;
  }

  @override
  Future<ByteData> load(String key) => _delegate.load(key);

  /// Clears the string cache (used when OTA updates replace assets).
  void clearCache() => _stringCache.clear();
}

class CompositeAssetLoader implements AssetLoader {
  const CompositeAssetLoader({
    required this.primary,
    required this.fallback,
  });

  final AssetLoader primary;
  final AssetLoader fallback;

  @override
  Future<String> loadString(String key) async {
    try {
      return await primary.loadString(key);
    } on Object {
      return fallback.loadString(key);
    }
  }

  @override
  Future<ByteData> load(String key) async {
    try {
      return await primary.load(key);
    } on Object {
      return fallback.load(key);
    }
  }
}

/// Phase 2 (P2-3): Loads asset files from disk (the app's
/// `getApplicationSupportDirectory()`) so that OTA-updated JSON overrides
/// can be used without shipping a new APK.
///
/// Files are stored flat in the support directory — the asset key (e.g.
/// `assets/risk_model_vocabulary.json`) is used as-is. `loadString` throws
/// if the file is missing so [CompositeAssetLoader] can fall back to the
/// bundled asset.
class DiskAssetLoader implements AssetLoader {
  DiskAssetLoader({Future<Directory> Function()? supportDirProvider})
    : _supportDirProvider =
          supportDirProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _supportDirProvider;

  Future<File> _fileFor(String key) async {
    final dir = await _supportDirProvider();
    // BUG fix (P2-3 review): RemoteConfigStore writes OTA files to the
    // `ota_config/` subdirectory — we must read from the same location.
    return File(p.join(dir.path, 'ota_config', p.basename(key)));
  }

  @override
  Future<String> loadString(String key) async {
    final file = await _fileFor(key);
    return file.readAsString();
  }

  @override
  Future<ByteData> load(String key) async {
    final file = await _fileFor(key);
    final bytes = await file.readAsBytes();
    return ByteData.sublistView(bytes);
  }
}
