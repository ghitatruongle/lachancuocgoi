# model-vn-small — Kế hoạch đóng gói model Vosk nhẹ (Phase 2 / P2-5)

## Mục tiêu

Giảm kích thước APK và tăng tốc cold-start Vosk trên máy yếu bằng cách ship thêm
một model Vosk tiếng Việt nhỏ hơn (`model-vn-small`) bên cạnh model đầy đủ
(`model-vn`).

## Hiện trạng

| Hạng mục | Trạng thái |
|----------|-----------|
| Model đầy đủ `assets/model-vn/` | ✅ Đã ship (~51 MB) |
| Code fallback path trong `VoskSttManager.kt` | ✅ Đã có (ưu tiên `model-vn-small` trước `model-vn`) |
| `pubspec.yaml` khai báo `assets/model-vn-small/` | ✅ Đã thêm |
| Setting toggle "model lớn / model nhỏ" | ✅ Đã thêm `useSmallSttModel` trong `SettingsState` |
| Bản thân `assets/model-vn-small/` | ❌ **Chưa có file model** — cần tải hoặc nén |

## Việc cần làm (khi có model thật)

### Bước 1 — Lấy hoặc tạo model nhỏ

**Option A:** Tải model Vosk tiếng Việt nhỏ từ Alphacephei community:
```bash
# Kiểm tra https://alphacephei.com/vosk/models — tìm bản "small" cho Vietnamese
wget https://alphacephei.com/vosk/models/vosk-model-small-vn-0.x.zip
unzip vosk-model-small-vn-0.x.zip
```

**Option B:** Nén/quantize model hiện tại (nghiên cứu docs Vosk — không phải TFLite quantize).

### Bước 2 — Giải nén vào đúng cấu trúc

```
assets/model-vn-small/
  am/
    final.mdl
  conf/
    mfcc.conf
    ivector.conf
    ...
  graph/
    HCLG.fst
    words.txt
    phones/
      ...
  ivector/
    final.dubm
    final.ie
    ...
```

**Quan trọng:** Cấu trúc folder phải giống y `model-vn/` (am/conf/graph/ivector).

### Bước 3 — Kiểm tra path order trong VoskSttManager.kt

```kotlin
private val MODEL_ASSET_PATHS = listOf(
    "flutter_assets/assets/model-vn-small",   // ← Ưu tiên small nếu có
    "model-vn-small",
    "flutter_assets/assets/model-vn",          // ← Fallback model đầy đủ
    "model-vn",
)
```

Code này **đã đúng** — khi `model-vn-small` tồn tại, Vosk sẽ ưu tiên dùng nó.
Khi chưa có, fallback xuống `model-vn` tự động.

### Bước 4 — Setting toggle

Setting `useSmallSttModel` trong `SettingsState` cho phép user chọn:
- `false` (mặc định): dùng model đầy đủ (chính xác hơn)
- `true`: dùng model nhỏ (nhẹ hơn, cold-start nhanh hơn)

Khi implement thực tế, wire setting này vào `VoskSttManager` qua MethodChannel
để thay đổi thứ tự path lúc runtime.

### Bước 5 — A/B test

Đo WER thô trên 10 câu gọi thử:
```bash
# Trước: model-vn (full)
adb logcat | grep VoskSttManager

# Sau: model-vn-small
# So sánh transcript, đếm số từ sai
```

### Bước 6 — Đo APK size

```bash
flutter build apk --release
# So sánh:
ls -lh build/app/outputs/flutter-apk/app-release.apk
```

## Lưu ý quan trọng

- **Đừng xóa `model-vn` cho đến khi `model-vn-small` đủ tốt.**
- Git LFS nếu model lớn (>50MB).
- Setting toggle chỉ ảnh hưởng khi cả hai model đều ship trong APK.
- Nếu chỉ ship 1 model, Vosk tự fallback path — setting toggle không cần thiết.

## Acceptance (khi model thật có sẵn)

- [ ] `assets/model-vn-small/` tồn tại với cấu trúc đúng
- [ ] APK size giảm rõ (ghi số MB trước/sau)
- [ ] Cold start unpack success log path small
- [ ] Không regress STT quá nặng trên 10 câu benchmark nội bộ
- [ ] Setting "model lớn/nhỏ" hoạt động (khi cả 2 model ship)
