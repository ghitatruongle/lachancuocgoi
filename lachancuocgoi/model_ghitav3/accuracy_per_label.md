# 📊 Tỉ Lệ Đoán Đúng Theo Từng Nhãn — 4 Models (1000 Kịch Bản)

> Dữ liệu từ `eval_results(34).txt` — Stage 34 🥇 (86.5% tổng)

## Tổng quan xếp hạng

| Model | Tổng đúng | Accuracy |
|-------|-----------|----------|
| 🥇 Stage 34 | 865/1000 | **86.5%** |
| 🥈 Stage 32 | 746/1000 | 74.6% |
| 🥉 Stage 33 | 733/1000 | 73.3% |
| 4️⃣ Stage 31 | 551/1000 | 55.1% |

---

## Chi Tiết Theo Từng Nhãn

| ID | Tên Nhãn | Tổng Mẫu | Stage 31 | Stage 32 | Stage 33 | Stage 34 |
|----|----------|:---------:|:--------:|:--------:|:--------:|:--------:|
| 0 | AUTH_POLICE_LAWSUIT | 83 | 40/83 (48.2%) | 64/83 (77.1%) | 63/83 (75.9%) | **78/83 (94.0%)** |
| 1 | TAX_GOV_APP | 137 | 55/137 (40.1%) | 118/137 (86.1%) | 106/137 (77.4%) | **126/137 (92.0%)** |
| 2 | TELECOM_LOCK | 6 | 0/6 (0.0%) | 0/6 (0.0%) | 0/6 (0.0%) | **1/6 (16.7%)** |
| 3 | TECH_SUPPORT_HIJACK | 5 | 0/5 (0.0%) | 0/5 (0.0%) | 0/5 (0.0%) | **1/5 (20.0%)** |
| 4 | HOSPITAL_EMERGENCY | 6 | 0/6 (0.0%) | 0/6 (0.0%) | 0/6 (0.0%) | **1/6 (16.7%)** |
| 5 | VIRTUAL_KIDNAPPING | 5 | 0/5 (0.0%) | 0/5 (0.0%) | 0/5 (0.0%) | **0/5 (0.0%)** |
| 6 | CEO_FRAUD_B2B | 5 | 0/5 (0.0%) | 0/5 (0.0%) | 1/5 (20.0%) | **1/5 (20.0%)** |
| 7 | SOCIAL_DEEPFAKE_LOAN | 75 | 43/75 (57.3%) | 54/75 (72.0%) | 49/75 (65.3%) | **62/75 (82.7%)** |
| 8 | ROMANCE_SCAM | 4 | 0/4 (0.0%) | 0/4 (0.0%) | 0/4 (0.0%) | **0/4 (0.0%)** |
| 9 | SEXTORTION_BLACKMAIL | 4 | 0/4 (0.0%) | 0/4 (0.0%) | 0/4 (0.0%) | **1/4 (25.0%)** |
| 10 | CHARITY_DONATION | 67 | 47/67 (70.1%) | 53/67 (79.1%) | 51/67 (76.1%) | **59/67 (88.1%)** |
| 11 | INVESTMENT_SCAM | 39 | 19/39 (48.7%) | 31/39 (79.5%) | 29/39 (74.4%) | **33/39 (84.6%)** |
| 12 | JOB_TASK_SCAM | 56 | 30/56 (53.6%) | 45/56 (80.4%) | 46/56 (82.1%) | **49/56 (87.5%)** |
| 13 | GIFT_LOTTERY | 64 | 51/64 (79.7%) | 56/64 (87.5%) | 56/64 (87.5%) | **60/64 (93.8%)** |
| 14 | GAMBLING_PREDICTION | 5 | 0/5 (0.0%) | 0/5 (0.0%) | 1/5 (20.0%) | **1/5 (20.0%)** |
| 15 | IMMIGRATION_VISA_SCAM | 4 | 0/4 (0.0%) | 0/4 (0.0%) | 1/4 (25.0%) | **1/4 (25.0%)** |
| 16 | BANK_CARD_FRAUD | 76 | 46/76 (60.5%) | 64/76 (84.2%) | 61/76 (80.3%) | **70/76 (92.1%)** |
| 17 | DELIVERY_COD | 119 | 74/119 (62.2%) | 92/119 (77.3%) | 84/119 (70.6%) | **106/119 (89.1%)** |
| 18 | FAKE_SUBSCRIPTION | 2 | 0/2 (0.0%) | 0/2 (0.0%) | 0/2 (0.0%) | **2/2 (100.0%)** |
| 19 | BLACK_CREDIT_TERROR | 2 | 0/2 (0.0%) | 0/2 (0.0%) | 1/2 (50.0%) | **1/2 (50.0%)** |
| 20 | RECOVERY_SCAM | 3 | 0/3 (0.0%) | 0/3 (0.0%) | 1/3 (33.3%) | **0/3 (0.0%)** |
| 21 | GENERIC_SCAM | 35 | 1/35 (2.9%) | 26/35 (74.3%) | 28/35 (80.0%) | **30/35 (85.7%)** |
| 22 | SAFE | 198 | 145/198 (73.2%) | 143/198 (72.2%) | 155/198 (78.3%) | **182/198 (91.9%)** |

---

## 🔍 Nhận Xét Chính

### ✅ Stage 34 vượt trội toàn diện
- **Nhãn lớn** (0, 1, 7, 10, 12, 13, 16, 17, 22): Tất cả đều **80-94%**, cải thiện đáng kể so với 31-33.
- **Nhãn hiếm** (2, 3, 4, 5, 6, 8, 9, 14, 15, 18, 19, 20, 21): Có bước nhảy từ **0%** ở các stage cũ lên có ít nhất **một số đúng**, nhưng vẫn rất thấp do mẫu quá ít.

### ⚠️ Các nhãn yếu nhất (ở tất cả models)

| Nhãn | Vấn đề |
|------|--------|
| **5 - VIRTUAL_KIDNAPPING** | 0/5 ở **tất cả** models, kể cả Stage 34 |
| **8 - ROMANCE_SCAM** | 0/4 ở **tất cả** models |
| **2 - TELECOM_LOCK** | Chỉ 1/6 ở Stage 34, còn lại 0% |
| **3 - TECH_SUPPORT_HIJACK** | Chỉ 1/5 ở Stage 34 |
| **4 - HOSPITAL_EMERGENCY** | Chỉ 1/6 ở Stage 34 |
| **20 - RECOVERY_SCAM** | 0/3 ở Stage 34 (dù Stage 33 đoán đúng 1/3) |

> **Nguyên nhân:** Các nhãn 2-6, 8, 9, 14, 15, 18-21 có rất ít mẫu training (2-6 câu test) và có thể thiếu data train tương ứng. Cần bổ sung training data cho các nhãn hiếm này.

### 🏆 Các nhãn mạnh nhất của Stage 34

| Nhãn | Accuracy | Ghi chú |
|------|----------|---------|
| **18 - FAKE_SUBSCRIPTION** | 100.0% (2/2) | Perfect nhưng mẫu ít |
| **0 - AUTH_POLICE_LAWSUIT** | 94.0% (78/83) | Rất mạnh |
| **13 - GIFT_LOTTERY** | 93.8% (60/64) | Rất mạnh |
| **1 - TAX_GOV_APP** | 92.0% (126/137) | Lớp lớn nhất, ấn tượng |
| **16 - BANK_CARD_FRAUD** | 92.1% (70/76) | Rất mạnh |
| **22 - SAFE** | 91.9% (182/198) | Giảm FPR tốt |
