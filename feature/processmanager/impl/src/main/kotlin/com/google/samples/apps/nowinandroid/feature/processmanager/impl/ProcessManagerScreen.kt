/*
 * Copyright 2025 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.google.samples.apps.nowinandroid.feature.processmanager.impl

import android.content.Intent
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.google.samples.apps.nowinandroid.core.designsystem.component.NiaLoadingWheel
import com.google.samples.apps.nowinandroid.core.designsystem.theme.NiaTheme
import com.google.samples.apps.nowinandroid.feature.processmanager.impl.ProcessManagerUiState.Loading
import com.google.samples.apps.nowinandroid.feature.processmanager.impl.ProcessManagerUiState.Success

@Composable
internal fun ProcessManagerScreen(
    viewModel: ProcessManagerViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current

    ProcessManagerScreen(
        uiState = uiState,
        onScan = viewModel::scanProcesses,
        onToggle = viewModel::toggleSelection,
        onSelectAll = viewModel::selectAll,
        onKillSelected = viewModel::killSelected,
        onKillAll = viewModel::killAll,
        onOpenSettings = {
            context.startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
        },
    )
}

@Composable
private fun ProcessManagerScreen(
    uiState: ProcessManagerUiState,
    onScan: () -> Unit,
    onToggle: (Int) -> Unit,
    onSelectAll: (Boolean) -> Unit,
    onKillSelected: () -> Int,
    onKillAll: () -> Int,
    onOpenSettings: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
    ) {
        when (uiState) {
            is Loading -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        NiaLoadingWheel(
                            modifier = Modifier,
                            contentDesc = stringResource(R.string.feature_processmanager_impl_loading),
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = stringResource(R.string.feature_processmanager_impl_loading),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            is Success -> ProcessListContent(
                state = uiState,
                onScan = onScan,
                onToggle = onToggle,
                onSelectAll = onSelectAll,
                onKillSelected = onKillSelected,
                onKillAll = onKillAll,
                onOpenSettings = onOpenSettings,
            )
        }
    }
}

@Composable
private fun ProcessListContent(
    state: Success,
    onScan: () -> Unit,
    onToggle: (Int) -> Unit,
    onSelectAll: (Boolean) -> Unit,
    onKillSelected: () -> Int,
    onKillAll: () -> Int,
    onOpenSettings: () -> Unit,
) {
    val selectedCount = state.processes.count { it.isSelected }

    if (!state.hasUsageStatsPermission) {
        PermissionHint(onOpenSettings = onOpenSettings)
        Spacer(modifier = Modifier.height(8.dp))
    }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Button(
            onClick = onScan,
            modifier = Modifier.weight(1f),
        ) {
            Text(stringResource(R.string.feature_processmanager_impl_scan))
        }
        OutlinedButton(
            onClick = { onSelectAll(true) },
        ) {
            Text(stringResource(R.string.feature_processmanager_impl_select_all))
        }
    }

    Spacer(modifier = Modifier.height(8.dp))

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = stringResource(
                R.string.feature_processmanager_impl_process_count,
                state.processes.size,
            ),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        if (selectedCount > 0) {
            Text(
                text = stringResource(
                    R.string.feature_processmanager_impl_selected_count,
                    selectedCount,
                ),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.primary,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }

    Spacer(modifier = Modifier.height(8.dp))

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        OutlinedButton(
            onClick = onKillSelected,
            enabled = selectedCount > 0,
            modifier = Modifier.weight(1f),
        ) {
            Text(stringResource(R.string.feature_processmanager_impl_kill_selected))
        }
        OutlinedButton(
            onClick = onKillAll,
            enabled = state.processes.isNotEmpty(),
            modifier = Modifier.weight(1f),
        ) {
            Text(stringResource(R.string.feature_processmanager_impl_kill_all))
        }
    }

    HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

    if (state.processes.isEmpty()) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = stringResource(R.string.feature_processmanager_impl_empty),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    } else {
        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            items(
                items = state.processes,
                key = { it.pid },
            ) { process ->
                ProcessCard(
                    process = process,
                    onToggle = { onToggle(process.pid) },
                )
            }
        }
    }
}

@Composable
private fun ProcessCard(
    process: ProcessItem,
    onToggle: () -> Unit,
) {
    val isBackground = process.importance >= IMPORTANCE_CACHED
    val accentColor = if (process.isSelected) {
        MaterialTheme.colorScheme.primary
    } else {
        MaterialTheme.colorScheme.surfaceVariant
    }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onToggle),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (process.isSelected) {
                MaterialTheme.colorScheme.primaryContainer
            } else {
                MaterialTheme.colorScheme.surface
            },
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .width(4.dp)
                    .height(40.dp)
                    .background(
                        color = accentColor,
                        shape = RoundedCornerShape(2.dp),
                    ),
            )
            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = process.appName,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = process.processName,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Row(
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Text(
                        text = "${stringResource(R.string.feature_processmanager_impl_pid)}: ${process.pid}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        text = "${stringResource(R.string.feature_processmanager_impl_memory)}: ${"%.1f".format(process.memoryMb)} MB",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        text = if (isBackground) {
                            stringResource(R.string.feature_processmanager_impl_background_process)
                        } else {
                            stringResource(R.string.feature_processmanager_impl_foreground_process)
                        },
                        style = MaterialTheme.typography.labelSmall,
                        color = if (isBackground) {
                            MaterialTheme.colorScheme.tertiary
                        } else {
                            MaterialTheme.colorScheme.secondary
                        },
                    )
                }
            }

            Spacer(modifier = Modifier.width(8.dp))
            Checkbox(
                checked = process.isSelected,
                onCheckedChange = { onToggle() },
            )
        }
    }
}

@Composable
private fun PermissionHint(onOpenSettings: () -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.tertiaryContainer,
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = stringResource(R.string.feature_processmanager_impl_permission_hint),
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.weight(1f),
                color = MaterialTheme.colorScheme.onTertiaryContainer,
            )
            TextButton(onClick = onOpenSettings) {
                Text(stringResource(R.string.feature_processmanager_impl_open_settings))
            }
        }
    }
}

private const val IMPORTANCE_CACHED = 400

@Preview
@Composable
private fun ProcessManagerScreenSuccessPreview() {
    NiaTheme {
        Surface {
            ProcessManagerScreen(
                uiState = Success(
                    processes = listOf(
                        ProcessItem(
                            pid = 1234,
                            processName = "com.example.app",
                            appName = "Example App",
                            packageName = "com.example.app",
                            memoryMb = 45.2,
                            importance = 100,
                            isSelected = false,
                        ),
                        ProcessItem(
                            pid = 5678,
                            processName = "com.example.background",
                            appName = "Background Service",
                            packageName = "com.example.background",
                            memoryMb = 12.8,
                            importance = 400,
                            isSelected = true,
                        ),
                    ),
                    hasUsageStatsPermission = false,
                ),
                onScan = {},
                onToggle = {},
                onSelectAll = {},
                onKillSelected = { 0 },
                onKillAll = { 0 },
                onOpenSettings = {},
            )
        }
    }
}

@Preview
@Composable
private fun ProcessManagerScreenLoadingPreview() {
    NiaTheme {
        Surface {
            ProcessManagerScreen(
                uiState = Loading,
                onScan = {},
                onToggle = {},
                onSelectAll = {},
                onKillSelected = { 0 },
                onKillAll = { 0 },
                onOpenSettings = {},
            )
        }
    }
}
