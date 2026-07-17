import 'dart:async';
import 'dart:typed_data';

abstract class AssetLoader {
  Future<String> loadString(String key);
  Future<ByteData> load(String key);
}
