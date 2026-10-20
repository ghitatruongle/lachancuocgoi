import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

Future<void> initializeFirebase() async {
  if (kIsWeb) return;

  if (defaultTargetPlatform != TargetPlatform.android) return;

  try {
    await Firebase.initializeApp();

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode,
    );

    await FirebaseCrashlytics.instance.setCustomKey('appVersion', '1.6.5+16');
    await FirebaseCrashlytics.instance.setCustomKey('platform', 'android');

    debugPrint('Firebase initialized successfully');
  } on FirebaseException catch (e) {
    debugPrint('Firebase initialization failed: $e');
  } on Object catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
}
