package io.github.processmanager.ui.home

import io.github.processmanager.data.KillReport
import io.github.processmanager.data.ProcessItem
import io.github.processmanager.data.ProcessState
import io.github.processmanager.data.SystemMemoryInfo

/**
 * Listenfilter der Oberfläche.
 */
enum class ProcessFilter {
    ALL,
    FOREGROUND,
    BACKGROUND,
    INACTIVE,
    SYSTEM,
    ;

    fun matches(item: ProcessItem): Boolean = when (this) {
        ALL -> true
        FOREGROUND -> item.state == ProcessState.FOREGROUND
        BACKGROUND -> item.state == ProcessState.BACKGROUND
        INACTIVE -> item.state == ProcessState.INACTIVE
        SYSTEM -> item.isSystem
    }
}

/**
 * Unveränderlicher UI-Zustand (Single Source of Truth).
 */
data class HomeUiState(
    val isScanning: Boolean = false,
    val items: List<ProcessItem> = emptyList(),
    val selectedIds: Set<String> = emptySet(),
    val expandedIds: Set<String> = emptySet(),
    val filter: ProcessFilter = ProcessFilter.ALL,
    val memory: SystemMemoryInfo? = null,
    val usageAccessGranted: Boolean = true,
    val rootAvailable: Boolean = false,
    val rootEnabled: Boolean = false,
    val lastScanAtMillis: Long? = null,
    val hasScannedOnce: Boolean = false,
) {
    val visibleItems: List<ProcessItem>
        get() = items.filter { filter.matches(it) }

    val selectedItems: List<ProcessItem>
        get() = items.filter { it.id in selectedIds }

    val foregroundCount: Int
        get() = items.count { it.state == ProcessState.FOREGROUND }

    val backgroundCount: Int
        get() = items.count { it.state == ProcessState.BACKGROUND }

    val inactiveCount: Int
        get() = items.count { it.state == ProcessState.INACTIVE }

    val killableItems: List<ProcessItem>
        get() = items.filter { it.isKillable }
}

/**
 * Einmal-Ereignisse für Snackbar-Meldungen.
 */
sealed interface HomeEvent {
    data class ScanCompleted(val count: Int) : HomeEvent
    data class KillCompleted(val report: KillReport) : HomeEvent
    data class Error(val message: String) : HomeEvent
}
