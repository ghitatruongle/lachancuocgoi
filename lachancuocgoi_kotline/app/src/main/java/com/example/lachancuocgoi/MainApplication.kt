package com.example.lachancuocgoi

import android.app.Application

/**
 * Lớp Application chính của ứng dụng.
 * (SỬA LỖI) Đã xóa bỏ logic khởi tạo cũ. Việc khởi tạo các bộ phân tích giờ đây
 * được quản lý bởi AnalysisCoordinator khi nó được tạo ra lần đầu tiên.
 * Điều này đảm bảo khởi tạo đúng lúc, đúng chỗ và không lãng phí tài nguyên.
 */
class MainApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        // Không còn cần khởi tạo bất cứ thứ gì ở đây.
    }
}
