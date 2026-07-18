# App Store Metadata — iOS

Release version: 1.6.0+14 (demo)

## App Name
Lá Chắn Cuộc Gọi — Xem trước AI

## Subtitle
Trợ lý phát hiện lừa đảo qua giọng nói (bản xem trước)

## Description (Vietnamese)

⚠️ **Đây là bản xem trước AI cho iOS.**

Bản đầy đủ (STT thời gian thực, overlay trên màn hình, chặn cuộc gọi) chỉ có trên Android.

Lá Chắn Cuộc Gọi là ứng dụng chống lừa đảo qua cuộc gọi sử dụng pipeline AI 3 tầng:
- **L1**: Phát hiện từ khóa lừa đảo tức thì (Aho-Corasick trie)
- **L2**: AI on-device (TFLite BERT + GDetection + WFSA state machine)
- **L3**: Gemini AI phân tích ngữ nghĩa sâu (opt-in)

Trên iOS, ứng dụng chạy ở chế độ **mô phỏng (demo)** với kịch bản lừa đảo thực tế,
cho phép bạn trải nghiệm khả năng phát hiện AI mà không cần quyền hệ thống đặc biệt.

Tính năng đầy đủ yêu cầu Android 10+ với:
- STT Vosk offline (nhận diện giọng nói tiếng Việt)
- Overlay cảnh báo toàn màn hình
- CallScreeningService (chặn số lừa đảo)
- Accessibility Service (phụ đề trực tiếp)

## Keywords (100 chars)
lừa đảo, scam, chống lừa đảo, OTP, ngân hàng, công an, cảnh báo, AI

## What's New
Bản xem trước iOS — phát hiện lừa đảo bằng AI trên các kịch bản mô phỏng.
Trên iOS, mọi phân tích chạy on-device (demo). Không có L3 cloud trên iOS.

## Marketing URL
(N/A — xem README.md)

## Privacy Policy URL
(https://github.com/nhom-trai-ai/lachancuocgoi_flutter/blob/main/PRIVACY_POLICY.md)

## Honesty Notice
Ứng dụng **KHÔNG** chặn cuộc gọi trên iOS. Ứng dụng **KHÔNG** nghe nội dung
cuộc gọi thật trên iOS. Trên iOS, ứng dụng chỉ chạy kịch bản mô phỏng để demo
khả năng phát hiện AI. Bản đầy đủ có trên Android.
