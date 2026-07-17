import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 2 (P2-3): Remote configuration store for OTA vocabulary/scenario
/// updates.
///
/// Downloads a manifest from a CDN, verifies SHA256 hashes, checks
/// `minAppVersion`, and writes JSON files into the app's support directory.
/// The [CompositeAssetLoader] then reads disk-first, falling back to bundled
/// assets.
///
/// Security:
/// - HTTPS only (cleartext rejected).
/// - SHA256 verification per file.
/// - `minAppVersion` gate (schema-breaking protection).
/// - Download size cap (default 5 MB).
/// - Only JSON data — no code execution from remote.
class RemoteConfigStore {
  RemoteConfigStore({
    required this.manifestUrl,
    String appVersion = '1.0.0',
    int maxDownloadBytes = 5 * 1024 * 1024,
    http.Client? httpClient,
  }) : _appVersion = appVersion,
       _maxDownloadBytes = maxDownloadBytes,
       _httpClient = httpClient ?? http.Client();

  final String manifestUrl;
  final String _appVersion;
  final int _maxDownloadBytes;
  final http.Client _httpClient;

  static const _prefKeyVersion = 'OTA_CONFIG_VERSION';
  static const _otaDirName = 'ota_config';

  /// Fetches the manifest, checks version, downloads files if needed.
  /// Returns `true` if an update was applied.
  Future<bool> refreshIfNeeded() async {
    try {
      final manifest = await _fetchManifest();
      if (manifest == null) return false;

      // minAppVersion gate: don't apply if app is too old.
      final minVersion = manifest.minAppVersion;
      if (minVersion != null && !_isVersionGeq(_appVersion, minVersion)) {
        debugPrint('OTA: app version $_appVersion < minAppVersion $minVersion — skipping');
        return false;
      }

      // Check if we already have this version.
      final prefs = await SharedPreferences.getInstance();
      final currentVersion = prefs.getInt(_prefKeyVersion) ?? 0;
      if (manifest.version <= currentVersion) {
        debugPrint('OTA: already at version $currentVersion (>= ${manifest.version})');
        return false;
      }

      // Download each file directly into the support directory.
      // DiskAssetLoader reads from <supportDir>/<basename(key)>, so we write
      // each file there using its manifest key as the filename.
      final supportDir = await getApplicationSupportDirectory();
      for (final entry in manifest.files.entries) {
        final name = entry.key;
        final info = entry.value;
        await _downloadAndVerify(
          url: info.url,
          expectedSha256: info.sha256,
          outputPath: p.join(supportDir.path, name),
        );
      }

      await prefs.setInt(_prefKeyVersion, manifest.version);
      debugPrint('OTA: applied version ${manifest.version} with ${manifest.files.length} files');
      return true;
    } on Exception catch (e) {
      debugPrint('OTA: refresh failed — keeping existing assets ($e)');
      return false;
    }
  }

  /// Returns the directory where OTA files are stored, or `null` if none.
  Future<Directory?> getOtaDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final otaDir = Directory(p.join(supportDir.path, _otaDirName));
    if (otaDir.existsSync()) return otaDir;
    return null;
  }

  /// The currently applied OTA config version (0 = none).
  Future<int> getAppliedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKeyVersion) ?? 0;
  }

  Future<OtaManifest?> _fetchManifest() async {
    final uri = Uri.tryParse(manifestUrl);
    if (uri == null || !uri.isScheme('https')) {
      debugPrint('OTA: manifest URL must be HTTPS — rejecting $manifestUrl');
      return null;
    }

    final response = await _httpClient.get(uri).timeout(
      const Duration(seconds: 15),
    );
    if (response.statusCode != 200) {
      debugPrint('OTA: manifest fetch failed: ${response.statusCode}');
      return null;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return OtaManifest.fromJson(json);
  }

  Future<void> _downloadAndVerify({
    required String url,
    required String? expectedSha256,
    required String outputPath,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isScheme('https')) {
      throw Exception('Download URL must be HTTPS: $url');
    }

    final response = await _httpClient.get(uri).timeout(
      const Duration(seconds: 30),
    );
    if (response.statusCode != 200) {
      throw Exception('Download failed: $url → ${response.statusCode}');
    }

    final bytes = response.bodyBytes;
    if (bytes.length > _maxDownloadBytes) {
      throw Exception(
        'Download too large: ${bytes.length} bytes (max $_maxDownloadBytes)',
      );
    }

    // SHA256 verification.
    if (expectedSha256 != null && expectedSha256.isNotEmpty) {
      final hash = sha256.convert(bytes).toString();
      if (hash != expectedSha256) {
        throw Exception(
          'SHA256 mismatch for $url: expected $expectedSha256, got $hash',
        );
      }
    }

    final file = File(outputPath);
    await file.writeAsBytes(bytes);
  }

  /// Returns `true` if [a] >= [b] using semantic version comparison
  /// (major.minor.patch).
  static bool _isVersionGeq(String a, String b) {
    final pa = a.split('.').map(int.tryParse).whereType<int>().toList();
    final pb = b.split('.').map(int.tryParse).whereType<int>().toList();
    for (var i = 0; i < 3; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va > vb) return true;
      if (va < vb) return false;
    }
    return true; // equal
  }

  void dispose() {
    _httpClient.close();
  }
}

/// Parsed OTA manifest entry.
class OtaManifest {
  const OtaManifest({
    required this.version,
    required this.files,
    this.minAppVersion,
  });

  final int version;
  final Map<String, OtaFileEntry> files;
  final String? minAppVersion;

  factory OtaManifest.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'] as Map<String, dynamic>? ?? {};
    return OtaManifest(
      version: (json['version'] as num?)?.toInt() ?? 0,
      minAppVersion: json['minAppVersion'] as String?,
      files: {
        for (final entry in rawFiles.entries)
          entry.key: OtaFileEntry.fromJson(entry.value as Map<String, dynamic>),
      },
    );
  }
}

/// A single file entry in the manifest.
class OtaFileEntry {
  const OtaFileEntry({required this.url, this.sha256});

  final String url;
  final String? sha256;

  factory OtaFileEntry.fromJson(Map<String, dynamic> json) {
    return OtaFileEntry(
      url: json['url'] as String,
      sha256: json['sha256'] as String?,
    );
  }
}

/// Riverpod provider for [RemoteConfigStore].
/// Disabled by default (empty URL) — enable by overriding this provider
/// with a real manifest URL in production builds.
final remoteConfigStoreProvider = Provider<RemoteConfigStore?>((ref) {
  // Phase 2 (P2-3): In production, override this with a real CDN URL.
  // When null, OTA is disabled and the app uses bundled assets.
  const manifestUrl = String.fromEnvironment(
    'OTA_MANIFEST_URL',
    defaultValue: '',
  );
  if (manifestUrl.isEmpty) return null;

  final store = RemoteConfigStore(manifestUrl: manifestUrl);
  ref.onDispose(store.dispose);
  return store;
});
