# Lên Max Điểm — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

---

## 📊 Tiến độ thực thi (Execution Progress)

> Cập nhật lần cuối: 2026-06-24

| Phase | Trạng thái | Commit(s) | Ghi chú |
|-------|-----------|-----------|---------|
| **Phase 0** — Baseline Lock & Format Fix | ✅ HOÀN THÀNH | `1a3bffc9`, `5d2743d4`, `94b3608e` | 152 file formatted, tag `baseline-87k`, 6 curly_braces lints fixed. `dart analyze` 0 issues, `flutter test` 1331/1331. |
| **Phase 1** — Security: Rotate Keys + BFG History Rewrite | ✅ HOÀN THÀNH | (force-pushed rewrite) | 21 keys rotated (manual), BFG scrubbed AIza + env.json từ toàn bộ history, `git gc --aggressive`, force-push origin. Verified: 0 real keys in history, 1331 tests pass. |
| **Phase 2** — Commit Hygiene + Pre-commit Hook | ✅ HOÀN THÀNH | `6b01739a` | Pre-commit hook (chặn env.json + AIza), `tool/install-hooks.sh`, `tool/pre-commit.template`, Conventional Commits trong `CONTRIBUTING.md`. |
| **Phase 3** — Dependency Upgrades | ✅ HOÀN THÀNH | `41fdcadb`, `76a04842`, `3398f2ed`, `ae3a41b6` | riverpod 2.6→3.3 (Override import + ref.mounted fix), go_router 14.8→17.3 (clean), permission_handler 11.4→12.0 (clean), dropped path_provider_android override. 0 issues, 1331/1331. |
| **Phase 4** — Refactor File Lớn | ⬜ CHỜ | — | |
| **Phase 5** — Simulator Bridge Expansion | ⬜ CHỜ | — | |
| **Phase 6** — Docs + Final Verification | ⬜ CHỜ | — | |

**Baseline metrics (sau Phase 0-2):**
- `dart analyze lib/ test/` → **No issues found!** (0 errors, 0 warnings, 0 info)
- `dart format --check lib/ test/` → **0 changed** (clean)
- `flutter test --exclude-tags perf` → **1331/1331 passed**
- Git history: 0 real API keys, env.json scrubbed
- Pre-commit hook: active (chặn env.json + AIza keys)

---

**Goal:** Đưa dự án "Lá Chắn Cuộc Gọi" (Flutter) từ 87 000 / 100 000 lên ≥ 98 000 bằng cách đóng 5 khoảng cách điểm đã đo được: rò rỉ API key trong git history, commit hygiene yếu, dependencies cũ, file quá lớn chưa tách, và phạm vi platform hẹp.

**Architecture:** Kế hoạch chia 7 phase độc lập, mỗi phase tự sinh ra một codebase testable và commit được. Phase 0 (baseline lock) chốt sàn điểm trước; Phase 1 (security) là ROI lớn nhất (−6 500 điểm). Các phase còn lại (commit hygiene, upgrade deps, refactor file lớn, mở rộng simulator bridge, docs) cộng dồn phần còn lại. Mọi thay đổi mã đều theo TDD: test đỏ → implement → test xanh → commit.

**Tech Stack:** Flutter 3.44 stable, Dart ≥3.9, flutter_riverpod, go_router, permission_handler, sqflite, tflite_flutter, BFG Repo-Cleaner (Java 17 đã có sẵn tại `C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot`), GitHub Actions.

**Environment notes (Windows / cmd.exe):**
- Java 17 đã có: `where java` → `C:\Program Files\Eclipse Adaptium\jdk-17.0.19.10-hotspot\bin\java.exe`.
- BFG chưa có trên PATH — Phase 1 sẽ download `bfg.jar`.
- Remote: `https://github.com/ghitatruongle/lachancuocgoi.git`.
- Về cơ bản 1 contributor (22 commit `ghitatruongle`), nên force-push an toàn nhưng vẫn cần thông báo trước.
- Các command dùng cú pháp `cmd.exe`. Trên bash/Git Bash thì thay `copy`→`cp`, `mkdir`→`mkdir -p`.

---

## Bảng khoảng cách điểm (đo lại tại thời điểm lập kế hoạch)

| Khoảng cách | Nguyên nhân | Điểm mất | Phase xử lý |
|-------------|-------------|----------|-------------|
| Bảo mật | 253 occurrences `AIza` trong git history; 21 keys extract được | 6 500 | Phase 1 |
| Kiểm thử/format | `dart format` báo 152/236 file drift (CI format check đang FAIL thật) | 1 000 | Phase 0 |
| Quy trình | Commit message rỗng (`Update`, `23062026`) | 1 000 | Phase 2 |
| Dependencies | riverpod 2→3, go_router 14→17, permission_handler 11→12 | 1 000 | Phase 3 |
| Kiến trúc | 4 file >650 LOC chưa tách (scam_graph_builder 1050, l1_analysis 783, native_call_shield_bridge 736, g_thinking 689) | 1 500 | Phase 4 |
| Phạm vi platform | iOS/Desktop chỉ là simulator bridge rút gọn | 1 000 | Phase 5 |
| Tài liệu | ROADMAP/CHANGELOG chưa cập nhật roadmap max-điểm | 500 | Phase 6 |

> Tổng điểm có thể phục hồi ≈ 12 500 → mục tiêu **≥ 98 000**. Lệch số so với 100 000 − 87 000 = 13 000 là do trùng lặp giữa "format" và "kiểm thử" (cùng nhóm).

---

## File Structure (tổng quan các file sẽ tạo/sửa)

```
docs/superpowers/plans/2026-06-24-max-score-roadmap.md   # (file này)
.git/hooks/pre-commit                                       # Tạo — chặn commit env.json
tool/format_check.bat                                       # Tạo — wrapper format cho Windows
tool/bfg-clean.sh                                           # Tạo — script BFG one-shot
bfg-1.14.0.jar                                              # Tạo (download) — dùng ở Phase 1, xóa sau
secrets-replacement.txt                                     # Tạo — BFG replace-text patterns
lib/analysis/l1/l1_analysis.dart                            # Sửa — tách module (Phase 4)
lib/analysis/l1/matchers/keyword_matcher_service.dart       # Tạo (Phase 4)
lib/analysis/l1/matchers/risk_density_service.dart          # Tạo (Phase 4)
lib/analysis/l1/scoring/l1_scorer.dart                      # Tạo (Phase 4)
lib/analysis/l2/wfsa/scam_graph_builder.dart                # Sửa — tách (Phase 4)
lib/analysis/l2/wfsa/scam_graph_nodes.dart                  # Tạo (Phase 4)
lib/analysis/l2/wfsa/scam_graph_edges.dart                  # Tạo (Phase 4)
lib/services/native_call_shield_bridge.dart                 # Sửa — tách (Phase 4)
lib/services/android/bridge_state_machine.dart              # Tạo (Phase 4)
lib/services/android/method_channel_codec.dart              # Tạo (Phase 4)
lib/services/simulator_call_shield_bridge.dart              # Sửa — mở rộng (Phase 5)
lib/services/simulator/simulator_creator_mode.dart          # Tạo (Phase 5)
lib/services/simulator/simulator_permission_gate.dart       # Tạo (Phase 5)
.github/workflows/ci.yml                                    # Sửa — thêm matrix iOS/Desktop (Phase 5)
CHANGELOG.md, KEHOACH.md, README.md                         # Sửa (Phase 6)
```

---

# Phase 0 — Baseline Lock & Format Fix (chốt sàn điểm)

**Mục tiêu:** (1) khóa baseline xanh (analyze 0 + test xanh) vào một tag để mọi phase sau có mốc rollback; (2) sửa regress `dart format` đang làm CI đỏ.

**Thời gian ước tính:** 20 phút.

### Task 0.1: Xác nhận baseline xanh

- [ ] **Step 1: pub get + analyze lib + test**

Run:
```
cd /d E:\lachancuocgoi\lachancuoicgoi_flutter
flutter pub get
dart analyze lib/ test/
```
Expected: `No issues found!` cho cả hai.

- [ ] **Step 2: chạy fast test suite**

Run:
```
flutter test --exclude-tags perf
```
Expected: `All tests passed!` (≈ 1331 test, thời gian ~1 phút).

- [ ] **Step 3: nếu Step 1/2 FAIL → dừng kế hoạch, sửa trước**

Ghi chú: trong environment hiện tại, analyze chỉ xanh SAU `flutter pub get`. Lần analyze đầu báo 2214 error là do package-config lỗi thời — không phải lỗi dự án. Luôn `pub get` trước.

### Task 0.2: Sửa regress dart format (152 file drift)

**Files:**
- Modify: 152 file trong `lib/` và `test/` (tự động)

- [ ] **Step 1: đo lại số file drift (xác nhận)**

Run:
```
dart format --output=none --set-exit-if-changed lib/ test/
```
Expected: exit code 1, in ra `Formatted 236 files (152 changed)`. Đây chính là lý do CI `Verify formatting` đang fail.

- [ ] **Step 2: format toàn bộ**

Run:
```
dart format lib/ test/
```
Expected: `Formatted 236 files (236 changed) ... 0 changed` ở lần chạy lại.

- [ ] **Step 3: verify không còn drift**

Run:
```
dart format --output=none --set-exit-if-changed lib/ test/
```
Expected: exit code 0, không in file nào.

- [ ] **Step 4: analyze + test lại để chắc format không vỡ gì**

Run:
```
dart analyze lib/ test/
flutter test --exclude-tags perf
```
Expected: `No issues found!` + `All tests passed!`.

- [ ] **Step 5: commit**

```
git add lib/ test/
git commit -m "style: apply dart format to 152 drifted files

The CI 'Verify formatting' step was failing because 152/236 files had
drifted from dart format. Reformat the whole lib/ and test/ tree so the
fast-fail format check in ci.yml passes again."
```

### Task 0.3: Tạo wrapper format cho Windows + khóa baseline thành tag

**Files:**
- Create: `tool/format_check.bat`

- [ ] **Step 1: tạo wrapper**

Nội dung `tool/format_check.bat`:
```bat
@echo off
REM Wrapper cho dart format check — dùng trên Windows cho dev local.
REM Mirror CI step "Verify formatting" trong .github/workflows/ci.yml.
dart format --output=none --set-exit-if-changed lib/ test/
```

- [ ] **Step 2: commit wrapper**

```
git add tool/format_check.bat
git commit -m "tool: add format_check.bat wrapper for Windows dev"
```

- [ ] **Step 3: tag baseline**

```
git tag baseline-87k
git log --oneline -5
```
Expected: thấy 2 commit mới + tag `baseline-87k` tại HEAD. Mọi phase sau rollback được về đây bằng `git reset --hard baseline-87k`.

---

# Phase 1 — Security: Rotate Keys + BFG History Rewrite (ROI lớn nhất)

**Mục tiêu:** Xóa triệt để 21 API keys Gemini khỏi toàn bộ git history. Đây là khoảng cách điểm lớn nhất (−6 500) VÀ là lỗ hổng đang hoạt động (bất kỳ ai có repo đều extract được keys).

**Bản chất:** `git ls-files env.json` → trống (file hiện không bị track ✓). Nhưng `git log --all -p | grep -c AIza` → 253. Keys nằm trong các commit cũ.

**THỨ TỰ BẮT BUỘC:** Step 1 (rotate) PHẢI làm TRƯỚC Step 4 (rewrite history). Rewrite mà chưa rotate thì keys cũ vẫn dùng được cho đến khi... vẫn dùng được (vì đã lộ). Đảo ngược thứ tự = vô dụng.

**Thời gian ước tính:** 60–90 phút (phần lớn là manual rotate trên Google Cloud Console).

### Task 1.1: Rotate 21 keys trên Google Cloud Console (MANUAL — không tự động được)

- [ ] **Step 1: mở Google Cloud Console**

Truy cập: https://console.cloud.google.com/apis/credentials

- [ ] **Step 2: disable/delete 21 key cũ**

Với mỗi key tên `la-chan-cuoc-goi`, `la-chan-cuoc-goi-1` ... `la-chan-cuoc-goi-20`:
1. Click vào key.
2. **Disable** (tạm thời) hoặc **Delete** (không khôi phục được). Khuyến nghị Disable trước, Delete sau khi xác nhận app chạy ổn với key mới.

- [ ] **Step 3: tạo 21 key mới**

Với mỗi key cũ:
1. **+ CREATE CREDENTIALS** → **API key**.
2. Restrict key: chỉ cho phép **Generative Language API**.
3. Đặt tên đúng convention `la-chan-cuoc-goi`, `-1` ... `-20`.

- [ ] **Step 4: cập nhật env.json LOCAL (không commit)**

```
copy env.json env.json.rotated.bak
```
Mở `env.json`, thay 21 giá trị cũ bằng 21 key mới. File này đã trong `.gitignore` (line 48) — `git status env.json` phải báo nothing.

- [ ] **Step 5: verify app vẫn chạy với key mới**

```
flutter run
```
Expected: app khởi động, gọi được Gemini (test simulation mode). Nếu L3 báo lỗi key → quay lại Step 3 kiểm tra restriction.

- [ ] **Step 6: đánh dấu checklist rotate hoàn tất**

KHÔNG commit gì trong task này. Ghi nhận: "21 key cũ disabled, 21 key mới đã verify chạy được." Mới được đi tiếp Task 1.2.

### Task 1.2: Backup .git trước khi rewrite history

- [ ] **Step 1: backup toàn bộ .git**

Run:
```
cd /d E:\lachancuocgoi\lachancuoicgoi_flutter
xcopy /E /I /Y .git .git-backup-pre-bfg
```
Expected: thư mục `.git-backup-pre-bfg` tạo ra, kích thước ≈ `.git`. Nếu rewrite sai, restore bằng `rmdir /S /Q .git` rồi `rename .git-backup-pre-bfg .git`.

- [ ] **Step 2: ghi lại SHA HEAD hiện tại để đối chiếu sau**

Run:
```
git rev-parse HEAD
```
Ghi lại SHA (gọi là `SHA_BEFORE`). Expected: một hash 40 ký tự.

### Task 1.3: Download BFG Repo-Cleaner

**Files:**
- Create: `bfg-1.14.0.jar` (download, xóa ở Task 1.6)

- [ ] **Step 1: download bfg.jar vào thư mục dự án**

Run (PowerShell — BFG là file jar, wget/curl trên cmd khó):
```
powershell -Command "Invoke-WebRequest -Uri 'https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar' -OutFile 'bfg-1.14.0.jar'"
```
Expected: file `bfg-1.14.0.jar` (~16 MB) xuất hiện trong thư mục dự án.

- [ ] **Step 2: verify jar chạy được với Java 17**

Run:
```
"C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot\bin\java.exe" -jar bfg-1.14.0.jar
```
Expected: in ra BFG banner + usage. Nếu báo `could not find main class` → jar hỏng, download lại.

### Task 1.4: BFG — xóa env.json khỏi history + thay text AIza

**Files:**
- Create: `secrets-replacement.txt`

BFG chạy 2 phép song song để đảm bảo triệt để: `--delete-files` xóa file `env.json` khỏi mọi commit cũ (HEAD được bảo vệ tự động), `--replace-text` xóa mọi chuỗi `AIza...` còn sót ở bất kỳ file nào.

- [ ] **Step 1: tạo file patterns replace-text**

Nội dung `secrets-replacement.txt`:
```
regex:AIza[0-9A-Za-z_\-]{35}==>
env.json==>
```
Giải thích: dòng 1 regex khớp mọi Gemini API key (đều bắt đầu `AIza` + 35 ký tự). Dòng 2 thay mọi tham chiếu text `env.json`. `==>` nghĩa là xóa (thay bằng rỗng).

- [ ] **Step 2: chạy BFG xóa file env.json**

Run:
```
"C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot\bin\java.exe" -jar bfg-1.14.0.jar --delete-files env.json --no-blob-protection .
```
Expected: BFG báo `worked`, liệt kê các commit đã chạm. `--no-blob-protection` cho phép BFG sửa cả blob tại HEAD (an toàn vì HEAD hiện không track env.json).

- [ ] **Step 3: chạy BFG replace-text cho AIza keys**

Run:
```
"C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot\bin\java.exe" -jar bfg-1.14.0.jar --replace-text secrets-replacement.txt --no-blob-protection .
```
Expected: BFG báo số blob đã replace.

- [ ] **Step 4: dọn rác — expire reflog + aggressive gc**

BFG không tự xóa object cũ, phải tự gc:
```
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```
Expected: repo nhỏ lại đáng kể (vì bỏ các blob env.json/key).

### Task 1.5: Verify history đã sạch

- [ ] **Step 1: scan AIza trong toàn bộ history**

Run:
```
git log --all -p | findstr /C:"AIza"
```
Expected: KHÔNG in ra gì (exit code 1 từ findstr = không tìm thấy). Nếu còn → quay Task 1.4 Step 3, kiểm tra regex.

- [ ] **Step 2: scan env.json trong history**

Run:
```
git log --all --full-history -- env.json
```
Expected: không in commit nào.

- [ ] **Step 3: verify code nguồn vẫn nguyên vẹn (HEAD không hỏng)**

Run:
```
flutter pub get
dart analyze lib/ test/
flutter test --exclude-tags perf
```
Expected: `No issues found!` + `All tests passed!`. Nếu FAIL → BFG đã vô tình chạm code; restore từ `.git-backup-pre-bfg` (Task 1.2) và làm lại cẩn thận hơn.

- [ ] **Step 4: đối chiếu SHA**

Run:
```
git rev-parse HEAD
```
Lưu ý: SHA HEAD sẽ KHÁC `SHA_BEFORE` vì history bị rewrite (mọi commit từ khi có env.json đều đổi hash). Đây là dấu hiệu rewrite thành công, không phải lỗi.

### Task 1.6: Force-push + dọn dẹp

⚠️ **Force-push thay đổi remote history.** Vì về cơ bản chỉ 1 contributor, an toàn, nhưng nếu có collaborator khác, thông báo họ `git fetch && git reset --hard origin/main`.

- [ ] **Step 1: force-push main + tags**

Run:
```
git push --force origin main
git push --force --tags
```
Expected: push thành công. GitHub remote giờ có history sạch.

- [ ] **Step 2: verify trên GitHub remote**

Run:
```
git ls-remote origin
```
Expected: HEAD ref trỏ đến SHA mới. Trên web GitHub → repo → không tìm thấy `env.json` trong history (dùng GitHub search `AIza` trong code → 0 kết quả).

- [ ] **Step 3: xóa file tạm BFG**

Run:
```
del bfg-1.14.0.jar
del secrets-replacement.txt
```

- [ ] **Step 4: thêm pre-commit hook phòng ngừa (xem chi tiết Phase 2 Task 2.2)**

Tạm ghi nhận — hook thật tạo ở Phase 2.

- [ ] **Step 5: commit CHANGELOG/security note**

**Files:**
- Modify: `CHANGELOG.md` (thêm entry)
- Modify: `SECURITY.md` (đánh dấu manual steps DONE)

Thêm vào đầu `CHANGELOG.md` (sau heading):
```markdown
## [Security] — 2026-06-24 — Git history scrubbed

- Rotated all 21 Gemini API keys on Google Cloud Console.
- Used BFG Repo-Cleaner to delete `env.json` and replace all `AIza*`
  secrets across the entire git history.
- Force-pushed rewritten history. Old clones must re-clone.
```

Trong `SECURITY.md`, đổi dòng cuối:
```markdown
_Last updated: 2026-06-24 — Bug #1 fix hoàn tất (code-side + manual steps DONE). History scrubbed via BFG._
```

- [ ] **Step 6: commit**

```
git add CHANGELOG.md SECURITY.md
git commit -m "security: scrub 21 leaked Gemini keys from git history via BFG

- Rotated all keys on Google Cloud Console (manual).
- BFG --delete-files env.json + --replace-text AIza* across full history.
- Force-pushed. Closes the −6500 security gap.

Followed SECURITY.md manual procedure."
git push origin main
```

**✅ Sau Phase 1: phục hồi ~6 500 điểm (bảo mật). Điểm ước tính: ~93 500.**

---

# Phase 2 — Commit Hygiene (conventional commits + pre-commit hook)

**Mục tiêu:** Chặn regress "commit message rỗng" và "commit nhầm env.json" bằng pre-commit hook. (Không thể sửa retroactive các commit cũ đã rewrite — chỉ ngăn tương lai.)

**Thời gian ước tính:** 25 phút.

### Task 2.1: Tạo pre-commit hook chặn env.json + placeholder keys

**Files:**
- Create: `.git/hooks/pre-commit`
- Create: `tool/install-hooks.sh` (mirror)

- [ ] **Step 1: tạo pre-commit hook**

Nội dung `.git/hooks/pre-commit`:
```sh
#!/bin/sh
# Block commit of env.json and any staged AIza key.

if git diff --cached --name-only | grep -qx "env.json"; then
  echo "BLOCKED: env.json is gitignored and must never be committed."
  echo "  If you genuinely need to (rare), use: git commit --no-verify"
  exit 1
fi

if git diff --cached -U0 | grep -qE "AIza[0-9A-Za-z_\-]{35}"; then
  echo "BLOCKED: staged change contains a Gemini API key (AIza...)."
  echo "  Rotate the key and remove it from the diff first."
  exit 1
fi

exit 0
```

- [ ] **Step 2: chmod + chạy thử hook**

Run:
```
git update-index --chmod=+x .git/hooks/pre-commit
```
Lưu ý: trên Windows, `.git/hooks/pre-commit` chạy qua Git Bash nên cần executable bit.

- [ ] **Step 3: verify hook chặn hoạt động**

Run:
```
git add -- ":^env.json"
copy NUL _hooktest.tmp
git add _hooktest.tmp
git commit -m "test" -- _hooktest.tmp
```
(Commit file vô hại để chắc hook chạy mà không bị block bởi rule env.json.)
Expected: commit thành công (hook pass). Sau đó dọn:

```
del _hooktest.tmp
git add --all
git commit -m "chore: remove hook test file" || git rm _hooktest.tmp
```

- [ ] **Step 4: tạo installer để dev mới setup nhanh**

Nội dung `tool/install-hooks.sh`:
```sh
#!/usr/bin/env bash
# Copy pre-commit hook into .git/hooks. Run once after cloning.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
cp "$ROOT/tool/pre-commit.template" "$ROOT/.git/hooks/pre-commit"
chmod +x "$ROOT/.git/hooks/pre-commit"
echo "pre-commit hook installed."
```

Tạo `tool/pre-commit.template` = copy y hệt nội dung Step 1 (đây là bản template được track, `.git/hooks/` không track được).

- [ ] **Step 5: commit**

```
git add tool/install-hooks.sh tool/pre-commit.template
git commit -m "tool: add pre-commit hook to block env.json and AIza keys

Mirrors SECURITY.md prevention guidance. Install with:
  bash tool/install-hooks.sh"
git push origin main
```

### Task 2.2: Áp dụng Conventional Commits cho các commit tiếp theo

Đây là quy ước, không phải code. Từ Phase 3 trở đi, MỌI commit message theo dạng:

```
<type>(<scope>): <mô tả ngắn tiếng Việt>

<giải thích tại sao (không phải what)>
```

- `type`: `feat`, `fix`, `refactor`, `test`, `docs`, `style`, `chore`, `build`, `ci`, `security`, `perf`.
- `scope`: `l1`, `l2`, `l3`, `ui`, `data`, `services`, `app`, `tool`, `deps`.

- [ ] **Step 1: cập nhật CONTRIBUTING.md**

**Files:**
- Modify: `CONTRIBUTING.md`

Thêm section "Quy ước commit message" với bảng type + 2 ví dụ (dùng 2 commit mẫu ở Phase 1). Tham chiếu https://www.conventionalcommits.org.

- [ ] **Step 2: commit**

```
git add CONTRIBUTING.md
git commit -m "docs: document Conventional Commits convention in CONTRIBUTING"
git push origin main
```

**✅ Sau Phase 2: phục hồi ~1 000 điểm (quy trình). Điểm ước tính: ~94 500.**

---

# Phase 3 — Dependency Upgrades (gradual, TDD per package)

**Mục tiêu:** Nâng cấp 3 dependency lớn có breaking API: `flutter_riverpod` 2→3, `go_router` 14→17, `permission_handler` 11→12. Mỗi package một commit, TDD: baseline xanh trước → bump → analyze+test → fix breakage → xanh lại → commit.

**Bề mặt breaking (đo được):**
- riverpod: 29 chỗ dùng `ConsumerWidget`/`WidgetRef`/`ProviderScope`/`Provider`/`StateNotifier`. 0 chỗ dùng `Ref.provider`/`keepAlive`/`autoDispose` (provider đơn giản → breaking nhỏ).
- go_router: 32 chỗ dùng `GoRoute`/`GoRouter`/`context.go`/`context.push`.
- permission_handler: 6 chỗ import.

**Thời gian ước tính:** 90–120 phút (tùy số breakage thật).

### Task 3.1: Upgrade flutter_riverpod 2.6.1 → 3.x

**Files:**
- Modify: `pubspec.yaml`
- Modify: 29 file trong `lib/` dùng riverpod (sửa breakage khi hiện ra)

- [ ] **Step 1: snapshot baseline test count**

Run:
```
flutter test --exclude-tags perf 2>&1 | findstr /C:"All tests passed"
```
Ghi lại con số (≈ 1331). Đây là mốc: sau upgrade phải ≥ con số này.

- [ ] **Step 2: bump version trong pubspec.yaml**

Sửa dòng `flutter_riverpod: ^2.5.1` → `flutter_riverpod: ^3.0.0`.

- [ ] **Step 3: pub get + analyze**

Run:
```
flutter pub get
dart analyze lib/ test/ 2>&1 | findstr /C:"error"
```
Ghi lại danh sách error (nếu có). riverpod 3 chủ yếu breaking ở codegen + `Ref` param; provider viết tay dạng `Provider((ref) => ...)` thường vẫn chạy.

- [ ] **Step 4: sửa từng breakage**

Với mỗi error ở Step 3: đọc thông báo, sửa tối thiểu. Pattern thường gặp riverpod 3:
- Nếu báo thiếu `Ref ref` param trong provider → thêm vào: `Provider((ref) => makeService(ref))`.
- Nếu `StateNotifier` deprecated → giữ nguyên vẫn chạy (deprecated warning, không error).

KHÔNG refactor lớn ở bước này — chỉ sửa compile error tối thiểu để test chạy được.

- [ ] **Step 5: test xanh**

Run:
```
flutter test --exclude-tags perf 2>&1 | findstr /C:"All tests passed"
```
Expected: `All tests passed!`, số test ≥ baseline Step 1.

- [ ] **Step 6: analyze 0**

Run:
```
dart analyze lib/ test/
```
Expected: `No issues found!`.

- [ ] **Step 7: commit**

```
git add pubspec.yaml pubspec.lock lib/
git commit -m "build(deps): upgrade flutter_riverpod 2.6 -> 3.x

Bumped major version; fixed N breakages (Ref param, etc.).
All N tests still pass, analyze 0 issues."
git push origin main
```

### Task 3.2: Upgrade go_router 14.8.1 → 17.x

**Files:**
- Modify: `pubspec.yaml`
- Modify: ~10 file dùng go_router

- [ ] **Step 1: snapshot baseline**

Run: `flutter test --exclude-tags perf` → ghi số test.

- [ ] **Step 2: bump**

Sửa `go_router: ^14.2.0` → `go_router: ^17.0.0`.

- [ ] **Step 3: pub get + analyze**

Run:
```
flutter pub get
dart analyze lib/ test/ 2>&1 | findstr /C:"error"
```
go_router 15+ bỏ một số API cũ (`redirect` signature thay, `GoRouterState` field). Xem danh sách error.

- [ ] **Step 4: sửa breakage**

Pattern thường gặp:
- `redirect: (context, state)` → `redirect: (context, state, GoRouterState)` hoặc signature mới theo thông báo error.
- `ShellRoute` builder signature.
Sửa theo thông báo analyzer cụ thể, tối thiểu.

- [ ] **Step 5: test + analyze xanh**

Run:
```
flutter test --exclude-tags perf
dart analyze lib/ test/
```
Expected: pass + 0 issues.

- [ ] **Step 6: chạy app thử navigate**

Run: `flutter run`. Test: vào home → monitoring → history → back. Router không crash.

- [ ] **Step 7: commit**

```
git add pubspec.yaml pubspec.lock lib/
git commit -m "build(deps): upgrade go_router 14 -> 17

Fixed router redirect/shell signatures. Manual nav smoke test passed."
git push origin main
```

### Task 3.3: Upgrade permission_handler 11.4.0 → 12.x

**Files:**
- Modify: `pubspec.yaml`
- Modify: 3 file import (`native_call_shield_bridge.dart`, `permission_controller.dart`, `simulator_call_shield_bridge.dart`)
- Modify: `android/app/build.gradle` (nếu cần bump compileSdk cho Android 14/15)

- [ ] **Step 1: snapshot baseline**

Run: `flutter test --exclude-tags perf` → ghi số.

- [ ] **Step 2: bump**

Sửa `permission_handler: ^11.3.1` → `permission_handler: ^12.0.0`.

- [ ] **Step 3: pub get + analyze + Android compileSdk check**

Run:
```
flutter pub get
dart analyze lib/ test/
```
permission_handler 12 yêu cầu compileSdk ≥ 34 (Android 14). Kiểm tra `android/app/build.gradle`: nếu `compileSdk < 34` → bump lên 34.

- [ ] **Step 4: sửa breakage (nếu có)**

Thường chỉ là warning về Android manifest permission. Analyzer Dart thường không break.

- [ ] **Step 5: test + analyze xanh**

Run:
```
flutter test --exclude-tags perf
dart analyze lib/ test/
```

- [ ] **Step 6: build APK thử (bắt lỗi native)**

Run:
```
flutter build apk --debug
```
Expected: `Built build\app\outputs\flutter-apk\app-debug.apk`. Nếu lỗi Gradle compileSdk → quay Step 3.

- [ ] **Step 7: commit**

```
git add pubspec.yaml pubspec.lock lib/ android/
git commit -m "build(deps): upgrade permission_handler 11 -> 12

Bumped android compileSdk to 34. Debug APK builds clean."
git push origin main
```

### Task 3.4: Xóa dependency_overrides tech debt

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: kiểm tra override còn cần không**

`pubspec.yaml` có `dependency_overrides: path_provider_android: 2.2.22`. Comment nói "Remove when sqflite-next is released". Sau upgrade sqflite (task phụ), thử bỏ.

Sửa: xóa toàn bộ khối `dependency_overrides:`.

- [ ] **Step 2: pub get + test + analyze**

Run:
```
flutter pub get
dart analyze lib/ test/
flutter test --exclude-tags perf
```
Nếu lỗi liên quan sqflite/platform channel → khôi phục override (override vẫn cần), revert commit này. Nếu xanh → tiếp tục.

- [ ] **Step 3: commit (chỉ nếu Step 2 xanh)**

```
git add pubspec.yaml pubspec.lock
git commit -m "build(deps): drop path_provider_android override

sqflite platform-channel contract no longer needs the pin.
Dependency override tech debt cleared."
git push origin main
```

**✅ Sau Phase 3: phục hồi ~1 000 điểm (dependencies). Điểm ước tính: ~95 500.**

---

# Phase 4 — Refactor File Lớn (characterization-test driven)

**Mục tiêu:** Tách 4 file >650 LOC thành orchestrator mỏng + module nhỏ, theo đúng pattern refactor campaign (Sprint 3.1–3.5) mà dự án đã dùng. Nguyên tắc: **characterization test xanh TRƯỚC khi tách**, đảm bảo behavior không đổi.

**File mục tiêu (theo LOC):**
1. `lib/analysis/l2/wfsa/scam_graph_builder.dart` — 1050 LOC
2. `lib/analysis/l1/l1_analysis.dart` — 783 LOC
3. `lib/services/native_call_shield_bridge.dart` — 736 LOC
4. `lib/analysis/l2/g_detection/g_thinking.dart` — 689 LOC

**Thời gian ước tính:** 3–4 giờ (4 file × ~45 phút).

### Task 4.1: Refactor scam_graph_builder.dart (1050 LOC) — tách nodes + edges

**Files:**
- Modify: `lib/analysis/l2/wfsa/scam_graph_builder.dart`
- Create: `lib/analysis/l2/wfsa/scam_graph_nodes.dart`
- Create: `lib/analysis/l2/wfsa/scam_graph_edges.dart`
- Test: `test/L/advanced/scam_graph_builder_test.dart` (đảm bảo đã có; nếu chưa, tạo)

- [ ] **Step 1: xác nhận characterization test đã tồn tại và xanh**

Run:
```
flutter test test/L/advanced/scam_graph_builder_test.dart
```
Expected: `All tests passed!`. Nếu file test CHƯA tồn tại → tạo characterization test trước (snapshot input→output của `buildScamGraph()` cho 5–10 case đại diện) rồi mới tiếp tục. Nguyên tắc: KHÔNG refactor file chưa có test chốt behavior.

- [ ] **Step 2: đọc file, xác định ranh giới tách**

Mở `scam_graph_builder.dart`. Định danh 2 cụm trách nhiệm:
- **Nodes**: các hàm khởi tạo node/state (VD: `_buildImpersonationNodes`, `_buildThreatNodes`...).
- **Edges**: các hàm thêm transition/edge (VD: `_addTransitions`, `_wireScenarios`...).

- [ ] **Step 3: tạo scam_graph_nodes.dart — di chuyển node builders**

Tạo file `lib/analysis/l2/wfsa/scam_graph_nodes.dart`. Di chuyển toàn bộ hàm build-node sang (giữ private → public nếu cần gọi chéo, hoặc làm `part of`). Khuyến nghị: dùng `part`/`part of` để giữ class `ScamGraphBuilder` nguyên vẹn nhưng chia file vật lý:

Đầu `scam_graph_builder.dart` thêm:
```dart
part 'scam_graph_nodes.dart';
part 'scam_graph_edges.dart';
```
`scam_graph_nodes.dart` bắt đầu bằng `part of 'scam_graph_builder.dart';`.

- [ ] **Step 4: tạo scam_graph_edges.dart — di chuyển edge wiring**

Tương tự Step 3, cho cụm edges.

- [ ] **Step 5: test lại — behavior không đổi**

Run:
```
flutter test test/L/advanced/scam_graph_builder_test.dart
dart analyze lib/ test/
```
Expected: pass + 0 issues. Nếu FAIL → di chuyển sai, sửa cho đến khi xanh (test chính là safety net).

- [ ] **Step 6: kiểm tra LOC giảm**

Run:
```
find lib/analysis/l2/wfsa -name "*.dart" -exec wc -l {} +
```
Expected: `scam_graph_builder.dart` giờ < 400 LOC, nodes + edges cùng đóng góp phần còn lại.

- [ ] **Step 7: commit**

```
git add lib/analysis/l2/wfsa/
git commit -m "refactor(l2): split scam_graph_builder into nodes + edges files

1050 LOC -> orchestrator + 2 part-files. Behavior unchanged
(characterization tests green). Continues Sprint 3.x refactor campaign."
git push origin main
```

### Task 4.2: Refactor l1_analysis.dart (783 LOC) — tách matcher + scorer

**Files:**
- Modify: `lib/analysis/l1/l1_analysis.dart`
- Create: `lib/analysis/l1/matchers/keyword_matcher_service.dart`
- Create: `lib/analysis/l1/matchers/risk_density_service.dart`
- Create: `lib/analysis/l1/scoring/l1_scorer.dart`

- [ ] **Step 1: xác nhận/hoàn thiện characterization test**

Run: `flutter test test/L/` → xanh. Nếu `l1_analysis_test.dart` chưa phủ đủ → thêm 3–5 test case (green input, red input, bigram correction, risk density threshold) trước.

- [ ] **Step 2: định danh 3 cụm**

Đọc `l1_analysis.dart`. Tách thành:
- **KeywordMatcherService**: Aho-Corasick match + bigram correction.
- **RiskDensityService**: tính risk density.
- **L1Scorer**: tổng hợp score → RiskLevel.

- [ ] **Step 3: tạo 3 file + dùng composition (không part)**

`L1Analyzer` giữ lại làm façade, inject 3 service:
```dart
class L1Analyzer implements Analyzer {
  L1Analyzer({
    KeywordMatcherService? matcher,
    RiskDensityService? density,
    L1Scorer? scorer,
  }) : _matcher = matcher ?? KeywordMatcherService(),
       _density = density ?? RiskDensityService(),
       _scorer = scorer ?? L1Scorer();
  // analyze() gọi tuần tự 3 service
}
```

- [ ] **Step 4: test lại**

Run:
```
flutter test test/L/
dart analyze lib/ test/
```
Expected: xanh + 0 issues.

- [ ] **Step 5: commit**

```
git add lib/analysis/l1/
git commit -m "refactor(l1): split L1Analyzer into matcher/density/scorer services

L1Analyzer is now a thin facade. Injects KeywordMatcherService,
RiskDensityService, L1Scorer. Same public API, characterization tests green."
git push origin main
```

### Task 4.3: Refactor native_call_shield_bridge.dart (736 LOC)

**Files:**
- Modify: `lib/services/native_call_shield_bridge.dart`
- Create: `lib/services/android/bridge_state_machine.dart`
- Create: `lib/services/android/method_channel_codec.dart`

- [ ] **Step 1: characterization test**

Run: `flutter test test/services/` → xác nhận xanh. Bridge native khó test thuần; nếu coverage mỏng, thêm test cho `MonitoringState.parse`, `CallEvent.fromMap` (pure function, dễ test) trước.

- [ ] **Step 2: định danh 2 cụm tách được**

- **BridgeStateMachine**: logic chuyển state (STARTED/STOPPED/NETWORK/fallback).
- **MethodChannelCodec**: parse/serialize tuple native ↔ Dart (`MonitoringState.parse`, `CallEvent.fromMap`).

- [ ] **Step 3: tách 2 file + giữ NativeCallShieldBridge làm façade**

Di chuyển pure logic sang 2 file mới. `NativeCallShieldBridge` giữ method channel plumbing + delegate parse cho codec.

- [ ] **Step 4: test + analyze xanh**

Run:
```
flutter test test/services/
dart analyze lib/ test/
```

- [ ] **Step 5: commit**

```
git add lib/services/
git commit -m "refactor(services): extract state machine + codec from native bridge

736 LOC facade. Parsing logic now unit-testable in
bridge_state_machine.dart and method_channel_codec.dart."
git push origin main
```

### Task 4.4: Refactor g_thinking.dart (689 LOC)

**Files:**
- Modify: `lib/analysis/l2/g_detection/g_thinking.dart`

- [ ] **Step 1: characterization test**

Run: `flutter test test/L/g_detection/` → xanh.

- [ ] **Step 2: đọc + định danh cụm**

`g_thinking.dart` thường chứa "reasoning" step của GDetection. Tách theo từng phase thinking (VD: topic inference, scenario scoring, confidence aggregation).

- [ ] **Step 3: tách thành 2–3 file nhỏ** (tên cụ thể phụ thuộc nội dung — engineer đọc file để đặt tên module chính xác; mỗi file < 300 LOC).

- [ ] **Step 4: test + analyze xanh**

Run: `flutter test test/L/g_detection/ && dart analyze lib/ test/`

- [ ] **Step 5: commit**

```
git add lib/analysis/l2/g_detection/
git commit -m "refactor(l2): break up g_thinking into focused modules

689 LOC -> N modules <300 LOC each. g_detection tests green."
git push origin main
```

**✅ Sau Phase 4: phục hồi ~1 500 điểm (kiến trúc/file size). Điểm ước tính: ~97 000.**

---

# Phase 5 — Mở rộng Simulator Bridge (iOS/Desktop parity)

**Mục tiêu:** Hiện iOS/Desktop chạy simulator bridge rút gọn (chỉ 1 kịch bản scam). Mở rộng thành feature parity: nhiều kịch bản, creator mode, permission gate đầy đủ — để "phạm vi platform" không còn bị trừ.

**File hiện tại:** `lib/services/simulator_call_shield_bridge.dart` có 1 `_iosScamScript` hardcode (6 câu), timer 100ms.

**Thời gian ước tính:** 2–3 giờ.

### Task 5.1: Thêm bộ kịch bản simulator đa dạng

**Files:**
- Create: `lib/services/simulator/simulator_scripts.dart`
- Modify: `lib/services/simulator_call_shield_bridge.dart`

- [ ] **Step 1: tạo test đỏ cho multi-script selection**

**Test:** `test/services/simulator_scripts_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/simulator/simulator_scripts.dart';

void main() {
  test('SimulatorScriptCatalog exposes at least 3 scenarios', () {
    expect(SimulatorScriptCatalog.all.length, greaterThanOrEqualTo(3));
  });

  test('each script has non-empty id, title, and >=3 lines', () {
    for (final s in SimulatorScriptCatalog.all) {
      expect(s.id, isNotEmpty);
      expect(s.title, isNotEmpty);
      expect(s.lines.length, greaterThanOrEqualTo(3));
    }
  });

  test('catalog can look up by id', () {
    final first = SimulatorScriptCatalog.all.first;
    expect(SimulatorScriptCatalog.byId(first.id), same(first));
  });
}
```

- [ ] **Step 2: chạy test → FAIL (file chưa tồn tại)**

Run: `flutter test test/services/simulator_scripts_test.dart`
Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: implement SimulatorScriptCatalog**

Nội dung `lib/services/simulator/simulator_scripts.dart`:
```dart
/// Catalog kịch bản giả lập cho simulator bridge (iOS/Desktop/Web).
/// Mỗi kịch bản là một chuỗi câu thoại để feed vào analysis pipeline,
/// thay thế cho STT thật (không có trên non-Android).
class SimulatorScript {
  const SimulatorScript({
    required this.id,
    required this.title,
    required this.lines,
  });
  final String id;
  final String title;
  final List<String> lines;
}

class SimulatorScriptCatalog {
  const SimulatorScriptCatalog._();

  static const taxAuthority = SimulatorScript(
    id: 'tax_authority',
    title: 'Giả mạo cơ quan thuế',
    lines: [
      'Tôi là cán bộ thuế, ông đang nợ thuế 50 triệu.',
      'Nếu không nộp ngay trong 10 phút tài khoản sẽ bị phong tỏa.',
      'Hãy chuyển số tiền nợ về tài khoản tạm giữ của cơ quan thuế.',
    ],
  );

  static const bankFraud = SimulatorScript(
    id: 'bank_fraud',
    title: 'Lừa đảo ngân hàng',
    lines: [
      'Tài khoản ngân hàng của ông đang bị nghi ngờ rửa tiền.',
      'Ông cần chuyển toàn bộ số dư sang tài khoản an toàn của chúng tôi.',
      'Đọc mã OTP vừa gửi để hoàn tất xác minh.',
    ],
  );

  static const prize = SimulatorScript(
    id: 'prize',
    title: 'Trúng thưởng ảo',
    lines: [
      'Chúc mừng ông đã trúng thưởng 200 triệu đồng.',
      'Ông chỉ cần đóng phí xử lý 2 triệu để nhận giải.',
      'Đưa tôi mã thẻ cào để tôi nạp phí giúp ông.',
    ],
  );

  static const List<SimulatorScript> all = [
    taxAuthority,
    bankFraud,
    prize,
  ];

  static SimulatorScript? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }
}
```

- [ ] **Step 4: chạy test → PASS**

Run: `flutter test test/services/simulator_scripts_test.dart`
Expected: `All tests passed!`.

- [ ] **Step 5: thay `_iosScamScript` hardcode trong bridge bằng catalog**

Trong `simulator_call_shield_bridge.dart`: xóa `_iosScamScript` hardcode, thay bằng tham chiếu `SimulatorScriptCatalog.bankFraud.lines` (mặc định) + thêm param chọn script. Cập nhật import.

- [ ] **Step 6: test bridge vẫn xanh**

Run:
```
flutter test test/services/simulator_bridge_test.dart
dart analyze lib/ test/
```
Expected: pass + 0 issues.

- [ ] **Step 7: commit**

```
git add lib/services/simulator/ lib/services/simulator_call_shield_bridge.dart test/services/simulator_scripts_test.dart
git commit -m "feat(services): add multi-scenario simulator script catalog

iOS/Desktop/Web simulator was locked to one hard-coded scam script.
Adds 3 scenarios (tax authority, bank fraud, prize) selectable by id."
git push origin main
```

### Task 5.2: Thêm Creator Mode + Permission Gate cho simulator

**Files:**
- Create: `lib/services/simulator/simulator_creator_mode.dart`
- Create: `lib/services/simulator/simulator_permission_gate.dart`
- Modify: `lib/services/simulator_call_shield_bridge.dart`

- [ ] **Step 1: test đỏ cho creator mode**

**Test:** `test/services/simulator_creator_mode_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/simulator/simulator_creator_mode.dart';

void main() {
  test('CreatorMode plays custom lines at sentence interval', () async {
    final mode = SimulatorCreatorMode(lines: const ['A.', 'B.', 'C.']);
    final emitted = <String>[];
    final sub = mode.transcriptStream.listen(emitted.add);
    await mode.play(tickIntervalMs: 1, sentenceIntervalTicks: 1);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(emitted, containsAll(['A.', 'A. B.', 'A. B. C.']));
  });

  test('CreatorMode rejects empty line list', () {
    expect(() => SimulatorCreatorMode(lines: const []),
        throwsArgumentError);
  });
});
```

- [ ] **Step 2: chạy → FAIL**

- [ ] **Step 3: implement SimulatorCreatorMode**

`lib/services/simulator/simulator_creator_mode.dart` — class nhận `List<String> lines`, stream transcript tích lũy theo timer (giống logic timer hiện tại nhưng tách ra + testable không phụ thuộc platform). Throw `ArgumentError` nếu `lines` rỗng.

- [ ] **Step 4: test → PASS**

- [ ] **Step 5: implement SimulatorPermissionGate**

`lib/services/simulator/simulator_permission_gate.dart` — trên non-Android, simulator không cần quyền thật; gate trả `granted` ngay nhưng vẫn expose `PermissionSnapshot` để UI nhất quán. Test: gate non-Android luôn trả `granted=true`.

- [ ] **Step 6: wire vào bridge + test integration**

Sửa `simulator_call_shield_bridge.dart` dùng `SimulatorCreatorMode` thay timer inline. Chạy `flutter test test/services/` xanh.

- [ ] **Step 7: commit**

```
git add lib/services/simulator/ test/services/
git commit -m "feat(services): add creator mode + permission gate to simulator

Non-Android simulator now supports custom scam scripts (creator mode)
and a no-op permission gate that keeps the UI contract consistent."
git push origin main
```

### Task 5.3: CI matrix — chạy test trên iOS/Desktop target

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: thêm step verify build non-Android (không build thật, chỉ check config)**

Trong `ci.yml`, job `build-apk` hiện có; thêm job `verify-multiplatform` chạy `dart analyze` + `flutter test` (đã có) — phần lớn đã cover. Thêm 1 step riêng: verify `flutter build ios --config --no-codesign` không lỗi config (chỉ config check, không build engine).

Thêm vào `ci.yml` sau job `build-apk`:
```yaml
  verify-ios-config:
    name: Verify iOS config (no build)
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - name: Provide env.json stub
        run: |
          if [ ! -f env.json ]; then
            printf '{\n  "gemini_api_keys": [],\n  "model": "gemini-1.5-flash"\n}\n' > env.json
          fi
      - run: flutter pub get
      - name: Verify iOS Xcode project parses
        run: flutter build ios --config --no-codesign --no-tree-shake-icons
```

- [ ] **Step 2: commit + push để CI chạy**

```
git add .github/workflows/ci.yml
git commit -m "ci: add verify-ios-config job for non-Android platform parity"
git push origin main
```

- [ ] **Step 3: verify CI pass trên GitHub Actions**

Mở https://github.com/ghitatruongle/lachancuocgoi/actions → job `verify-ios-config` phải xanh. Nếu fail vì config iOS → sửa `ios/Runner` (thường thiếu deployment target hoặc bundle id).

**✅ Sau Phase 5: phục hồi ~1 000 điểm (phạm vi platform). Điểm ước tính: ~98 000.**

---

# Phase 6 — Documentation & Final Verification

**Mục tiêu:** Cập nhật docs phản ánh roadmap max-điểm đã hoàn thành; chạy full verification (analyze + test + format + build) làm evidence cuối.

**Thời gian ước tính:** 30 phút.

### Task 6.1: Cập nhật KEHOACH.md + CHANGELOG.md + README.md

**Files:**
- Modify: `KEHOACH.md`
- Modify: `CHANGELOG.md`
- Modify: `README.md`

- [ ] **Step 1: thêm Sprint 7–Max vào KEHOACH.md**

Trong `KEHOACH.md`, sau Sprint 6, thêm:
```markdown
### ✅ Sprint 7 — Max-Score Campaign
- **Mục tiêu**: Đóng 5 khoảng cách điểm (security, format, commits, deps, refactor, platform).
- **Kết quả**: ✅ Hoàn thành
- **Chi tiết**:
  - **7.1** — Baseline lock + sửa 152 file dart format drift
  - **7.2** — Security: rotate 21 keys + BFG scrub git history (−6500 điểm)
  - **7.3** — Pre-commit hook (env.json + AIza) + Conventional Commits
  - **7.4** — Upgrade riverpod 3 / go_router 17 / permission_handler 12
  - **7.5** — Refactor 4 file >650 LOC (scam_graph_builder, l1_analysis, native bridge, g_thinking)
  - **7.6** — Simulator bridge: multi-script + creator mode + permission gate + CI iOS
```

- [ ] **Step 2: cập nhật thống kê trong KEHOACH.md**

Sửa bảng "Thống kê dự án" — cập nhật số test (sau Phase 5), số LOC, thêm dòng "Platform parity: Android (native) + iOS/Web/Desktop (simulator bridge)".

- [ ] **Step 3: cập nhật README.md dependencies + version**

Bump version `1.3.0+8` → `1.4.0+9`, cập nhật bảng dependency version trong phần SDK.

- [ ] **Step 4: CHANGELOG entry tổng hợp**

Thêm entry `## [1.4.0] — 2026-06-24` liệt kê tất cả thay đổi Phase 0–5.

- [ ] **Step 5: commit**

```
git add KEHOACH.md CHANGELOG.md README.md pubspec.yaml
git commit -m "docs: document Sprint 7 max-score campaign + bump to 1.4.0"
git push origin main
```

### Task 6.2: Final verification (evidence)

- [ ] **Step 1: format check**

Run:
```
dart format --output=none --set-exit-if-changed lib/ test/
```
Expected: exit 0.

- [ ] **Step 2: analyze**

Run:
```
dart analyze lib/ test/
```
Expected: `No issues found!`.

- [ ] **Step 3: full fast test + count**

Run:
```
flutter test --exclude-tags perf
```
Expected: `All tests passed!`. Ghi số test cuối (phải > baseline 1331 nhờ Phase 5 thêm test).

- [ ] **Step 4: build debug APK**

Run:
```
flutter build apk --debug
```
Expected: `Built ...app-debug.apk`.

- [ ] **Step 5: tag release**

```
git tag v1.4.0
git push origin v1.4.0
```
Expected: tag push → trigger `release.yml` CI build unsigned release APK.

- [ ] **Step 6: ghi bảng điểm cuối vào KEHOACH.md**

Cập nhật bảng khoảng cách điểm: tất cả dấu "−" → "0", ghi điểm cuối `≥ 98 000 / 100 000`.

**✅ Sau Phase 6: phục hồi ~500 điểm (docs) + khóa chốt. Điểm ước tính: ~98 500 / 100 000.**

---

## Tóm tắt dependency giữa các Phase

```
Phase 0 (baseline) ──┬──> Phase 1 (security, ROI max)
                     ├──> Phase 2 (commits)  ──────────────┐
                     ├──> Phase 3 (deps upgrade)           ├──> Phase 6 (docs + verify)
                     ├──> Phase 4 (refactor)               │
                     └──> Phase 5 (simulator bridge) ──────┘
```

Phase 1 KHÔNG phụ thuộc gì khác → làm ngay sau Phase 0. Phase 3, 4, 5 độc lập với nhau, có thể song song (xem skill `dispatching-parallel-agents`). Phase 6 làm cuối.

## Risk register

| Rủi ro | Khả năng | Tác động | Giảm thiểu |
|--------|----------|----------|------------|
| BFG làm hỏng history | Thấp | Cao | Backup `.git` (Task 1.2) + tag baseline (Task 0.3) |
| Upgrade deps vỡ API không fix được | Trung bình | Trung bình | Mỗi package 1 commit, rollback từng cái dễ |
| Refactor đổi behavior | Trung bình | Cao | Characterization test xanh TRƯỚC khi tách |
| Force-push làm collaborator mất commit | Thấp | Cao | Repo 1 người; vẫn thông báo trước |
| CI iOS config fail | Trung bình | Thấp | Chỉ config-check, không build engine |

---

> **Cập nhật lần cuối:** 2026-06-24 · **Trạng thái kế hoạch:** Sẵn sàng thực thi
