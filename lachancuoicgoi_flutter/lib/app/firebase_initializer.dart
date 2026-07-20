import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Initializes Firebase services for crash reporting and analytics.
///
/// Only initializes on Android (production target). iOS/desktop use
/// [SimulatorCallShieldBridge] and do not require crash reporting.
///
/// This must be called before [runApp] to ensure crashlytics is ready
/// for the entire app lifecycle.
Future<void> initializeFirebase() async {
  if (kIsWeb) return;

  // Only initialize on Android for now. iOS/macOS/Linux/Windows/Web use
  // simulator bridge and don't need Firebase crash reporting in v1.6.0.
  if (defaultTargetPlatform != TargetPlatform.android) return;

  try {
    await Firebase.initializeApp();

    // Enable crashlytics collection by default for release builds.
    // In debug/dev builds, you may want to disable to avoid test noise.
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode,
    );

    // Set custom keys for context in Crashlytics dashboard
    await FirebaseCrashlytics.instance.setCustomKey('appVersion', '1.6.0+14');
    await FirebaseCrashlytics.instance.setCustomKey('platform', 'android');

    debugPrint('Firebase initialized successfully');
  } on FirebaseException catch (e) {
    // Firebase may not be configured in dev/test environments.
    // Log but don't crash — app should still function without crash reporting.
    debugPrint('Firebase initialization failed: $e');
  } on Object catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
}
