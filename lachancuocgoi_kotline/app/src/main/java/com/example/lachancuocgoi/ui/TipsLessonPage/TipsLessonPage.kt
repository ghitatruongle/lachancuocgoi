package com.example.lachancuocgoi.ui.TipsLessonPage

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material.icons.rounded.Share
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController

enum class TipSeverity { HIGH, MEDIUM }

data class ScamTip(
    val icon: String,
    val title: String,
    val description: String,
    val severity: TipSeverity
)

private val TIPS = listOf(
    ScamTip(
        icon = "🏛️",
        title = "Công an không bao giờ gọi điện yêu cầu chuyển tiền",
        description = "Cơ quan công an thực sự sẽ mời bạn đến trực tiếp làm việc, không bao giờ yêu cầu bạn chuyển tiền qua điện thoại để \"phục vụ điều tra\".",
        severity = TipSeverity.HIGH
    ),
    ScamTip(
        icon = "🔐",
        title = "Không bao giờ đọc mã OTP cho bất kỳ ai",
        description = "OTP (mã một lần) là bí mật tuyệt đối. Ngân hàng, Zalo, hay bất kỳ dịch vụ nào cũng không yêu cầu bạn đọc OTP qua điện thoại.",
        severity = TipSeverity.HIGH
    ),
    ScamTip(
        icon = "💰",
        title = "Lợi nhuận cao bất thường = Bẫy lừa đảo",
        description = "Không có khoản đầu tư hợp pháp nào cam kết lợi nhuận 20-30% mỗi tháng. Nếu ai hứa vậy, đó là dấu hiệu lừa đảo đầu tư.",
        severity = TipSeverity.MEDIUM
    ),
    ScamTip(
        icon = "📦",
        title = "Bưu kiện từ nước ngoài hiếm khi bị \"giữ hải quan\"",
        description = "Kịch bản \"bưu kiện quà bị kẹt hải quan, cần đóng phí\" là chiêu lừa phổ biến. Hãy liên hệ trực tiếp với hải quan chính thức để xác minh.",
        severity = TipSeverity.MEDIUM
    ),
    ScamTip(
        icon = "🧑‍💼",
        title = "Việc làm online yêu cầu nạp tiền trước là lừa đảo",
        description = "\"Chốt đơn, nhận hoa hồng\" nghe hấp dẫn nhưng khi họ yêu cầu bạn nạp tiền để \"kích hoạt nhiệm vụ\", đó là bẫy mất tiền.",
        severity = TipSeverity.MEDIUM
    ),
    ScamTip(
        icon = "📱",
        title = "Không cài app lạ theo yêu cầu qua điện thoại",
        description = "Không cơ quan chính phủ hay nhà mạng nào yêu cầu bạn cài app VNeID, Thuế, hay hỗ trợ kỹ thuật theo hướng dẫn qua điện thoại.",
        severity = TipSeverity.HIGH
    ),
    ScamTip(
        icon = "🎁",
        title = "Trúng thưởng mà phải đóng phí trước = Lừa đảo 100%",
        description = "Giải thưởng thật không bao giờ yêu cầu người trúng thưởng đóng phí kiểm duyệt, phí thuế, hay phí vận chuyển trước khi nhận.",
        severity = TipSeverity.MEDIUM
    ),
    ScamTip(
        icon = "⏰",
        title = "Tạo áp lực thời gian = Dấu hiệu lừa đảo",
        description = "\"Chuyển ngay hôm nay còn kịp\", \"trong 2 tiếng nữa hết hạn\" — kẻ lừa đảo dùng áp lực thời gian để bạn không kịp suy nghĩ. Hãy dừng lại và gọi cho người thân.",
        severity = TipSeverity.MEDIUM
    )
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TipsLessonPage(navController: NavController) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            Icons.Outlined.Lightbulb,
                            contentDescription = null,
                            tint = Color(0xFFFFC107),
                            modifier = Modifier.size(22.dp)
                        )
                        Spacer(Modifier.width(8.dp))
                        Text("Mẹo chống lừa đảo")
                    }
                },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Quay lại")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            item {
                Text(
                    "Những điều cần nhớ để tránh bị lừa đảo qua điện thoại:",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 8.dp, bottom = 4.dp)
                )
            }
            itemsIndexed(TIPS) { index, tip ->
                TipCard(index = index + 1, tip = tip)
            }
            item { Spacer(Modifier.height(16.dp)) }
        }
    }
}

@Composable
private fun TipCard(index: Int, tip: ScamTip) {
    val context = LocalContext.current

    // Auto color scaling for Light/Dark Mode based on Material Theme
    val containerColor = if (tip.severity == TipSeverity.HIGH) {
        MaterialTheme.colorScheme.errorContainer
    } else {
        MaterialTheme.colorScheme.tertiaryContainer
    }

    val onContainerColor = if (tip.severity == TipSeverity.HIGH) {
        MaterialTheme.colorScheme.onErrorContainer
    } else {
        MaterialTheme.colorScheme.onTertiaryContainer
    }

    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = containerColor.copy(alpha = 0.6f)
        ),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier.padding(12.dp)
        ) {
            Row(verticalAlignment = Alignment.Top) {
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .clip(CircleShape)
                        .background(onContainerColor.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "$index",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        color = onContainerColor
                    )
                }
                Spacer(Modifier.width(10.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(tip.icon, fontSize = 16.sp)
                        Spacer(Modifier.width(6.dp))
                        Text(
                            tip.title,
                            fontWeight = FontWeight.SemiBold,
                            style = MaterialTheme.typography.bodyLarge,
                            color = onContainerColor
                        )
                    }
                    Spacer(Modifier.height(6.dp))
                    Text(
                        tip.description,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.9f)
                    )
                }
            }

            Spacer(Modifier.height(8.dp))

            // Share Button
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                IconButton(
                    onClick = {
                        val sendIntent: Intent = Intent().apply {
                            action = Intent.ACTION_SEND
                            putExtra(Intent.EXTRA_TEXT, "💡 Cảnh giác lừa đảo: ${tip.title}\n\n${tip.description}\n\n(Mẹo từ ứng dụng Lá chắn cuộc gọi)")
                            type = "text/plain"
                        }
                        val shareIntent = Intent.createChooser(sendIntent, "Chia sẻ mẹo này")
                        context.startActivity(shareIntent)
                    },
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        Icons.Rounded.Share,
                        contentDescription = "Chia sẻ",
                        modifier = Modifier.size(20.dp),
                        tint = onContainerColor
                    )
                }
            }
        }
    }
}