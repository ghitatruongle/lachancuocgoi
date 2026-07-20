# Eval corpus v2

## Cấu trúc

```text
test/fixtures/eval/corpus_v2_templates.json
test/analysis/eval/eval_case.dart
test/analysis/eval/eval_runner.dart
test/analysis/eval/corpus_regression_test.dart
```

Corpus nguồn dùng template đã duyệt và được mở rộng thành đúng 300 ca:

- 120 câu lành tính.
- 120 câu lừa đảo.
- 60 câu nhiễu ASR, thiếu dấu hoặc tách từ sai.

Mỗi template kết hợp với 10 biến thể để có ID ổn định và vẫn dễ review. Không
dùng transcript hoặc số điện thoại thật.

## Pipeline kiểm thử

Gate khởi tạo `L1Analyzer` và `GDetectionEngine` bằng chính JSON trong
`assets/`. TFLite được vô hiệu hóa trong eval để kết quả tái lập trên CI; WFSA
và toàn bộ L1/L2 còn lại là implementation production. L3 nhận key rỗng và
`networkAvailable` luôn false nên không gọi Gemini.

Chạy riêng:

```bash
flutter test test/analysis/eval/corpus_regression_test.dart
```

## Cổng chất lượng

- Precision ≥ 90%.
- Recall ≥ 90%.
- False-red trên câu lành tính ≤ 1%.
- Nhóm critical OTP, chuyển tiền và giả danh cơ quan không có false-green.

Khi thêm template, phải giữ tối thiểu số lượng từng nhóm và không hạ các cổng
để làm test vượt qua. Nếu gate thất bại, xem bảng confusion/failure mà runner
in ra và sửa asset hoặc thuật toán với test hồi quy tương ứng.
