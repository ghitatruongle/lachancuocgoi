package com.example.lachancuocgoi.ui.HomePage.SettingsDialog

import android.widget.Toast
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.selectable
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp

/**
 * Xác định chế độ phân tích sẽ được sử dụng.
 */
enum class AnalysisMode {
    NORMAL,       // Cấp 1: Thuật toán bình thường
    GDetection, // Cấp 2: Hệ thống GDetection
    GEMINI_API    // Cấp 3: Gọi API Gemini
}

/**
 * Composable để người dùng chọn Độ nhạy phân tích.
 */
@Composable
fun AnalysisSensitivitySetting(
    selectedMode: AnalysisMode,
    onModeSelected: (AnalysisMode) -> Unit,
    enabled: Boolean = true // Giữ lại tham số enabled cho mục đích chung
) {
    val options = listOf(
        Triple(AnalysisMode.NORMAL, "Cấp 1: Cơ bản", "Phân tích nhanh dựa trên từ khóa."),
        Triple(AnalysisMode.GDetection, "Cấp 2: Nâng cao", "Phân tích Chủ đề Lừa đảo"),
        Triple(AnalysisMode.GEMINI_API, "Cấp 3: AI", "Phân tích bằng AI trực tuyến")
    )

    Column(modifier = Modifier.padding(16.dp)) {
        Text(
            "Độ nhạy phân tích:",
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(bottom = 8.dp),
            color = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
        )
        options.forEach { (mode, title, description) ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .selectable(
                        selected = (selectedMode == mode),
                        onClick = { onModeSelected(mode) }, // (SỬA LỖI) Cho phép chọn tất cả các chế độ
                        enabled = enabled
                    )
                    .padding(vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                RadioButton(
                    selected = (selectedMode == mode),
                    onClick = null,
                    enabled = enabled
                )
                Column(modifier = Modifier.padding(start = 8.dp)) {
                    val textColor = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
                    Text(
                        text = title,
                        style = MaterialTheme.typography.bodyLarge,
                        color = textColor
                    )
                    Text(
                        text = description,
                        style = MaterialTheme.typography.bodySmall,
                        color = if (enabled) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.38f)
                    )
                }
            }
        }
    }
}
