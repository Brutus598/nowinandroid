package io.github.processmanager.data

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Android-Implementierung des Scans.
 *
 * Datenquellen (bewusst nur öffentliche APIs, wie sie auch große
 * App-Manager nutzen – vgl. Hamza417/Inure, MuntashirAkon/AppManager):
 *
 * 1. `ActivityManager.getRunningAppProcesses()` – laufende Prozesse mit
 *    Priorität und PID (moderne Android-Versionen zeigen hier primär die
 *    eigenen Prozesse; ältere/OEM-Builds liefern mehr).
 * 2. `ActivityManager.getProcessMemoryInfo()` – PSS-Speicher pro Prozess
 *    (ausdrücklich für Prozess-Manager-UIs freigegeben).
 * 3. `UsageStatsManager` – Apps mit kürzlicher Aktivität, Vordergrundzeit
 *    und letzter Nutzung (benötigt den Sonderzugriff).
 * 4. `/proc/<pid>/stat` – Laufzeit, sofern das System es erlaubt.
 */
class AndroidProcessScanner(
    context: Context,
) : ProcessScanner {

    private val appContext = context.applicationContext
    private val activityManager =
        appContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    private val packageManager: PackageManager = appContext.packageManager
    private val usageStatsManager =
        appContext.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

    @Volatile
    private var cachedRootAvailable: Boolean? = null

    override fun hasUsageAccess(): Boolean {
        val appOps = appContext.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            appContext.packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    override fun isRootAvailable(): Boolean = cachedRootAvailable ?: detectRoot().also {
        cachedRootAvailable = it
    }

    override suspend fun scan(): ScanResult = withContext(Dispatchers.IO) {
        val now = System.currentTimeMillis()
        val running = scanRunningProcesses()
        val runningPackages = running.flatMap { it.packages }.toSet()
        val fromUsage = scanUsageStats(runningPackages, now)

        val all = (running + fromUsage).sortedWith(
            compareByDescending<ProcessItem> { it.state == ProcessState.FOREGROUND }
                .thenByDescending { it.source == ScanSource.RUNNING_PROCESS }
                .thenByDescending { it.memoryKb ?: -1L }
                .thenBy { it.label.lowercase() },
        )

        ScanResult(
            items = all,
            memory = readSystemMemory(),
            usageAccessGranted = hasUsageAccess(),
            rootAvailable = isRootAvailable(),
            scannedAtMillis = now,
        )
    }

    private fun readSystemMemory(): SystemMemoryInfo {
        val info = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(info)
        return SystemMemoryInfo(
            totalBytes = info.totalMem,
            availableBytes = info.availMem,
            thresholdBytes = info.threshold,
            isLowMemory = info.lowMemory,
        )
    }

    private fun scanRunningProcesses(): List<ProcessItem> {
        val processes = activityManager.runningAppProcesses ?: return emptyList()
        val pids = processes.map { it.pid }.toIntArray()
        val memoryByPid: Map<Int, Long> = try {
            activityManager.getProcessMemoryInfo(pids)
                ?.mapIndexedNotNull { index, memory ->
                    pids.getOrNull(index)?.let { it to memory.totalPss.toLong() }
                }
                ?.toMap()
                ?: emptyMap()
        } catch (_: Exception) {
            emptyMap()
        }
        return processes.map { mapRunningProcess(it, memoryByPid[it.pid]) }
    }

    private fun mapRunningProcess(
        info: ActivityManager.RunningAppProcessInfo,
        memoryKb: Long?,
    ): ProcessItem {
        val packages = info.pkgList?.toList().orEmpty()
        val primaryPackage = packages.firstOrNull()
            ?: info.processName.substringBefore(':')
        val appInfo = runCatching {
            packageManager.getApplicationInfo(primaryPackage, PackageManager.GET_META_DATA)
        }.getOrNull()
        val isSelf = appInfo?.packageName == appContext.packageName ||
            packages.contains(appContext.packageName) ||
            info.processName == appContext.packageName

        return ProcessItem(
            id = "pid:${info.pid}",
            label = appInfo?.let { packageManager.getApplicationLabel(it).toString() }
                ?: info.processName,
            processName = info.processName,
            packageName = appInfo?.packageName ?: primaryPackage,
            pid = info.pid,
            uid = appInfo?.uid,
            state = importanceToState(info.importance),
            importance = info.importance,
            memoryKb = memoryKb,
            uptimeMillis = Procfs.processUptimeMillis(info.pid),
            foregroundTimeMillis = null,
            lastUsedMillis = null,
            isSystem = appInfo?.isSystemApp() == true,
            isSelf = isSelf,
            source = ScanSource.RUNNING_PROCESS,
            packages = packages,
        )
    }

    private fun importanceToState(importance: Int): ProcessState = when (importance) {
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND,
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND_SERVICE,
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE,
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_PERCEPTIBLE,
        -> ProcessState.FOREGROUND

        else -> ProcessState.BACKGROUND
    }

    private fun scanUsageStats(
        knownPackages: Set<String>,
        now: Long,
    ): List<ProcessItem> {
        if (!hasUsageAccess()) return emptyList()
        val begin = now - DAY_MILLIS
        val stats: List<UsageStats> = runCatching {
            usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                begin,
                now,
            )
        }.getOrNull().orEmpty()
        if (stats.isEmpty()) return emptyList()

        val foregroundByPackage = queryForegroundPackages(begin, now)

        return stats
            .filter { it.lastTimeUsed > 0L && it.packageName !in knownPackages }
            .map { usage -> mapUsageStats(usage, foregroundByPackage[usage.packageName] == true) }
    }

    /** Letzte RESUMED/PAUSED-Ereignisse pro Paket → gerade im Vordergrund? */
    private fun queryForegroundPackages(begin: Long, now: Long): Map<String, Boolean> {
        val result = mutableMapOf<String, Boolean>()
        val events = runCatching { usageStatsManager.queryEvents(begin, now) }.getOrNull()
            ?: return emptyMap()
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> result[event.packageName] = true
                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.ACTIVITY_STOPPED,
                -> result[event.packageName] = false
            }
        }
        return result
    }

    private fun mapUsageStats(usage: UsageStats, inForeground: Boolean): ProcessItem {
        val appInfo = runCatching {
            packageManager.getApplicationInfo(usage.packageName, 0)
        }.getOrNull()
        val isSelf = usage.packageName == appContext.packageName
        return ProcessItem(
            id = "pkg:${usage.packageName}",
            label = appInfo?.let { packageManager.getApplicationLabel(it).toString() }
                ?: usage.packageName,
            processName = usage.packageName,
            packageName = usage.packageName,
            pid = null,
            uid = appInfo?.uid,
            state = if (inForeground) ProcessState.FOREGROUND else ProcessState.INACTIVE,
            importance = null,
            memoryKb = null,
            uptimeMillis = null,
            foregroundTimeMillis = usage.totalTimeInForeground,
            lastUsedMillis = usage.lastTimeUsed,
            isSystem = appInfo?.isSystemApp() == true,
            isSelf = isSelf,
            source = ScanSource.USAGE_STATS,
            packages = listOf(usage.packageName),
        )
    }

    /**
     * Schnelle, nicht-blockierende Root-Erkennung über typische su-Binaries.
     * Der eigentliche `su`-Aufruf erfolgt erst beim Beenden (mit Timeout).
     */
    private fun detectRoot(): Boolean = ROOT_BINARY_CANDIDATES.any { File(it).exists() }

    private fun ApplicationInfo.isSystemApp(): Boolean =
        (flags and ApplicationInfo.FLAG_SYSTEM) != 0 ||
            (flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0

    private companion object {
        const val DAY_MILLIS = 24L * 60 * 60 * 1000

        val ROOT_BINARY_CANDIDATES = listOf(
            "/system/bin/su",
            "/system/xbin/su",
            "/sbin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/data/local/bin/su",
            "/data/local/xbin/su",
            "/su/bin/su",
            "/sbin/.magisk/busybox/su",
        )
    }
}
