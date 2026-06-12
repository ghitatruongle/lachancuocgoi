package com.example.lachancuocgoi.ui.ResultPage

import android.content.Intent
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.automirrored.outlined.Article
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.livedata.observeAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import com.example.lachancuocgoi.RiskLevel
import com.example.lachancuocgoi.data.CallHistoryDao
import com.example.lachancuocgoi.ui.MonitoringPage.AlertHistorySection

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ResultPage(
    navController: NavController,
    onShowSettings: () -> Unit,
    historyId: Long?,
    callHistoryDao: CallHistoryDao
) {
    val context = LocalContext.current
    val factory = remember { ResultViewModelFactory(callHistoryDao) }
    val viewModel: ResultViewModel = viewModel(factory = factory)

    val historyItem by callHistoryDao.getById(historyId ?: -1).observeAsState()
    val alertHistory by viewModel.alertHistory.collectAsState()
    val isSaving by viewModel.isSaving.collectAsState()
    val saveResult by viewModel.saveResult.collectAsState()

    LaunchedEffect(historyItem) {
        viewModel.processAlertHistory(historyItem)
    }

    LaunchedEffect(saveResult) {
        saveResult?.let {
            Toast.makeText(context, it, Toast.LENGTH_SHORT).show()
            viewModel.clearSaveResult()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Lá chắn cuộc gọi", fontWeight = FontWeight.Bold)
                        Text("Phát hiện Lừa đảo & Bạo lực", style = MaterialTheme.typography.bodySmall)
                    }
                },
                actions = {
                    IconButton(onClick = onShowSettings) {
                        Icon(Icons.Filled.Settings, contentDescription = "Cài đặt")
                    }
                    historyItem?.let { item ->
                        val riskLevel = try { RiskLevel.valueOf(item.riskLevel) } catch (e: Exception) { RiskLevel.GREEN }
                        IconButton(onClick = {
                            val shareText = """
                                Lá chắn cuộc gọi - Kết quả phân tích:
                                Đánh giá: ${riskLevel.vietnameseName}
                                Tóm tắt: ${item.summary}
                                -------
                                Nội dung cuộc gọi:
                                ${if (item.transcript.isBlank()) "Không có dữ liệu" else item.transcript.replace("+", " ")}
                            """.trimIndent()
                            val shareIntent = Intent().apply {
                                action = Intent.ACTION_SEND
                                putExtra(Intent.EXTRA_TEXT, shareText)
                                type = "text/plain"
                            }
                            context.startActivity(Intent.createChooser(shareIntent, "Chia sẻ kết quả"))
                        }) {
                            Icon(Icons.Filled.Share, contentDescription = "Chia sẻ")
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text("Kết quả phân tích", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.height(16.dp))

            historyItem?.let { item ->
                val riskLevel = try { RiskLevel.valueOf(item.riskLevel) } catch (e: Exception) { RiskLevel.GREEN }
                
                AnalysisSummaryCard(riskLevel = riskLevel, summary = item.summary)
                Spacer(modifier = Modifier.height(16.dp))
                
                RecordingCard(
                    isSaving = isSaving,
                    transcript = item.transcript,
                    dateTime = item.dateTime,
                    onDownloadRequest = { trans, date -> 
                        viewModel.saveTranscript(context, trans, date)
                    }
                )
                Spacer(modifier = Modifier.height(16.dp))
                
                TranscriptCard(transcript = item.transcript)
                Spacer(modifier = Modifier.height(16.dp))
                
                AlertHistorySection(
                    alertHistory = alertHistory,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(modifier = Modifier.height(16.dp))
            } ?: run {
                Box(modifier = Modifier.fillMaxSize().padding(32.dp), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            }

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Button(onClick = { navController.navigate("home") { popUpTo("home") { inclusive = true } } }, modifier = Modifier.weight(1f)) {
                    Text("Màn hình chính")
                }
                OutlinedButton(onClick = { navController.navigate("history") { popUpTo("home") } }, modifier = Modifier.weight(1f)) {
                    Text("Xem lịch sử")
                }
            }
        }
    }
}

@Composable
fun AnalysisSummaryCard(riskLevel: RiskLevel, summary: String) {
    val riskColor = riskLevel.color
    val context = LocalContext.current

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Row(modifier = Modifier.height(IntrinsicSize.Min)) {
            Box(
                modifier = Modifier
                    .width(6.dp)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(topStart = 12.dp, bottomStart = 12.dp))
                    .background(riskColor)
            )
            Column(modifier = Modifier.padding(16.dp).weight(1f)) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Text("Đánh giá", style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = riskLevel.vietnameseName,
                            color = riskColor,
                            fontWeight = FontWeight.Bold
                        )
                        IconButton(onClick = {
                            val shareIntent = Intent().apply {
                                action = Intent.ACTION_SEND
                                putExtra(Intent.EXTRA_TEXT, "Lá chắn cuộc gọi - Đánh giá: ${riskLevel.vietnameseName}\nTóm tắt: $summary")
                                type = "text/plain"
                            }
                            context.startActivity(Intent.createChooser(shareIntent, "Chia sẻ đánh giá"))
                        }) {
                            Icon(Icons.Filled.Share, contentDescription = "Chia sẻ đánh giá", modifier = Modifier.size(20.dp))
                        }
                    }
                }
                Spacer(modifier = Modifier.height(8.dp))
                Text("Tóm tắt: $summary", style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}

@Composable
fun RecordingCard(isSaving: Boolean, transcript: String, dateTime: String, onDownloadRequest: (String, String) -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Lưu trữ", style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.height(8.dp))

            Text(
                "* Vì lý do bảo mật, âm thanh cuộc gọi không được lưu lại. Văn bản cuộc gọi được lưu cục bộ để bạn xem lại và tải xuống trực tiếp.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontStyle = FontStyle.Italic
            )

            Spacer(modifier = Modifier.height(16.dp))

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                OutlinedButton(
                    onClick = { onDownloadRequest(transcript, dateTime) },
                    enabled = !isSaving
                ) {
                    if (isSaving) {
                        CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Đang tải xuống...")
                    } else {
                        Icon(Icons.AutoMirrored.Outlined.Article, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Tải nội dung (TXT)")
                    }
                }
            }
        }
    }
}

@Composable
fun TranscriptCard(transcript: String) {
    val context = LocalContext.current
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "Nội dung cuộc gọi (Bản lưu cục bộ)", 
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Bold
                )
                IconButton(onClick = {
                    val content = if (transcript.isBlank()) "Không có dữ liệu âm thanh." else transcript.replace("+", " ")
                    val shareIntent = Intent().apply {
                        action = Intent.ACTION_SEND
                        putExtra(Intent.EXTRA_TEXT, "Nội dung cuộc gọi:\n$content")
                        type = "text/plain"
                    }
                    context.startActivity(Intent.createChooser(shareIntent, "Chia sẻ nội dung"))
                }) {
                    Icon(Icons.Filled.Share, contentDescription = "Chia sẻ nội dung", modifier = Modifier.size(20.dp))
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
            HorizontalDivider(color = MaterialTheme.colorScheme.surfaceVariant)
            Spacer(modifier = Modifier.height(8.dp))
            
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 250.dp)
                    .verticalScroll(rememberScrollState())
            ) {
                Text(
                    text = if (transcript.isBlank()) "Không có dữ liệu âm thanh." else transcript.replace("+", " "),
                    style = MaterialTheme.typography.bodyMedium,
                    fontFamily = FontFamily.Monospace,
                    modifier = Modifier.padding(4.dp)
                )
            }
        }
    }
}
