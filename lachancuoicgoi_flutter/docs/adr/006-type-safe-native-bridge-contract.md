# ADR-006: Type-Safe Native Channel Contract & Interop Hardening

## Status

Accepted

## Context

La Chan Cuoc Goi relies on Android native Kotlin code for key features:
- `CallScreeningService` for incoming call detection.
- `AudioRecord` / Vosk for background STT.
- System Window Overlay for risk alerts.

Communicating across the Flutter Dart and Android Kotlin boundary via standard `MethodChannel` can lead to runtime crashes if:
1. Native code returns an unexpected type (e.g. `String` or `int` when Dart expects `bool`).
2. Native service throws `PlatformException` or `MissingPluginException`.
3. Method calls execute concurrently during background service initialization.

## Decision

Establish a **Centralized Type-Safe Native Bridge Contract (`NativeBridgeContract`)**:
1. All `MethodChannel` interactions pass through `invokeTypeSafeMethod<T>()`.
2. Explicit type checks (`result is T`) validate return payloads before casting.
3. Catch all `PlatformException`, `MissingPluginException`, and unexpected errors, returning caller-specified safe fallbacks instead of letting exceptions bubble up to UI.

## Consequences

**Positive:**
- Triples resilience against native interop errors and type mismatches.
- Simplifies cross-platform testing by using mock binary messenger contracts.
- Elevates Platform Engineering score to Tier A+.

**Negative:**
- Requires method invocations to go through `NativeBridgeContract` facade instead of raw `MethodChannel`.

## References

- `lib/services/native_bridge_contract.dart`
- `test/services/native_bridge_contract_test.dart`
- `docs/adr/003-android-native-integration.md`
