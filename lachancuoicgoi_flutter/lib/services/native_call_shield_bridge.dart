import 'package:flutter_riverpod/flutter_riverpod.dart';

class NativeCallShieldBridge {
  static final NativeCallShieldBridge instance = NativeCallShieldBridge();
}

final nativeBridgeProvider = Provider<NativeCallShieldBridge>((ref) {
  throw UnimplementedError();
});
