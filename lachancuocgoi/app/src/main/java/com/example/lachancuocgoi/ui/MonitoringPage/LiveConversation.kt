package com.example.lachancuocgoi.ui.MonitoringPage

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.lachancuocgoi.Analysis.KeywordMatch

@Composable
fun LiveConversation(transcript: String, matches: List<KeywordMatch>) {
    val listState = rememberLazyListState()

    // Sửa lỗi hiển thị: Thay thế dấu '+' bằng khoảng trắng nếu có (đề phòng lỗi encode/decode)
    val cleanTranscript = transcript.replace("+", " ")

    LaunchedEffect(cleanTranscript) {
        if (cleanTranscript.isNotEmpty()) {
            listState.animateScrollToItem(0)
        }
    }

    val annotatedTranscript = buildAnnotatedString {
        append(cleanTranscript)
        matches.forEach { match ->
            // Update: Chỉ highlight nếu mức độ rủi ro là Vàng, Cam hoặc Đỏ
            // Filter keywords based on risk level (Yellow, Orange, Red)
            if (match.level != com.example.lachancuocgoi.RiskLevel.GREEN) {
                 val keyword = match.keyword
                 // Kiểm tra từ khóa trong bản text sạch
                 var startIndex = cleanTranscript.indexOf(keyword, ignoreCase = true)
                 while (startIndex >= 0) {
                     val endIndex = startIndex + keyword.length
                     addStyle(
                         style = SpanStyle(
                             color = match.level.color,
                             fontWeight = FontWeight.Bold,
                             background = match.level.color.copy(alpha = 0.2f)
                         ),
                         start = startIndex,
                         end = endIndex
                     )
                     startIndex = cleanTranscript.indexOf(keyword, startIndex + 1, ignoreCase = true)
                 }
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .clip(MaterialTheme.shapes.large)
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(16.dp)
    ) {
        LazyColumn(state = listState, reverseLayout = true) {
            item {
                Text(text = annotatedTranscript)
            }
        }
    }
}
