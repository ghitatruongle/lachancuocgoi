package com.example.lachancuocgoi.ui.MonitoringPage

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.lachancuocgoi.data.AlertHistoryEntry

/**
 * Component hiển thị lịch sử cảnh báo của một cuộc gọi.
 * Hiển thị danh sách các lần cảnh báo đã được hiển thị (L1 batch, L2 batch, L3 immediate).
 */
@Composable
fun AlertHistorySection(
    alertHistory: List<AlertHistoryEntry>,
    modifier: Modifier = Modifier
) {
    if (alertHistory.isEmpty()) {
        return
    }
    
    Column(modifier = modifier.fillMaxWidth()) {
        // Header
        Text(
            text = "⚠️ LỊCH SỬ CẢNH BÁO",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.padding(bottom = 12.dp)
        )
        
        HorizontalDivider(
            modifier = Modifier.padding(bottom = 12.dp),
            color = MaterialTheme.colorScheme.outlineVariant
        )
        
        // Hiển thị theo thứ tự ngược (mới nhất lên đầu)
        alertHistory.reversed().forEachIndexed { index, entry ->
            AlertHistoryCard(entry)
            if (index < alertHistory.size - 1) {
                Spacer(modifier = Modifier.height(8.dp))
            }
        }
    }
}

/**
 * Card hiển thị một entry trong lịch sử cảnh báo.
 */
@Composable
fun AlertHistoryCard(entry: AlertHistoryEntry) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = entry.getRiskLevelColor().copy(alpha = 0.08f)
        ),
        shape = RoundedCornerShape(8.dp)
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Icon + Time
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = entry.getRiskLevelIcon(),
                        fontSize = 20.sp
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = entry.getFormattedTime(),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
                
                // Level badge

            }
            
            Spacer(modifier = Modifier.height(6.dp))
            
            // Alert count (nếu là batch)
            if (entry.alertCount > 1) {
                Text(
                    text = "${entry.alertCount} cảnh báo • Mức cao nhất: ${entry.riskLevel}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontWeight = FontWeight.Medium
                )
                Spacer(modifier = Modifier.height(4.dp))
            }
            
            // Main reason
            Text(
                text = entry.displayedReason,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
                fontWeight = FontWeight.Normal
            )
            
            // All reasons (if batch và có nhiều lý do)
            entry.allReasons?.let { reasons ->
                if (reasons.size > 1) {
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = "Chi tiết: ${reasons.take(3).joinToString(", ")}${if (reasons.size > 3) "..." else ""}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontStyle = FontStyle.Italic,
                        lineHeight = 16.sp
                    )
                }
            }
        }
    }
}
