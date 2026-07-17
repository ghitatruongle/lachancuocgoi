# P2-SEC: Bảo mật API Key — Hướng dẫn Backend Proxy

## Vấn đề

`env.json` nằm trong `assets/` và bị **bundle trực tiếp trong APK**. Bất kỳ ai
cài app cũng có thể extract file này qua `apktool` hoặc `strings`. XOR
obfuscation (`api_key_obfuscator.dart`) chỉ làm chậm reverse engineering vài
phút — không phải bảo vệ thật.

## Giải pháp: Backend Proxy

Thay vì gọi Gemini trực tiếp từ app, app gọi qua backend nhỏ. Backend giữ
API key, app chỉ gửi transcript **đã strip PII** + Firebase App Check token.

### Kiến trúc

```
App (Flutter)                        Backend (Cloud Function/Run)
  │                                    │
  ├─ POST /analyze                     ├─ Verify App Check token
  │  { transcript: "..." }             ├─ Strip PII lần 2 (defense in depth)
  │  Header: App-Check-Token: ...      ├─ Gọi Gemini API (key ở server)
  │                                    ├─ Parse response
  │  ←─ 200 { level, reason, ... }     ├─ Return JSON
  └─ Fallback: L1+L2 offline           └─ Rate limit / logging
```

### Đã implement (Phase 2)

- **`lib/analysis/l3/core/proxy_l3_client.dart`** — `ProxyL3Executor`
  thay thế `_defaultRequestExecutor` trong `GeminiClient`.
  App gửi HTTPS POST thay vì gọi `google_generative_ai` trực tiếp.
  Circuit breaker của `GeminiClient` vẫn hoạt động (khi backend down).

### Cách bật proxy trong production

```dart
// Thay vì:
final client = GeminiClient(
  apiKeyProvider: provider,
  config: GeminiConfig.forAnalysis(),
);

// Dùng:
import 'package:http/http.dart' as http;
final proxyExecutor = ProxyL3Executor(
  endpoint: Uri.parse('https://your-backend.com/analyze'),
  httpClient: http.Client(),
  appCheckToken: () async => await getAppCheckToken(), // Firebase App Check
);
final client = GeminiClient(
  apiKeyProvider: provider, // vẫn cần cho fallback / testing
  config: GeminiConfig.forAnalysis(),
  requestExecutor: proxyExecutor.execute, // ← inject proxy
);
```

### Backend tham khảo (Cloud Function)

```python
# main.py — Google Cloud Functions
import functions_framework
import google.generativeai as genai
from flask import jsonify, request

GENAI_API_KEY = "AIza..."  # Chỉ ở server, không bao giờ ship trong app
genai.configure(api_key=GENAI_API_KEY)

@functions_framework.http
def analyze(request):
    # 1. Verify App Check token
    app_check_token = request.headers.get("App-Check-Token")
    if not verify_app_check(app_check_token):
        return jsonify({"error": "unauthorized"}), 401

    # 2. Parse + strip PII (defense in depth)
    data = request.get_json()
    transcript = strip_pii(data.get("transcript", ""))

    # 3. Call Gemini
    model = genai.GenerativeModel("gemini-3.5-flash")
    response = model.generate_content(build_prompt(transcript))

    # 4. Return structured JSON
    return jsonify(parse_response(response.text))
```

### Checklist migration

- [ ] Deploy backend (Cloud Function / Cloud Run)
- [ ] Wire `ProxyL3Executor` vào `L3Analyzer` factory
- [ ] Thêm Firebase App Check
- [ ] Xóa `env.json` khỏi `pubspec.yaml` assets
- [ ] Rotate toàn bộ key đã từng ship trong APK
- [ ] Test: `strings app-release.apk | grep AIza` → không còn kết quả
- [ ] Test: backend down → circuit breaker hoạt động, L1+L2 vẫn chạy

### Lưu ý

- App vẫn giữ `ApiKeyProvider` cho **testing** và **fallback**.
- Trong release build, `env.json` KHÔNG được bundle — chỉ backend có key.
- Circuit breaker (`GeminiClient` + `CircuitBreaker`) đảm bảo khi backend down,
  L3 fail-fast và pipeline fallback sang L1+L2 offline.
