import 'dart:typed_data';
import 'asset_loader.dart';

class NoopAssetLoader implements AssetLoader {
  const NoopAssetLoader();

  @override
  Future<String> loadString(String key) async {
    return '{}';
  }

  @override
  Future<ByteData> load(String key) async {
    final list = Uint8List.fromList([123, 125]);
    return ByteData.view(list.buffer);
  }
}
