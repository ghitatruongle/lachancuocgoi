# Eval Corpus — Hướng dẫn thêm case mới

## Cấu trúc

```
test/fixtures/eval/corpus_v1.jsonl   # Corpus (JSONL, mỗi dòng 1 case)
test/analysis/eval/eval_case.dart     # Model: EvalCase
test/analysis/eval/eval_runner.dart   # Runner: precision/recall/F1
test/analysis/eval/corpus_regression_test.dart  # Gate test (tags: ['eval'])
```

## Thêm case mới

Mở `test/fixtures/eval/corpus_v1.jsonl`, thêm 1 dòng JSON:

```json
{"id":"bank_otp_99","text":"cho xin ma OTP","expected":"RED","scenario":"authority_bank","notes":"classic OTP"}
```

### Quy ước `expected`

| Giá trị | Ý nghĩa |
|---------|---------|
| `GREEN` | predicted phải là green |
| `YELLOW` | predicted phải là yellow |
| `ORANGE` | predicted ≥ orange |
| `RED` | predicted phải là red |
| `YELLOW_OR_GREEN` | predicted ≤ yellow (case FP dễ) |
| `ORANGE_OR_RED` | predicted ≥ orange |

## Chạy eval

```bash
flutter test --tags eval
```

## Ngưỡng (thresholds)

Xem `corpus_regression_test.dart`:
- precision ≥ 0.85
- recall ≥ 0.80
- 0 false RED trên case GREEN

## Pitfall

- Soft fusion (Phase 1): case "L1 orange marketing" có thể ra **yellow** — dùng `YELLOW_OR_GREEN`.
- L3 Gemini: **đừng** gọi API thật trên CI. Eval default dùng `gDetection` hoặc `parallel` + `networkAvailable: () => false`.
