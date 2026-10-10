package io.github.processmanager.ui.home

import app.cash.turbine.test
import com.google.common.truth.Truth.assertThat
import io.github.processmanager.data.KillReport
import io.github.processmanager.data.ProcessItem
import io.github.processmanager.data.ProcessKiller
import io.github.processmanager.data.ProcessScanner
import io.github.processmanager.data.ProcessState
import io.github.processmanager.data.ScanResult
import io.github.processmanager.data.ScanSource
import io.github.processmanager.data.SystemMemoryInfo
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestCoroutineScheduler
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class HomeViewModelTest {

    private val testScheduler = TestCoroutineScheduler()
    private val dispatcher = StandardTestDispatcher(testScheduler)

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun init_scansAndPublishesItems() = runTest(testScheduler) {
        val items = listOf(processItem("a"), processItem("b"))
        val viewModel = HomeViewModel(FakeScanner(resultOf(items)), FakeKiller())
        advanceUntilIdle()

        val state = viewModel.uiState.value
        assertThat(state.items).hasSize(2)
        assertThat(state.hasScannedOnce).isTrue()
        assertThat(state.isScanning).isFalse()
    }

    @Test
    fun killSelected_killsOnlySelection_thenRescans() = runTest(testScheduler) {
        val items = listOf(processItem("a"), processItem("b"))
        val killer = FakeKiller()
        val scanner = FakeScanner(resultOf(items))
        val viewModel = HomeViewModel(scanner, killer)
        advanceUntilIdle()

        viewModel.toggleSelection("pkg:b")
        viewModel.events.test {
            viewModel.killSelected()
            advanceUntilIdle()

            val event = awaitItem()
            assertThat(event).isInstanceOf(HomeEvent.KillCompleted::class.java)
            val report = (event as HomeEvent.KillCompleted).report
            assertThat(report.killedPackages).containsExactly("com.example.b")
            cancelAndIgnoreRemainingEvents()
        }

        assertThat(killer.lastItems.map { it.id }).containsExactly("pkg:b")
        // Nach dem Beenden wird still aktualisiert (zweiter Scan).
        assertThat(scanner.scanCount).isEqualTo(2)
    }

    @Test
    fun killAll_killsOnlyKillableItems() = runTest(testScheduler) {
        val items = listOf(
            processItem("fg", state = ProcessState.FOREGROUND),
            processItem("self", isSelf = true),
            processItem("bg", state = ProcessState.BACKGROUND),
        )
        val killer = FakeKiller()
        val viewModel = HomeViewModel(FakeScanner(resultOf(items)), killer)
        advanceUntilIdle()

        viewModel.events.test {
            viewModel.killAll()
            advanceUntilIdle()
            cancelAndIgnoreRemainingEvents()
        }

        assertThat(killer.lastItems.map { it.id }).containsExactly("pkg:bg")
    }

    @Test
    fun killSelected_withoutSelection_doesNothing() = runTest(testScheduler) {
        val killer = FakeKiller()
        val viewModel = HomeViewModel(FakeScanner(resultOf(listOf(processItem("a")))), killer)
        advanceUntilIdle()

        viewModel.killSelected()

        assertThat(killer.callCount).isEqualTo(0)
    }

    @Test
    fun selectAllVisible_selectsOnlyKillable() = runTest(testScheduler) {
        val items = listOf(
            processItem("fg", state = ProcessState.FOREGROUND),
            processItem("self", isSelf = true),
            processItem("bg", state = ProcessState.BACKGROUND),
            processItem("inactive", state = ProcessState.INACTIVE),
        )
        val viewModel = HomeViewModel(FakeScanner(resultOf(items)), FakeKiller())
        advanceUntilIdle()

        viewModel.selectAllVisible()

        assertThat(viewModel.uiState.value.selectedIds)
            .containsExactly("pkg:bg", "pkg:inactive")
    }

    @Test
    fun filter_limitsVisibleItems() = runTest(testScheduler) {
        val items = listOf(
            processItem("fg", state = ProcessState.FOREGROUND),
            processItem("bg", state = ProcessState.BACKGROUND),
            processItem("inactive", state = ProcessState.INACTIVE),
        )
        val viewModel = HomeViewModel(FakeScanner(resultOf(items)), FakeKiller())
        advanceUntilIdle()

        viewModel.setFilter(ProcessFilter.BACKGROUND)
        assertThat(viewModel.uiState.value.visibleItems.map { it.id })
            .containsExactly("pkg:bg")

        viewModel.setFilter(ProcessFilter.FOREGROUND)
        assertThat(viewModel.uiState.value.visibleItems.map { it.id })
            .containsExactly("pkg:fg")

        viewModel.setFilter(ProcessFilter.ALL)
        assertThat(viewModel.uiState.value.visibleItems).hasSize(3)
    }

    // ------------------------------------------------------------------
    // Test-Doubles
    // ------------------------------------------------------------------

    private fun resultOf(items: List<ProcessItem>) = ScanResult(
        items = items,
        memory = SystemMemoryInfo(
            totalBytes = 8_000_000_000L,
            availableBytes = 2_000_000_000L,
            thresholdBytes = 100_000_000L,
            isLowMemory = false,
        ),
        usageAccessGranted = true,
        rootAvailable = false,
        scannedAtMillis = 0L,
    )

    private fun processItem(
        id: String,
        state: ProcessState = ProcessState.BACKGROUND,
        isSelf: Boolean = false,
    ) = ProcessItem(
        id = "pkg:$id",
        label = "App $id",
        processName = "com.example.$id",
        packageName = "com.example.$id",
        pid = if (state == ProcessState.INACTIVE) null else 1000,
        uid = 10_001,
        state = state,
        importance = null,
        memoryKb = 1024L,
        uptimeMillis = null,
        foregroundTimeMillis = null,
        lastUsedMillis = null,
        isSystem = false,
        isSelf = isSelf,
        source = if (state == ProcessState.INACTIVE) {
            ScanSource.USAGE_STATS
        } else {
            ScanSource.RUNNING_PROCESS
        },
    )

    private class FakeScanner(
        private val result: ScanResult,
    ) : ProcessScanner {
        var scanCount: Int = 0
            private set

        override fun hasUsageAccess(): Boolean = result.usageAccessGranted

        override fun isRootAvailable(): Boolean = result.rootAvailable

        override suspend fun scan(): ScanResult {
            scanCount++
            return result
        }
    }

    private class FakeKiller : ProcessKiller {
        var callCount: Int = 0
            private set
        var lastItems: List<ProcessItem> = emptyList()
            private set

        override suspend fun kill(items: List<ProcessItem>, useRoot: Boolean): KillReport {
            callCount++
            lastItems = items
            return KillReport(
                killedPackages = items.mapNotNull { it.packageName },
            )
        }
    }
}
