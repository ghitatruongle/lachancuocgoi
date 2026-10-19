# Play / store policy notes (v1.6.5)

## Platform honesty

| Platform | Full call shield | Notes |
|----------|------------------|-------|
| Android | Yes (STT, overlay, screening) | Production target |
| iOS | AI preview / simulator only | Do not claim live call blocking |
| Web/Desktop | Simulator only | Demo |

## Sensitive capabilities

- **Microphone:** required for real-time transcript on Android.
- **Overlay:** scam alerts over other apps.
- **Call screening:** optional number-level protection.
- **Accessibility:** optional; **call control (answer/end) default OFF** in v1.6.5. Detection/caption paths must not require control clicks.
- **Cloud L3:** optional; requires explicit consent; PII stripped before Gemini; keys bundled in APK (engineering risk accepted — see threat model).

## Listing claims to avoid

- “Blocks all scam calls on iOS”
- “Never sends any data” while L3 enabled
- “Bank-grade encrypted API keys in the app” (obfuscation ≠ encryption)

## Listing claims OK

- On-device keyword + AI analysis
- Optional cloud analysis with consent
- Android real-time monitoring with user permissions
