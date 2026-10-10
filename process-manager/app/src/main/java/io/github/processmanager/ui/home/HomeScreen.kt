package io.github.processmanager.ui.home

import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import io.github.processmanager.R
import io.github.processmanager.ui.components.ProcessCard
import io.github.processmanager.ui.components.ScanCard
import io.github.processmanager.ui.components.SummaryCard

/**
 * Startbildschirm: Scan, Übersicht, Filterliste und Beenden-Aktionen.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    viewModel: HomeViewModel = viewModel(factory = HomeViewModel.Factory),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    val context = LocalContext.current
    val resources = context.resources

    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            val message = when (event) {
                is HomeEvent.ScanCompleted -> resources.getString(
                    R.string.event_scan_completed,
                    event.count,
                )

                is HomeEvent.KillCompleted -> {
                    val report = event.report
                    when {
                        report.successCount > 0 &&
                            report.failedPackages.isEmpty() &&
                            report.skipped.isEmpty() ->
                            resources.getString(R.string.event_kill_success, report.successCount)

                        report.successCount > 0 -> resources.getString(
                            R.string.event_kill_partial,
                            report.successCount,
                            report.skipped.size + report.failedPackages.size,
                        )

                        report.failedPackages.isNotEmpty() ->
                            resources.getString(R.string.event_kill_failed)

                        else -> resources.getString(R.string.event_kill_none)
                    }
                }

                is HomeEvent.Error -> resources.getString(
                    R.string.event_scan_error,
                    event.message,
                )
            }
            snackbarHostState.showSnackbar(message)
        }
    }

    // Nach Rückkehr aus den Einstellungen Zustand erneut aktualisieren.
    LifecycleResumeEffect(Unit) {
        viewModel.onResumed()
        onPauseOrDispose { }
    }

    var showInfo by remember { mutableStateOf(false) }
    if (showInfo) {
        InfoDialog(
            usageAccessGranted = state.usageAccessGranted,
            rootEnabled = state.rootEnabled,
            onRootEnabledChange = viewModel::setRootEnabled,
            onOpenUsageSettings = { openUsageSettings(context) },
            onDismiss = { showInfo = false },
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = stringResource(R.string.title_process_list),
                            style = MaterialTheme.typography.titleLarge,
                        )
                        Text(
                            text = if (state.hasScannedOnce) {
                                stringResource(
                                    R.string.subtitle_counts,
                                    state.foregroundCount,
                                    state.backgroundCount,
                                    state.items.size,
                                )
                            } else {
                                stringResource(R.string.subtitle_no_scan)
                            },
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { showInfo = true }) {
                        Icon(
                            imageVector = Icons.Default.Info,
                            contentDescription = stringResource(R.string.info_title),
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
        bottomBar = {
            ActionBar(
                selectedCount = state.selectedIds.size,
                killableCount = state.killableItems.size,
                isScanning = state.isScanning,
                onKillSelected = viewModel::killSelected,
                onKillAll = viewModel::killAll,
                onSelectAll = viewModel::selectAllVisible,
                onClearSelection = viewModel::clearSelection,
            )
        },
    ) { padding ->
        Box(modifier = Modifier.padding(padding)) {
            when {
                !state.hasScannedOnce && state.isScanning -> FullScreenProgress()

                state.items.isEmpty() && state.hasScannedOnce -> EmptyState(
                    title = stringResource(R.string.empty_title),
                    body = stringResource(R.string.empty_body),
                    onScan = { viewModel.scan() },
                )

                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        start = 16.dp,
                        end = 16.dp,
                        top = 8.dp,
                        bottom = 16.dp,
                    ),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    item(key = "scan") {
                        ScanCard(
                            isScanning = state.isScanning,
                            hasScannedOnce = state.hasScannedOnce,
                            lastScanAtMillis = state.lastScanAtMillis,
                            onScan = { viewModel.scan() },
                        )
                    }

                    if (!state.usageAccessGranted) {
                        item(key = "usage_access") {
                            UsageAccessBanner(
                                onOpenSettings = { openUsageSettings(context) },
                            )
                        }
                    }

                    item(key = "summary") {
                        SummaryCard(
                            foregroundCount = state.foregroundCount,
                            backgroundCount = state.backgroundCount,
                            inactiveCount = state.inactiveCount,
                            memory = state.memory,
                        )
                    }

                    item(key = "filters") {
                        FilterRow(
                            selected = state.filter,
                            onSelect = viewModel::setFilter,
                        )
                    }

                    if (state.visibleItems.isEmpty()) {
                        item(key = "empty_filter") {
                            EmptyState(
                                title = stringResource(R.string.empty_filter_title),
                                body = stringResource(R.string.empty_filter_body),
                                onScan = { viewModel.scan() },
                            )
                        }
                    }

                    items(state.visibleItems, key = { it.id }) { item ->
                        ProcessCard(
                            item = item,
                            isSelected = item.id in state.selectedIds,
                            isExpanded = item.id in state.expandedIds,
                            nowMillis = state.lastScanAtMillis ?: System.currentTimeMillis(),
                            onToggleSelection = { viewModel.toggleSelection(item.id) },
                            onToggleExpanded = { viewModel.toggleExpanded(item.id) },
                            onKillItem = { viewModel.killItem(item) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun FullScreenProgress() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator()
    }
}

@Composable
private fun EmptyState(
    title: String,
    body: String,
    onScan: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = Icons.Default.List,
            contentDescription = null,
            modifier = Modifier.size(48.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            textAlign = TextAlign.Center,
        )
        Text(
            text = body,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
        Spacer(modifier = Modifier.height(8.dp))
        Button(onClick = onScan) {
            Text(stringResource(R.string.action_scan))
        }
    }
}

@Composable
private fun UsageAccessBanner(onOpenSettings: () -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.tertiaryContainer,
        contentColor = MaterialTheme.colorScheme.onTertiaryContainer,
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = Icons.Default.Warning,
                contentDescription = null,
                modifier = Modifier.size(24.dp),
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = stringResource(R.string.usage_access_title),
                    style = MaterialTheme.typography.titleSmall,
                )
                Text(
                    text = stringResource(R.string.usage_access_body),
                    style = MaterialTheme.typography.bodySmall,
                )
                TextButton(onClick = onOpenSettings) {
                    Text(stringResource(R.string.usage_access_action))
                }
            }
        }
    }
}

@Composable
private fun FilterRow(
    selected: ProcessFilter,
    onSelect: (ProcessFilter) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        FilterChip(
            selected = selected == ProcessFilter.ALL,
            onClick = { onSelect(ProcessFilter.ALL) },
            label = { Text(stringResource(R.string.filter_all)) },
        )
        FilterChip(
            selected = selected == ProcessFilter.FOREGROUND,
            onClick = { onSelect(ProcessFilter.FOREGROUND) },
            label = { Text(stringResource(R.string.filter_foreground)) },
        )
        FilterChip(
            selected = selected == ProcessFilter.BACKGROUND,
            onClick = { onSelect(ProcessFilter.BACKGROUND) },
            label = { Text(stringResource(R.string.filter_background)) },
        )
        FilterChip(
            selected = selected == ProcessFilter.INACTIVE,
            onClick = { onSelect(ProcessFilter.INACTIVE) },
            label = { Text(stringResource(R.string.filter_inactive)) },
        )
        FilterChip(
            selected = selected == ProcessFilter.SYSTEM,
            onClick = { onSelect(ProcessFilter.SYSTEM) },
            label = { Text(stringResource(R.string.filter_system)) },
        )
    }
}

@Composable
private fun ActionBar(
    selectedCount: Int,
    killableCount: Int,
    isScanning: Boolean,
    onKillSelected: () -> Unit,
    onKillAll: () -> Unit,
    onSelectAll: () -> Unit,
    onClearSelection: () -> Unit,
) {
    Surface(
        tonalElevation = 3.dp,
        color = MaterialTheme.colorScheme.surfaceContainer,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = if (selectedCount > 0) {
                        stringResource(R.string.selection_count, selectedCount)
                    } else {
                        stringResource(R.string.killable_summary, killableCount)
                    },
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Row {
                    if (selectedCount > 0) {
                        TextButton(onClick = onClearSelection) {
                            Text(stringResource(R.string.action_clear_selection))
                        }
                    }
                    TextButton(onClick = onSelectAll, enabled = killableCount > 0) {
                        Text(stringResource(R.string.action_select_all))
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilledTonalButton(
                    onClick = onKillSelected,
                    enabled = selectedCount > 0 && !isScanning,
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp),
                ) {
                    Text(
                        text = if (selectedCount > 0) {
                            stringResource(R.string.action_kill_selected_count, selectedCount)
                        } else {
                            stringResource(R.string.action_kill_selected)
                        },
                        maxLines = 1,
                    )
                }
                Button(
                    onClick = onKillAll,
                    enabled = killableCount > 0 && !isScanning,
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp),
                ) {
                    Text(stringResource(R.string.action_kill_all), maxLines = 1)
                }
            }
        }
    }
}

@Composable
private fun InfoDialog(
    usageAccessGranted: Boolean,
    rootEnabled: Boolean,
    onRootEnabledChange: (Boolean) -> Unit,
    onOpenUsageSettings: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.info_title)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    text = stringResource(R.string.info_body),
                    style = MaterialTheme.typography.bodyMedium,
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Switch(
                        checked = rootEnabled,
                        onCheckedChange = onRootEnabledChange,
                    )
                    Column(modifier = Modifier.padding(start = 12.dp)) {
                        Text(
                            text = stringResource(R.string.info_root),
                            style = MaterialTheme.typography.labelLarge,
                        )
                        Text(
                            text = stringResource(R.string.info_root_summary),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                Text(
                    text = stringResource(
                        if (usageAccessGranted) {
                            R.string.info_usage_status_on
                        } else {
                            R.string.info_usage_status_off
                        },
                    ),
                    style = MaterialTheme.typography.labelMedium,
                    color = if (usageAccessGranted) {
                        MaterialTheme.colorScheme.secondary
                    } else {
                        MaterialTheme.colorScheme.error
                    },
                )
                if (!usageAccessGranted) {
                    TextButton(onClick = onOpenUsageSettings) {
                        Text(stringResource(R.string.usage_access_action))
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.action_close))
            }
        },
    )
}

private fun openUsageSettings(context: Context) {
    runCatching {
        context.startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
    }.onFailure {
        runCatching { context.startActivity(Intent(Settings.ACTION_SETTINGS)) }
    }
}
