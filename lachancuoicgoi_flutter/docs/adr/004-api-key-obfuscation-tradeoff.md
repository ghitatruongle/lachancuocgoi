# ADR-004: API Key Obfuscation Trade-off

## Status

Accepted

## Context

La Chan Cuoc Goi uses Google Gemini API for L3 cloud analysis. The API key must be stored somewhere accessible to the app at runtime. Options considered:

### Option 1: Backend Proxy (Ideal)
```
App → Your Backend → Gemini API
              ↑
         Key stored server-side
```
**Pros:**
- Key never in APK
- Server can authenticate users
- Rate limiting, logging, analytics
- Key rotation without app update

**Cons:**
- Requires backend infrastructure
- Ongoing hosting costs
- Single point of failure
- Adds latency

### Option 2: Firebase Remote Config / Secrets Manager
```
App → Firebase → Gemini API
           ↑
      Key stored in Firebase
```
**Pros:**
- No custom backend needed
- Key can be rotated remotely
- Firebase has good security

**Cons:**
- Still requires app to fetch key at runtime
- Firebase can be reverse-engineered
- Dependency on third-party service

### Option 3: Bundle in APK with Obfuscation (Current)
```
App (APK) → Gemini API
    ↑
   Key embedded in assets
```
**Pros:**
- No backend dependency
- Works offline/without setup
- Simple architecture
- Low operational overhead

**Cons:**
- Key is extractable from APK
- Obfuscation is not encryption
- Determined attacker can recover key
- Risk if key has high quota

## Decision

For v1.6.0, accept **Option 3 (bundle in APK with XOR obfuscation)** with strict operational mitigations.

### Implementation

1. **XOR obfuscation** with 16-byte key:
   ```dart
   // lib/analysis/l3/core/api_key_obfuscator.dart
   final encoded = base64Encode(xorEncode(key, xorKey));
   ```

2. **Legacy support** for single-byte XOR (0x42):
   ```dart
   // Backward compatibility with v1.5.x builds
   if (key.startsWith('AIza') && key.length == 39) return key;
   ```

3. **Placeholder detection**:
   ```dart
   // Reject keys containing placeholder strings
   const placeholders = ['aizareplace', 'replace_me', 'your_api_key'];
   ```

4. **Validation before release**:
   ```bash
   dart run tool/validate_release_env.dart env.json
   ```

### Operational Mitigations

These mitigate the inherent risk of bundling keys:

1. **Low API quotas:** Set Gemini API quota to minimum required (e.g., 1000 requests/day)
2. **Monitoring:** Alert on unusual usage spikes
3. **Key rotation:** Rotate immediately if compromise suspected
4. **No logging:** Never log keys, prompts, or responses
5. **Secret scanner:** CI blocks commits with real keys (`tool/check_no_secrets.dart`)
6. **Pre-commit hook:** Prevents staging `env.json` or key patterns

```yaml
# .github/workflows/ci.yml
- name: Scan source and CI logs for accidental secrets
  run: dart run tool/check_no_secrets.dart ci-test.log ci-android.log ci-build.log
```

## Rationale

This trade-off is acceptable for v1.6.0 because:

1. **Quota is low:** Even if key is extracted, damage is limited by rate limits
2. **Consent-based:** Cloud analysis only happens with explicit user opt-in
3. **PII stripping:** Transcripts are redacted before sending to Gemini
4. **Migration path:** Architecture supports backend proxy later (see ADR-002)
5. **Operational controls:** Monitoring and rotation reduce risk

The team will revisit this decision when:
- User base grows beyond 10,000 active users
- Quota needs increase significantly
- Security audit reveals unacceptable risk
- Backend infrastructure becomes available

## Consequences

**Positive:**
- Simple architecture, no backend to maintain
- Works out-of-the-box for developers
- Low operational overhead
- Suitable for MVP and early adoption

**Negative:**
- Key is technically extractable from APK
- Not suitable for enterprise/high-security use cases
- Requires discipline on key management
- Risk if quota is set too high

**Mitigations in place:**
- XOR obfuscation raises effort (not a security barrier, just a delay)
- CI secret scanner prevents accidental commits
- Release validation ensures only real keys in production builds
- Privacy policy discloses cloud analysis to users

## Migration Path to Backend Proxy

When ready to migrate:

1. Create backend endpoint `/api/analyze` that holds Gemini key
2. App sends PII-stripped transcript to backend
3. Backend calls Gemini, returns analysis
4. Remove `env.json` from app assets
5. Update `ApiKeyProvider` to fetch from backend URL
6. Add certificate pinning for backend communications

See `docs/API_KEY_SECURITY.md` for detailed security guide.

## References

- `lib/analysis/l3/core/api_key_obfuscator.dart`
- `lib/analysis/l3/core/api_key_provider.dart`
- `tool/validate_release_env.dart`
- `tool/check_no_secrets.dart`
- `docs/API_KEY_SECURITY.md`
- `env.example.json`
