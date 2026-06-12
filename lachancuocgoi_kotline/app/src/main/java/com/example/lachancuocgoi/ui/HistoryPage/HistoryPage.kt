package com.example.lachancuocgoi.ui.HistoryPage

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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.input.ImeAction
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import com.example.lachancuocgoi.data.CallHistory
import com.example.lachancuocgoi.data.CallHistoryDao
import com.example.lachancuocgoi.ui.HistoryPage.ItemHistory.HistoryItemCard
import kotlinx.coroutines.CoroutineScope

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HistoryPage(
    navController: NavController,
    callHistoryDao: CallHistoryDao,
    onShowSettings: () -> Unit,
    coroutineScope: CoroutineScope
) {
    val factory = remember { HistoryViewModelFactory(callHistoryDao) }
    val viewModel: HistoryViewModel = viewModel(factory = factory)

    val historyItems by viewModel.filteredHistoryItems.collectAsState()
    val searchQuery by viewModel.searchQuery.collectAsState()

    var itemToDelete by remember { mutableStateOf<CallHistory?>(null) }
    var showDeleteAllDialog by remember { mutableStateOf(false) }

    val focusManager = LocalFocusManager.current

    if (showDeleteAllDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteAllDialog = false },
            title = { Text("Xác nhận xóa") },
            text = { Text("Bạn muốn xóa tất cả dữ liệu cuộc gọi?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.deleteAll()
                        showDeleteAllDialog = false
                    }
                ) {
                    Text("Xóa")
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteAllDialog = false }) {
                    Text("Quay lại")
                }
            }
        )
    }

    itemToDelete?.let { item ->
        AlertDialog(
            onDismissRequest = { itemToDelete = null },
            title = { Text("Xác nhận xóa") },
            text = { Text("Xác nhận xóa lịch sử cuộc gọi này?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.deleteItem(item.id)
                        itemToDelete = null
                    }
                ) {
                    Text("Xóa")
                }
            },
            dismissButton = {
                TextButton(onClick = { itemToDelete = null }) {
                    Text("Quay lại")
                }
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Lịch sử giám sát") },
                navigationIcon = {
                    IconButton(onClick = { navController.navigate("home") { popUpTo("home") { inclusive = true } } }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Quay về Trang chủ")
                    }
                },
                actions = {
                    IconButton(onClick = onShowSettings) {
                        Icon(Icons.Default.Settings, contentDescription = "Cài đặt")
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(modifier = Modifier.padding(paddingValues).padding(horizontal = 16.dp)) {
            // Cập nhật thanh tìm kiếm chuyên nghiệp hơn
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { viewModel.updateSearchQuery(it) },
                placeholder = { Text("Tìm theo nội dung, mức độ, ngày tháng...") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = "Tìm kiếm") },
                trailingIcon = {
                    if (searchQuery.isNotEmpty()) {
                        IconButton(onClick = {
                            viewModel.updateSearchQuery("")
                            focusManager.clearFocus()
                        }) {
                            Icon(Icons.Default.Close, contentDescription = "Xóa tìm kiếm")
                        }
                    }
                },
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(onSearch = { focusManager.clearFocus() }),
                shape = MaterialTheme.shapes.large,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant
                )
            )

            Row(
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text("Lịch sử cuộc gọi", style = MaterialTheme.typography.titleMedium)
                if (historyItems.isNotEmpty()) {
                    TextButton(onClick = { showDeleteAllDialog = true }) {
                        Text("Xóa tất cả", color = Color.Red)
                    }
                }
            }
            Spacer(modifier = Modifier.height(16.dp))

            if (historyItems.isEmpty()) {
                HistoryEmptyState(
                    message = if (searchQuery.isBlank()) {
                        "Lịch sử trống."
                    } else {
                        "Không tìm thấy kết quả."
                    },
                    secondaryMessage = if (searchQuery.isBlank()) {
                        "Dữ liệu cuộc gọi chỉ được lưu trên thiết bị này để bạn xem lại trực tiếp."
                    } else {
                        "Không tìm thấy kết quả nào khớp với \"$searchQuery\"."
                    }
                )
            } else {
                LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    items(historyItems, key = { it.id }) { item ->
                        val dismissState = rememberSwipeToDismissBoxState(
                            confirmValueChange = { direction ->
                                if (direction == SwipeToDismissBoxValue.EndToStart) {
                                    itemToDelete = item
                                }
                                false // Do not dismiss automatically
                            }
                        )

                        SwipeToDismissBox(
                            state = dismissState,
                            enableDismissFromStartToEnd = false,
                            backgroundContent = {
                                Box(
                                    modifier = Modifier
                                        .fillMaxSize()
                                        .background(
                                            MaterialTheme.colorScheme.errorContainer,
                                            shape = MaterialTheme.shapes.medium
                                        )
                                        .padding(horizontal = 20.dp),
                                    contentAlignment = Alignment.CenterEnd
                                ) {
                                    Icon(
                                        Icons.Default.Delete,
                                        contentDescription = "Xóa",
                                        tint = MaterialTheme.colorScheme.onErrorContainer
                                    )
                                }
                            }
                        ) {
                            HistoryItemCard(item = item) {
                                navController.navigate("result/${item.id}") {
                                    popUpTo("home")
                                }
                            }
                        }
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "*Lưu ý: Để đảm bảo quyền riêng tư và tối ưu bộ nhớ, file ghi âm sẽ không được lưu trong lịch sử; chỉ lưu văn bản cuộc gọi trên thiết bị này.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

@Composable
fun HistoryEmptyState(message: String = "Lịch sử trống.", secondaryMessage: String = "Dữ liệu cuộc gọi chỉ được lưu trên thiết bị này và không chia sẻ ra bên ngoài.") {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(message, style = MaterialTheme.typography.titleLarge)
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = secondaryMessage,
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 32.dp)
        )
    }
}
