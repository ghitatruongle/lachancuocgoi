package com.example.lachancuocgoi.ui.HomePage.RightsDialog

import android.Manifest
import android.content.Intent
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.StringRes
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Subtitles
import androidx.compose.material.icons.filled.TaskAlt
import androidx.compose.material.icons.filled.WarningAmber
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.example.lachancuocgoi.R
import com.example.lachancuocgoi.ui.theme.AppSpacing

private data class PermissionItemUi(
    val icon: ImageVector,
    @StringRes val titleRes: Int,
    @StringRes val descriptionRes: Int,
    @StringRes val readyDescriptionRes: Int,
    @StringRes val actionLabelRes: Int,
    val granted: Boolean,
    val onClick: () -> Unit
)

@Composable
fun PermissionsTab(
    modifier: Modifier = Modifier,
    onRequestCallScreening: () -> Unit,
    onRequestCallLog: () -> Unit,
    onRequestForegroundService: () -> Unit,
    onRequestNotifications: () -> Unit,
    onRequestDrawOverlay: () -> Unit
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    var isRecordAudioGranted by remember { mutableStateOf(PermissionUtils.isRecordAudioGranted(context)) }
    var isAccessibilityProtectionEnabled by remember {
        mutableStateOf(PermissionUtils.isAccessibilityProtectionEnabled(context))
    }
    var isCallScreeningHeld by remember { mutableStateOf(PermissionUtils.isCallScreeningRoleHeld(context)) }
    var isDrawOverlayGranted by remember { mutableStateOf(PermissionUtils.isDrawOverlayGranted(context)) }
    var isNotificationsGranted by remember { mutableStateOf(PermissionUtils.isNotificationsGranted(context)) }
    var hasPhoneCallAccess by remember { mutableStateOf(PermissionUtils.hasPhoneCallAccess(context)) }
    var isForegroundServiceGranted by remember {
        mutableStateOf(PermissionUtils.isForegroundServiceGranted(context))
    }

    fun refreshPermissionStates() {
        isRecordAudioGranted = PermissionUtils.isRecordAudioGranted(context)
        isAccessibilityProtectionEnabled = PermissionUtils.isAccessibilityProtectionEnabled(context)
        isCallScreeningHeld = PermissionUtils.isCallScreeningRoleHeld(context)
        isDrawOverlayGranted = PermissionUtils.isDrawOverlayGranted(context)
        isNotificationsGranted = PermissionUtils.isNotificationsGranted(context)
        hasPhoneCallAccess = PermissionUtils.hasPhoneCallAccess(context)
        isForegroundServiceGranted = PermissionUtils.isForegroundServiceGranted(context)
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) {
        refreshPermissionStates()
    }

    val settingsLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartActivityForResult()
    ) {
        refreshPermissionStates()
    }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                refreshPermissionStates()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val essentialPermissions = listOf(
        PermissionItemUi(
            icon = Icons.Default.Mic,
            titleRes = R.string.permission_microphone_title,
            descriptionRes = R.string.permission_microphone_desc,
            readyDescriptionRes = R.string.permission_microphone_ready_desc,
            actionLabelRes = R.string.permission_action_grant_microphone,
            granted = isRecordAudioGranted,
            onClick = { permissionLauncher.launch(Manifest.permission.RECORD_AUDIO) }
        ),
        PermissionItemUi(
            icon = Icons.Default.Subtitles,
            titleRes = R.string.permission_accessibility_title,
            descriptionRes = R.string.permission_accessibility_desc,
            readyDescriptionRes = R.string.permission_accessibility_ready_desc,
            actionLabelRes = R.string.permission_action_open_accessibility,
            granted = isAccessibilityProtectionEnabled,
            onClick = { settingsLauncher.launch(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }
        ),
        PermissionItemUi(
            icon = Icons.Default.Call,
            titleRes = R.string.permission_screening_title,
            descriptionRes = R.string.permission_screening_desc,
            readyDescriptionRes = R.string.permission_screening_ready_desc,
            actionLabelRes = R.string.permission_action_enable_role,
            granted = isCallScreeningHeld,
            onClick = onRequestCallScreening
        )
    )

    val supportingPermissions = listOf(
        PermissionItemUi(
            icon = Icons.Default.Layers,
            titleRes = R.string.permission_overlay_title,
            descriptionRes = R.string.permission_overlay_desc,
            readyDescriptionRes = R.string.permission_overlay_ready_desc,
            actionLabelRes = R.string.permission_action_enable_overlay,
            granted = isDrawOverlayGranted,
            onClick = onRequestDrawOverlay
        ),
        PermissionItemUi(
            icon = Icons.Default.Notifications,
            titleRes = R.string.permission_notifications_title,
            descriptionRes = R.string.permission_notifications_desc,
            readyDescriptionRes = R.string.permission_notifications_ready_desc,
            actionLabelRes = R.string.permission_action_enable_notifications,
            granted = isNotificationsGranted,
            onClick = onRequestNotifications
        ),
        PermissionItemUi(
            icon = Icons.Default.History,
            titleRes = R.string.permission_phone_access_title,
            descriptionRes = R.string.permission_phone_access_desc,
            readyDescriptionRes = R.string.permission_phone_access_ready_desc,
            actionLabelRes = R.string.permission_action_enable_phone_access,
            granted = hasPhoneCallAccess,
            onClick = onRequestCallLog
        ),
        PermissionItemUi(
            icon = Icons.Default.Security,
            titleRes = R.string.permission_foreground_title,
            descriptionRes = R.string.permission_foreground_desc,
            readyDescriptionRes = R.string.permission_foreground_ready_desc,
            actionLabelRes = R.string.permission_action_enable_background,
            granted = isForegroundServiceGranted,
            onClick = onRequestForegroundService
        )
    )

    val essentialGrantedCount = essentialPermissions.count { it.granted }
    val supportingGrantedCount = supportingPermissions.count { it.granted }

    Column(
        modifier = modifier
            .verticalScroll(rememberScrollState())
            .padding(horizontal = AppSpacing.Lg, vertical = AppSpacing.Sm),
        verticalArrangement = Arrangement.spacedBy(AppSpacing.Md)
    ) {
        PermissionReadinessCard(
            essentialGrantedCount = essentialGrantedCount,
            essentialTotalCount = essentialPermissions.size,
            supportingGrantedCount = supportingGrantedCount,
            supportingTotalCount = supportingPermissions.size
        )

        PermissionSection(
            title = stringResource(R.string.rights_section_essential),
            description = stringResource(R.string.rights_section_essential_desc),
            items = essentialPermissions
        )

        PermissionSection(
            title = stringResource(R.string.rights_section_supporting),
            description = stringResource(R.string.rights_section_supporting_desc),
            items = supportingPermissions
        )

        Text(
            text = stringResource(R.string.rights_footer_note),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun PermissionReadinessCard(
    essentialGrantedCount: Int,
    essentialTotalCount: Int,
    supportingGrantedCount: Int,
    supportingTotalCount: Int
) {
    val essentialProgress = if (essentialTotalCount == 0) {
        0f
    } else {
        essentialGrantedCount.toFloat() / essentialTotalCount.toFloat()
    }
    val isReady = essentialGrantedCount == essentialTotalCount

    Card(
        colors = CardDefaults.cardColors(
            containerColor = if (isReady) {
                MaterialTheme.colorScheme.secondaryContainer
            } else {
                MaterialTheme.colorScheme.surfaceVariant
            }
        ),
        shape = MaterialTheme.shapes.medium
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(AppSpacing.Sm),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.Xs)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(AppSpacing.Xs)
            ) {
                Icon(
                    imageVector = if (isReady) Icons.Default.TaskAlt else Icons.Default.WarningAmber,
                    contentDescription = null,
                    tint = if (isReady) MaterialTheme.colorScheme.tertiary else MaterialTheme.colorScheme.primary
                )
                Column {
                    Text(
                        text = stringResource(R.string.rights_summary_title),
                        style = MaterialTheme.typography.titleSmall
                    )
                    Text(
                        text = if (isReady) {
                            stringResource(R.string.rights_summary_ready)
                        } else {
                            stringResource(R.string.rights_summary_missing)
                        },
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            LinearProgressIndicator(
                progress = { essentialProgress },
                modifier = Modifier.fillMaxWidth(),
                color = if (isReady) MaterialTheme.colorScheme.tertiary else MaterialTheme.colorScheme.primary,
                trackColor = MaterialTheme.colorScheme.background
            )

            Text(
                text = stringResource(
                    R.string.rights_summary_essential,
                    essentialGrantedCount,
                    essentialTotalCount
                ),
                style = MaterialTheme.typography.labelLarge
            )
            Text(
                text = stringResource(
                    R.string.rights_summary_supporting,
                    supportingGrantedCount,
                    supportingTotalCount
                ),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun PermissionSection(
    title: String,
    description: String,
    items: List<PermissionItemUi>
) {
    Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.Xs)) {
        Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.Xxxs)) {
            Text(text = title, style = MaterialTheme.typography.titleMedium)
            Text(
                text = description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.Xs)) {
            items.forEach { item ->
                PermissionItemCard(item = item)
            }
        }
    }
}

@Composable
private fun PermissionItemCard(item: PermissionItemUi) {
    val containerColor = if (item.granted) {
        MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.45f)
    } else {
        MaterialTheme.colorScheme.surface
    }
    val borderColor = if (item.granted) {
        MaterialTheme.colorScheme.secondary.copy(alpha = 0.3f)
    } else {
        MaterialTheme.colorScheme.outline.copy(alpha = 0.18f)
    }
    val iconBackground = if (item.granted) {
        MaterialTheme.colorScheme.tertiaryContainer
    } else {
        MaterialTheme.colorScheme.surfaceVariant
    }
    val iconTint = if (item.granted) {
        MaterialTheme.colorScheme.tertiary
    } else {
        MaterialTheme.colorScheme.primary
    }

    Card(
        colors = CardDefaults.cardColors(containerColor = containerColor),
        shape = MaterialTheme.shapes.medium,
        border = BorderStroke(1.dp, borderColor)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(AppSpacing.Sm),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.Xs)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Row(
                    modifier = Modifier.weight(1f),
                    horizontalArrangement = Arrangement.spacedBy(AppSpacing.Xs),
                    verticalAlignment = Alignment.Top
                ) {
                    Surface(
                        modifier = Modifier.size(44.dp),
                        shape = MaterialTheme.shapes.small,
                        color = iconBackground
                    ) {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = item.icon,
                                contentDescription = null,
                                tint = iconTint
                            )
                        }
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(AppSpacing.Xxxs)) {
                        Text(
                            text = stringResource(item.titleRes),
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            text = stringResource(
                                if (item.granted) item.readyDescriptionRes else item.descriptionRes
                            ),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                PermissionStatusBadge(granted = item.granted)
            }

            if (!item.granted) {
                FilledTonalButton(
                    onClick = item.onClick,
                    modifier = Modifier.align(Alignment.End)
                ) {
                    Text(text = stringResource(item.actionLabelRes))
                }
            }
        }
    }
}

@Composable
fun PermissionCard(
    icon: ImageVector,
    title: String,
    description: String,
    granted: Boolean,
    onClick: () -> Unit
) {
    val containerColor = if (granted) {
        MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.45f)
    } else {
        MaterialTheme.colorScheme.surface
    }
    val borderColor = if (granted) {
        MaterialTheme.colorScheme.secondary.copy(alpha = 0.3f)
    } else {
        MaterialTheme.colorScheme.outline.copy(alpha = 0.18f)
    }
    val iconBackground = if (granted) {
        MaterialTheme.colorScheme.tertiaryContainer
    } else {
        MaterialTheme.colorScheme.surfaceVariant
    }
    val iconTint = if (granted) {
        MaterialTheme.colorScheme.tertiary
    } else {
        MaterialTheme.colorScheme.primary
    }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = !granted, onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = containerColor),
        shape = MaterialTheme.shapes.medium,
        border = BorderStroke(1.dp, borderColor)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(AppSpacing.Sm),
            horizontalArrangement = Arrangement.spacedBy(AppSpacing.Xs),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Surface(
                modifier = Modifier.size(44.dp),
                shape = MaterialTheme.shapes.small,
                color = iconBackground
            ) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = iconTint
                    )
                }
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = if (granted) stringResource(R.string.permission_status_ready) else description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            PermissionStatusBadge(granted = granted)
        }
    }
}

@Composable
private fun PermissionStatusBadge(granted: Boolean) {
    val containerColor = if (granted) {
        MaterialTheme.colorScheme.tertiaryContainer
    } else {
        MaterialTheme.colorScheme.surfaceVariant
    }
    val textColor = if (granted) {
        MaterialTheme.colorScheme.onTertiaryContainer
    } else {
        MaterialTheme.colorScheme.onSurfaceVariant
    }

    Surface(
        color = containerColor,
        shape = MaterialTheme.shapes.small
    ) {
        Row(
            modifier = Modifier.padding(horizontal = AppSpacing.Xs, vertical = AppSpacing.Xxs),
            horizontalArrangement = Arrangement.spacedBy(AppSpacing.Xxs),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Surface(
                modifier = Modifier.size(8.dp),
                shape = MaterialTheme.shapes.extraSmall,
                color = if (granted) MaterialTheme.colorScheme.tertiary else MaterialTheme.colorScheme.outline
            ) {}
            Text(
                text = stringResource(
                    if (granted) R.string.permission_status_ready else R.string.permission_status_required
                ),
                style = MaterialTheme.typography.labelMedium,
                color = textColor
            )
        }
    }
}
