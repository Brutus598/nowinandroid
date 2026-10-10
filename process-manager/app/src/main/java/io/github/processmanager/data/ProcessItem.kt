package io.github.processmanager.data

/**
 * Aggregierter Zustand eines Prozesses/einer App für die Oberfläche.
 */
enum class ProcessState {
    /** Sichtbar bzw. im Vordergrund – vom System geschützt. */
    FOREGROUND,

    /** Laufender Hintergrundprozess (Dienst, gecacht). */
    BACKGROUND,

    /** Kein sichtbarer Prozess, aber kürzlich aktiv (aus Nutzungsinformationen). */
    INACTIVE,
}

/**
 * Woher ein Eintrag stammt.
 */
enum class ScanSource {
    RUNNING_PROCESS,
    USAGE_STATS,
}

/**
 * Ein Prozess- oder App-Eintrag, wie er in der Liste angezeigt wird.
 */
data class ProcessItem(
    /** Stabile ID für Auswahl & Listen-Schlüssel. */
    val id: String,
    /** Anzeigename (App-Label) oder Prozessname. */
    val label: String,
    val processName: String,
    val packageName: String?,
    val pid: Int?,
    val uid: Int?,
    val state: ProcessState,
    /** Roher `RunningAppProcessInfo.importance`-Wert, sofern bekannt. */
    val importance: Int?,
    /** Belegter Speicher in KB (PSS), sofern ermittelbar. */
    val memoryKb: Long?,
    /** Prozess-Laufzeit seit Start in ms, sofern ermittelbar. */
    val uptimeMillis: Long?,
    /** Kumulierte Vordergrundzeit aus den Nutzungsinformationen. */
    val foregroundTimeMillis: Long?,
    /** Zeitpunkt der letzten Aktivität aus den Nutzungsinformationen. */
    val lastUsedMillis: Long?,
    val isSystem: Boolean,
    val isSelf: Boolean,
    val source: ScanSource,
    val packages: List<String> = emptyList(),
) {
    /**
     * Ob der Eintrag über [io.github.processmanager.data.ProcessKiller] beendet
     * werden kann. Vordergrund-Prozesse und die eigene App sind geschützt.
     */
    val isKillable: Boolean
        get() = packageName != null && !isSelf && state != ProcessState.FOREGROUND
}

/**
 * Systemspeicher-Zustand (aus `ActivityManager.MemoryInfo`).
 */
data class SystemMemoryInfo(
    val totalBytes: Long,
    val availableBytes: Long,
    val thresholdBytes: Long,
    val isLowMemory: Boolean,
) {
    val usedBytes: Long
        get() = (totalBytes - availableBytes).coerceAtLeast(0L)
}

/**
 * Ergebnis eines Scans.
 */
data class ScanResult(
    val items: List<ProcessItem>,
    val memory: SystemMemoryInfo,
    val usageAccessGranted: Boolean,
    val rootAvailable: Boolean,
    val scannedAtMillis: Long,
)

/**
 * Ergebnis eines Beendigen-Laufs.
 */
data class KillReport(
    val killedPackages: List<String> = emptyList(),
    val failedPackages: List<String> = emptyList(),
    val skipped: List<ProcessItem> = emptyList(),
) {
    val successCount: Int get() = killedPackages.size
    val totalCount: Int get() = killedPackages.size + failedPackages.size + skipped.size

    operator fun plus(other: KillReport): KillReport = KillReport(
        killedPackages = killedPackages + other.killedPackages,
        failedPackages = failedPackages + other.failedPackages,
        skipped = skipped + other.skipped,
    )
}
