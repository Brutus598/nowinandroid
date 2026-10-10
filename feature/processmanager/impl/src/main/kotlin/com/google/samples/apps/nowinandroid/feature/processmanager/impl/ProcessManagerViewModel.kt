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

import android.app.ActivityManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.SystemClock
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.android.lifecycle.HiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

/**
 * Represents a single running process with resource details.
 */
data class ProcessItem(
    val pid: Int,
    val processName: String,
    val appName: String,
    val packageName: String,
    val memoryMb: Double,
    val importance: Int,
    val isSelected: Boolean,
)

/**
 * UI state for the process manager screen.
 */
sealed interface ProcessManagerUiState {
    data object Loading : ProcessManagerUiState
    data class Success(
        val processes: List<ProcessItem>,
        val hasUsageStatsPermission: Boolean,
    ) : ProcessManagerUiState
}

@HiltViewModel
class ProcessManagerViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
) : ViewModel() {

    private val activityManager =
        context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    private val packageManager = context.packageManager
    private val usageStatsManager =
        context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager

    private val _uiState = MutableStateFlow<ProcessManagerUiState>(ProcessManagerUiState.Loading)
    val uiState: StateFlow<ProcessManagerUiState> = _uiState.asStateFlow()

    private val scanStartElapsed = SystemClock.elapsedRealtime()

    init {
        scanProcesses()
    }

    fun scanProcesses() {
        _uiState.value = ProcessManagerUiState.Loading
        viewModelScope.launch {
            val state = withContext(Dispatchers.IO) { doScan() }
            _uiState.value = state
        }
    }

    fun toggleSelection(pid: Int) {
        val current = _uiState.value as? ProcessManagerUiState.Success ?: return
        _uiState.value = current.copy(
            processes = current.processes.map { item ->
                if (item.pid == pid) item.copy(isSelected = !item.isSelected) else item
            },
        )
    }

    fun selectAll(select: Boolean) {
        val current = _uiState.value as? ProcessManagerUiState.Success ?: return
        _uiState.value = current.copy(
            processes = current.processes.map { it.copy(isSelected = select) },
        )
    }

    fun killSelected(): Int {
        val current = _uiState.value as? ProcessManagerUiState.Success ?: return 0
        val toKill = current.processes.filter { it.isSelected }
        var killed = 0
        for (item in toKill) {
            if (killProcess(item)) killed++
        }
        scanProcesses()
        return killed
    }

    fun killAll(): Int {
        val current = _uiState.value as? ProcessManagerUiState.Success ?: return 0
        var killed = 0
        for (item in current.processes) {
            if (killProcess(item)) killed++
        }
        scanProcesses()
        return killed
    }

    private fun killProcess(item: ProcessItem): Boolean {
        return try {
            // killBackgroundProcesses requires KILL_BACKGROUND_PROCESSES permission
            activityManager.killBackgroundProcesses(item.packageName)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun doScan(): ProcessManagerUiState.Success {
        val hasUsageStats = hasUsageStatsPermission()

        val processes = activityManager.runningAppProcesses ?: emptyList()

        val items = processes.mapNotNull { processInfo ->
            val pkg = processInfo.processName.substringBefore(':')
            val memoryInfo = try {
                activityManager.getProcessMemoryInfo(intArrayOf(processInfo.pid))
            } catch (e: Exception) {
                null
            }
            val memKb = memoryInfo?.firstOrNull()?.totalPrivateDirty ?: 0
            val appName = try {
                val appInfo = packageManager.getApplicationInfo(pkg, 0)
                packageManager.getApplicationLabel(appInfo).toString()
            } catch (e: Exception) {
                pkg
            }
            ProcessItem(
                pid = processInfo.pid,
                processName = processInfo.processName,
                appName = appName,
                packageName = pkg,
                memoryMb = memKb / 1024.0,
                importance = processInfo.importance,
                isSelected = false,
            )
        }.sortedByDescending { it.memoryMb }

        return ProcessManagerUiState.Success(
            processes = items,
            hasUsageStatsPermission = hasUsageStats,
        )
    }

    private fun hasUsageStatsPermission(): Boolean {
        val now = System.currentTimeMillis()
        val stats = usageStatsManager?.queryUsageStats(
            UsageStatsManager.INTERVAL_BEST,
            now - 60_000,
            now,
        )
        return stats?.isNotEmpty() == true
    }
}
