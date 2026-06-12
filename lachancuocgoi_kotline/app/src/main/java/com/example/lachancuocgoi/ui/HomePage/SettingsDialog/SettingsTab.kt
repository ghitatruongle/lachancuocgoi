package com.example.lachancuocgoi.ui.HomePage.SettingsDialog

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@Composable
fun SettingsTab(settings: SettingsState, onSettingsChange: (SettingsState) -> Unit) {
    Column(
        modifier = Modifier
            .padding(top = 16.dp)
            .verticalScroll(rememberScrollState()), // Thêm khả năng cuộn
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Cài đặt Giao diện
        val isDarkTheme = settings.isDarkTheme
        val themeIcon = if (isDarkTheme) Icons.Default.DarkMode else Icons.Default.LightMode
        val themeTitle = if (isDarkTheme) "Giao diện tối" else "Giao diện sáng"
        val themeDescription = if (isDarkTheme) "Tắt để chuyển sang giao diện sáng." else "Bật để chuyển sang giao diện tối."

        SettingToggleCard(
            modifier = Modifier.fillMaxWidth(),
            title = themeTitle,
            description = themeDescription,
            icon = themeIcon,
            checked = isDarkTheme,
            onCheckedChange = { onSettingsChange(settings.copy(isDarkTheme = it)) }
        )

        // Cài đặt Chế độ Phân tích - Bọc trong Card
        Card(modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
            AnalysisSensitivitySetting(
                selectedMode = settings.analysisMode,
                onModeSelected = { onSettingsChange(settings.copy(analysisMode = it)) }
            )
        }

        // Cài đặt Khuếch đại âm thanh
        SettingToggleCard(
            modifier = Modifier.fillMaxWidth(),
            title = "Khuếch đại âm thanh",
            description = "Tự động tăng âm lượng cuộc gọi để cải thiện độ chính xác.",
            icon = Icons.Default.GraphicEq,
            checked = settings.audioBoost,
            onCheckedChange = { onSettingsChange(settings.copy(audioBoost = it)) }
        )

        // ── CREATOR MODE SECTION ─────────────────────────────────────────────
        // Hoàn toàn ẩn với người dùng phổ thông.
        // Chỉ hiện khi Developer Mode đang active (tap title "Cài đặt" × 10 + mật mã).
        val isDevActive by DeveloperModeManager.isActive
        AnimatedVisibility(
            visible = isDevActive,
            enter = expandVertically(),
            exit = shrinkVertically()
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                HorizontalDivider()
                Text(
                    text = "🎬  Nhà sáng tạo",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.padding(top = 4.dp)
                )

                // Toggle: Capture audio màn hình
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.primaryContainer
                    )
                ) {
                    Box(modifier = Modifier.padding(16.dp).fillMaxWidth()) {
                        Column(modifier = Modifier.align(Alignment.CenterStart).padding(end = 56.dp)) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Videocam,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.onPrimaryContainer
                                )
                                Text(
                                    text = "Chụp audio màn hình",
                                    fontWeight = FontWeight.Medium,
                                    color = MaterialTheme.colorScheme.onPrimaryContainer
                                )
                            }
                            Text(
                                text = "Lấy audio VoIP trực tiếp từ hệ thống để phân tích. Chỉ hoạt động với Zalo/Telegram/WhatsApp.",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onPrimaryContainer
                            )
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(4.dp),
                                modifier = Modifier.padding(top = 4.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Warning,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.error,
                                    modifier = Modifier.height(14.dp)
                                )
                                Text(
                                    text = "Yêu cầu đồng ý quyền ghi màn hình khi bắt đầu giám sát.",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.error
                                )
                            }
                        }
                        Switch(
                            checked = settings.creatorAudioCapture,
                            onCheckedChange = { onSettingsChange(settings.copy(creatorAudioCapture = it)) },
                            modifier = Modifier.align(Alignment.CenterEnd)
                        )
                    }
                }
            }
        }
        // ── END CREATOR MODE SECTION ─────────────────────────────────────────
    }
}


@Composable
fun SettingToggleCard(
    modifier: Modifier = Modifier,
    title: String,
    description: String,
    icon: ImageVector,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Card(
        modifier = modifier.height(120.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Box(modifier = Modifier.padding(16.dp).fillMaxSize()) {
            Icon(
                imageVector = icon,
                contentDescription = title,
                modifier = Modifier.align(Alignment.TopStart)
            )
            Column(modifier = Modifier.align(Alignment.BottomStart)) {
                Text(
                    text = title,
                    fontWeight = FontWeight.Medium,
                )
                Text(
                    text = description,
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            Switch(
                checked = checked,
                onCheckedChange = onCheckedChange,
                modifier = Modifier.align(Alignment.BottomEnd)
            )
        }
    }
}
