package com.example.lachancuocgoi.ui.HomePage.InstructDialog

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun InstructDialog(onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Hướng dẫn sử dụng") },
        text = {
            PrincipleOfOperationTab()
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("Đã hiểu")
            }
        }
    )
}

@Composable
fun PrincipleOfOperationTab() {
    val principles = listOf(
        Triple(
            Icons.AutoMirrored.Filled.VolumeUp,
            "Bước 1: Bật Loa Ngoài",
            "Bật loa ngoài giúp ứng dụng thu được âm thanh từ cả hai phía thông qua microphone để phân tích."
        ),
        Triple(
            Icons.Filled.Mic,
            "Bước 2: Phân Tích Âm Thanh",
            "Ứng dụng sẽ lắng nghe và phân tích cuộc hội thoại theo thời gian thực."
        ),
        Triple(
            Icons.Filled.NotificationsActive,
            "Bước 3: Gửi Cảnh Báo",
            "Nếu phát hiện dấu hiệu lừa đảo, ứng dụng sẽ rung hoặc phát chuông để cảnh báo bạn."
        )
    )

    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier
            .padding(vertical = 16.dp)
            .verticalScroll(rememberScrollState())
    ) {
        principles.forEach { (icon, title, description) ->
            ListItem(
                headlineContent = { Text(title) },
                supportingContent = { Text(description) },
                leadingContent = {
                    Icon(
                        imageVector = icon,
                        contentDescription = title,
                    )
                }
            )
        }
    }
}
