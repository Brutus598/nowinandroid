package io.github.processmanager.data

/**
 * Liefert den aktuellen Prozess-/App-Zustand des Geräts.
 */
interface ProcessScanner {

    /** Liegen die "Nutzungsinformationen" (Usage Stats) vor? */
    fun hasUsageAccess(): Boolean

    /** Ist Root für erweiterte Aktionen verfügbar? (langsam – gecacht) */
    fun isRootAvailable(): Boolean

    /** Führt einen vollständigen Scan aller sichtbaren Prozesse durch. */
    suspend fun scan(): ScanResult
}

/**
 * Beendet Prozesse/Apps.
 */
interface ProcessKiller {

    /**
     * Beendet die gegebenen Einträge. [useRoot] erlaubt zusätzlich
     * `am force-stop` über su (nur wenn Root verfügbar).
     */
    suspend fun kill(items: List<ProcessItem>, useRoot: Boolean): KillReport
}
