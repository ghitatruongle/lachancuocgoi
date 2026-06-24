# SECURITY — Rotate API Keys & Clean Git History

> ⚠️ **KHẨN CẤP**: 21 API keys Gemini đã từng được commit vào git history của repo này. Bất kỳ ai có quyền truy cập repo đều có thể extract keys qua `git log -- env.json`. **Phải rotate keys trên Google Cloud Console TRƯỚC khi clean git history.**

---

## 🔴 Tại sao đây là vấn đề nghiêm trọng

- **Quota theft**: Người khác dùng keys → quota bị trừ hết → app bị block
- **Billing risk**: Nếu vượt free tier, có thể phát sinh chi phí
- **ToS violation**: Google Cloud Terms of Service cấm commit keys vào public repo
- **Account ban**: Google có thể suspend project nếu phát hiện lạm dụng

---

## 📋 Manual Steps (PHẢI làm thủ công)

### Step 1: Rotate tất cả 21 keys trên Google Cloud Console

1. Truy cập: https://console.cloud.google.com/apis/credentials
2. Với **mỗi** trong 21 keys (tên `la-chan-cuoc-goi`, `la-chan-cuoc-goi-1`, ... `la-chan-cuoc-goi-20`):
   - Click vào key
   - **Disable** key (hoặc **Delete** — không thể khôi phục)
3. Tạo 21 keys mới:
   - Click **+ CREATE CREDENTIALS** → **API key**
   - Restrict key: chỉ cho phép **Generative Language API**
   - Đặt tên: `la-chan-cuoc-goi` (giữ nguyên convention)
4. **KHÔNG commit keys mới vào git**. Cập nhật file `env.json` ở local (file này đã có trong `.gitignore`).

### Step 2: Verify `.gitignore` đã có `env.json`

Kiểm tra file `.gitignore` ở root có dòng:

```
env.json
.env
.env.*
```

✅ Đã có sẵn (xem [`.gitignore`](../../.gitignore) line 49).

### Step 3: Xác nhận `env.json` không bị commit trong tương lai

```bash
# Phải báo "no changes" (file đã ở local, không bị track)
git status env.json

# Nếu vẫn bị track (do commit cũ), untrack ngay:
git rm --cached env.json
```

### Step 4: Clean git history bằng BFG Repo Cleaner

⚠️ **Cảnh báo**: BFG thay đổi git history — tất cả collaborators phải `git pull --rebase` sau đó.

```bash
# Cài BFG (Java cần thiết)
# macOS:   brew install bfg
# Linux:   apt install bfg
# Windows: tải jar từ https://rtyley.github.io/bfg-repo-cleaner/

# Backup trước khi clean (an toàn)
cp -r .git .git-backup

# Chạy BFG xoá env.json khỏi toàn bộ history
bfg --delete-files env.json
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push (cảnh báo collaborators trước)
git push --force --all
git push --force --tags
```

### Step 5: Verify

```bash
# Không được có kết quả (env.json đã bị xoá khỏi history)
git log --all --full-history -- env.json

# Scan toàn bộ history xem còn sót AIza key nào không
git log --all -p | grep -i "AIza" || echo "✅ Clean"

# (Tuỳ chọn) Dùng tool chuyên: trufflehog, gitleaks, git-secrets
gitleaks detect --source . --verbose
```

---

## 🛡️ Phòng ngừa tương lai (đã có trong code)

### a) `env.example.json` template

File [env.example.json](../../env.example.json) là template an toàn, đã được commit vào git. Khi dev mới cần keys:

```bash
cp env.example.json env.json
# Sửa env.json với keys thật (do team lead cấp)
```

### b) Placeholder detection trong code

`EnvironmentApiKeyProvider` ([`lib/analysis/l3/core/api_key_provider.dart`](../../lib/analysis/l3/core/api_key_provider.dart)) tự động phát hiện và bỏ qua các placeholder keys (`AIzaReplace...`, `REPLACE_ME`, etc.) khi load `env.json`. Nếu dev commit nhầm `env.example.json` thay vì `env.json` thật, app sẽ:

1. Log warning: `SECURITY: Bỏ qua N placeholder key(s) trong env.json`
2. Không gọi được Gemini API → fail rõ ràng, dev nhận ra ngay

### c) Runtime warning khi load từ assets

Trong release mode, app sẽ log:

```
🚨 SECURITY WARNING: env.json đang được bundle trong APK release.
Bất kỳ ai cài app đều có thể extract API keys.
Hãy move env.json ra app documents directory và rotate keys.
```

### d) Git pre-commit hook (khuyến nghị thêm)

Tạo file `.git/hooks/pre-commit`:

```bash
#!/bin/sh
# Block commit nếu env.json chứa AIza key thật
if git diff --cached --name-only | grep -q "^env.json$"; then
  echo "❌ BLOCKED: env.json không được commit!"
  echo "   Nếu bạn thật sự cần commit (rare), dùng: git commit --no-verify"
  exit 1
fi
```

Hoặc dùng tool [gitleaks](https://github.com/gitleaks/gitleaks):

```bash
# Cài và chạy pre-commit scan
brew install gitleaks
gitleaks protect --staged --verbose
```

---

## 📞 Liên hệ

Nếu phát hiện key bị lộ ngoài repo này, liên hệ team lead ngay để rotate khẩn cấp.

---

_Last updated: 2026-06-12 — Bug #1 fix triệt để (code-side done, manual steps pending)._
