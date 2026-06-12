package com.example.lachancuocgoi.ui.HomePage.RightsDialog

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AppRegistration
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Subtitles
import androidx.compose.material.icons.filled.TaskAlt
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@Composable
fun PermissionPrompts(
    isRecordAudioGranted: Boolean,
    isCallCaptionEnabled: Boolean,
    isCallDetectionEnabled: Boolean,
    isCallScreeningEnabled: Boolean,
    onRequestRecordAudioPermission: () -> Unit,
    onRequestCallCaptionPermission: () -> Unit,
    onRequestCallDetectionPermission: () -> Unit,
    onRequestCallScreeningRole: () -> Unit
) {
    val allGranted = isRecordAudioGranted && isCallCaptionEnabled && isCallDetectionEnabled && isCallScreeningEnabled

    Box(modifier = Modifier.fillMaxWidth().animateContentSize()) {
        if (allGranted) {
            Card(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer),
                shape = MaterialTheme.shapes.medium
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center
                ) {
                    Icon(Icons.Default.TaskAlt, contentDescription = null, tint = MaterialTheme.colorScheme.tertiary)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Hệ thống bảo vệ đã sẵn sàng",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onTertiaryContainer
                    )
                }
            }
        } else {
            LazyRow(
                contentPadding = PaddingValues(horizontal = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                if (!isRecordAudioGranted) {
                    item {
                        MiniPermissionCard(
                            icon = Icons.Default.Mic,
                            title = "Ghi âm",
                            description = "Nghe và phát hiện AI.",
                            onClick = onRequestRecordAudioPermission
                        )
                    }
                }
                if (!isCallCaptionEnabled) {
                    item {
                        MiniPermissionCard(
                            icon = Icons.Default.Subtitles,
                            title = "Đọc phụ đề",
                            description = "Đọc phụ đề cuộc gọi (nếu có).",
                            onClick = onRequestCallCaptionPermission
                        )
                    }
                }
                if (!isCallDetectionEnabled) {
                    item {
                        MiniPermissionCard(
                            icon = Icons.Default.AppRegistration,
                            title = "Nhận diện cuộc gọi",
                            description = "Phát hiện các cuộc gọi đến.",
                            onClick = onRequestCallDetectionPermission
                        )
                    }
                }
                if (!isCallScreeningEnabled) {
                    item {
                        MiniPermissionCard(
                            icon = Icons.Default.Call,
                            title = "Sàng lọc cuộc gọi",
                            description = "Lắng nghe cuộc gọi đúng cách.",
                            onClick = onRequestCallScreeningRole
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun MiniPermissionCard(
    icon: ImageVector,
    title: String,
    description: String,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .width(270.dp)
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = MaterialTheme.shapes.medium,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.error.copy(alpha = 0.5f))
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Surface(
                modifier = Modifier.size(32.dp),
                shape = MaterialTheme.shapes.small,
                color = MaterialTheme.colorScheme.errorContainer
            ) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(18.dp))
                }
            }
            Spacer(modifier = Modifier.width(8.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(text = title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, maxLines = 1)
                Text(text = description, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
            }
            Icon(Icons.Default.ChevronRight, contentDescription = "Cấp quyền", tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(16.dp))
        }
    }
}
