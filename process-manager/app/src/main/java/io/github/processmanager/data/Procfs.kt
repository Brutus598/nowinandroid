package io.github.processmanager.data

import java.io.File

/**
 * Liest Prozess-Laufzeiten aus `/proc`.
 *
 * Seit Android 7 (hidepid=2) sind fremde `/proc/<pid>`-Einträge für normale
 * Apps gesperrt – dann liefert dieses Objekt `null` und die Oberfläche zeigt
 * die Laufzeit als unbekannt bzw. greift auf Nutzungsinformationen zurück.
 * Siehe https://github.com/jaredrummler/AndroidProcesses
 */
internal object Procfs {

    /** Ticks pro Sekunde auf Android/Linux. */
    private const val CLK_TICKS_PER_SECOND = 100L

    /**
     * Laufzeit eines Prozesses seit Start in Millisekunden, oder `null`,
     * wenn `/proc` für diese PID nicht lesbar ist.
     */
    fun processUptimeMillis(pid: Int): Long? = try {
        val stat = File("/proc/$pid/stat").readText()
        val commEnd = stat.lastIndexOf(')')
        if (commEnd == -1) {
            null
        } else {
            // Nach "pid (comm)" folgen die Felder ab 3 (state).
            val fields = stat.substring(commEnd + 1).trim().split(Regex("\\s+"))
            // Feld 22 (starttime) → Index 22 - 3 = 19 innerhalb dieses Arrays.
            val startTicks = fields.getOrNull(19)?.toLongOrNull()
            val uptimeSeconds = File("/proc/uptime").readText()
                .trim().split(' ').firstOrNull()?.toDoubleOrNull()
            if (startTicks == null || uptimeSeconds == null) {
                null
            } else {
                val elapsedSeconds = uptimeSeconds - startTicks.toDouble() / CLK_TICKS_PER_SECOND
                if (elapsedSeconds < 0) null else (elapsedSeconds * 1000).toLong()
            }
        }
    } catch (_: Exception) {
        null
    }
}
