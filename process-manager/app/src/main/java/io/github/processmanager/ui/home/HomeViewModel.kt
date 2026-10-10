package io.github.processmanager.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import io.github.processmanager.data.AndroidProcessKiller
import io.github.processmanager.data.AndroidProcessScanner
import io.github.processmanager.data.KillReport
import io.github.processmanager.data.ProcessItem
import io.github.processmanager.data.ProcessKiller
import io.github.processmanager.data.ProcessScanner
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * State Holder der Startseite: Scan, Filter, Auswahl und Beenden.
 * Unidirektionaler Datenfluss (UDF) – vgl. Architektur von android/nowinandroid.
 */
class HomeViewModel(
    private val scanner: ProcessScanner,
    private val killer: ProcessKiller,
) : ViewModel() {

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    private val _events = Channel<HomeEvent>(Channel.BUFFERED)
    val events = _events.receiveAsFlow()

    init {
        scan(notify = false)
    }

    /** Zentrale Scan-Funktion: erkennt alle sichtbaren aktiven Prozesse. */
    fun scan(notify: Boolean = true) {
        if (_uiState.value.isScanning) return
        viewModelScope.launch {
            _uiState.update { it.copy(isScanning = true) }
            runCatching { scanner.scan() }
                .onSuccess { result ->
                    val aliveIds = result.items.mapTo(mutableSetOf()) { item -> item.id }
                    _uiState.update { state ->
                        state.copy(
                            isScanning = false,
                            items = result.items,
                            memory = result.memory,
                            usageAccessGranted = result.usageAccessGranted,
                            rootAvailable = result.rootAvailable,
                            lastScanAtMillis = result.scannedAtMillis,
                            hasScannedOnce = true,
                            selectedIds = state.selectedIds.intersect(aliveIds),
                        )
                    }
                    if (notify) {
                        _events.send(HomeEvent.ScanCompleted(result.items.size))
                    }
                }
                .onFailure { error ->
                    _uiState.update { it.copy(isScanning = false, hasScannedOnce = true) }
                    _events.send(
                        HomeEvent.Error(error.message ?: "Scan fehlgeschlagen"),
                    )
                }
        }
    }

    fun setFilter(filter: ProcessFilter) {
        _uiState.update { it.copy(filter = filter) }
    }

    fun toggleSelection(id: String) {
        _uiState.update { state ->
            val selection = if (id in state.selectedIds) {
                state.selectedIds - id
            } else {
                state.selectedIds + id
            }
            state.copy(selectedIds = selection)
        }
    }

    fun toggleExpanded(id: String) {
        _uiState.update { state ->
            val expanded = if (id in state.expandedIds) {
                state.expandedIds - id
            } else {
                state.expandedIds + id
            }
            state.copy(expandedIds = expanded)
        }
    }

    fun selectAllVisible() {
        _uiState.update { state ->
            val visibleIds = state.visibleItems
                .filter { it.isKillable }
                .mapTo(mutableSetOf()) { it.id }
            state.copy(selectedIds = visibleIds)
        }
    }

    fun clearSelection() {
        _uiState.update { it.copy(selectedIds = emptySet()) }
    }

    fun setRootEnabled(enabled: Boolean) {
        _uiState.update { it.copy(rootEnabled = enabled) }
    }

    /**
     * Nach Rückkehr in die App (z. B. aus den Einstellungen) erneut
     * aktualisieren – ohne Snackbar.
     */
    fun onResumed() {
        val state = _uiState.value
        if (state.hasScannedOnce && !state.isScanning) {
            scan(notify = false)
        }
    }

    /** Ein-Klick: alle ausgewählten Einträge beenden. */
    fun killSelected() {
        val targets = _uiState.value.selectedItems
        if (targets.isEmpty()) return
        kill(targets)
    }

    /** Ein-Klick: alle beendbaren Prozesse beenden. */
    fun killAll() {
        kill(_uiState.value.killableItems)
    }

    /** Einzelnen Eintrag beenden (Details-Ansicht). */
    fun killItem(item: ProcessItem) {
        kill(listOf(item))
    }

    private fun kill(targets: List<ProcessItem>) {
        if (targets.isEmpty()) {
            viewModelScope.launch { _events.send(HomeEvent.KillCompleted(KillReport())) }
            return
        }
        viewModelScope.launch {
            val useRoot = _uiState.value.rootEnabled && scanner.isRootAvailable()
            val report = killer.kill(targets, useRoot)
            _events.send(HomeEvent.KillCompleted(report))
            // Liste aktualisieren, ohne eine zweite Snackbar auszulösen.
            scan(notify = false)
        }
    }

    companion object {
        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val app = this[ViewModelProvider.AndroidViewModelFactory.APPLICATION_KEY]
                    ?: error("Application context missing")
                HomeViewModel(
                    scanner = AndroidProcessScanner(app),
                    killer = AndroidProcessKiller(app),
                )
            }
        }
    }
}
