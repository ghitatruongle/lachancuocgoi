package com.example.lachancuocgoi.ui.HomePage.SettingsDialog

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog

@Composable
fun SettingsDialog(
    settings: SettingsState,
    onSettingsChange: (SettingsState) -> Unit,
    onDismiss: () -> Unit
) {
    var showDevPasswordDialog by remember { mutableStateOf(false) }

    // Đọc trực tiếp observable state — Compose tự recompose khi thay đổi
    val isDevActive by DeveloperModeManager.isActive

    if (showDevPasswordDialog) {
        DevPasswordDialog(
            onDismiss = { showDevPasswordDialog = false },
            onSuccess = {
                showDevPasswordDialog = false
                DeveloperModeManager.activateDevMode()
            }
        )
    }

    Dialog(onDismissRequest = onDismiss) {
        Surface(
            shape = MaterialTheme.shapes.large,
            color = MaterialTheme.colorScheme.surface,
            modifier = Modifier.padding(16.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // ── Tap 10 lần → kích hoạt | Tap 3 lần khi active → tắt ──
                    Text(
                        text = if (isDevActive)
                            "Cài đặt  🛠️ ${DeveloperModeManager.remainingSeconds()}s"
                        else
                            "Cài đặt",
                        style = MaterialTheme.typography.headlineSmall,
                        modifier = Modifier
                            .weight(1f)
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null
                            ) {
                                when (DeveloperModeManager.onTitleTap()) {
                                    is DeveloperModeManager.TapResult.ShowPassword -> {
                                        showDevPasswordDialog = true
                                    }
                                    is DeveloperModeManager.TapResult.Deactivated -> {
                                        // isActive.value đã được set trong deactivateDevMode()
                                    }
                                    is DeveloperModeManager.TapResult.Nothing -> { /* chờ thêm */ }
                                }
                            }
                    )
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, contentDescription = "Đóng")
                    }
                }
                Spacer(modifier = Modifier.padding(bottom = 8.dp))
                SettingsTab(settings, onSettingsChange)
            }
        }
    }
}
