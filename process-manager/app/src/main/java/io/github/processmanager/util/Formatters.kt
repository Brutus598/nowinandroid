package io.github.processmanager.util

import java.util.Locale

/**
 * Deutsche Formatierer für Speicher, Laufzeiten und Zeitstempel.
 */
object Formatters {

    const val UNKNOWN = "–"

    /** PSS in KB → "512 MB" bzw. "1,2 GB". */
    fun formatMemory(totalPssKb: Long?): String {
        if (totalPssKb == null || totalPssKb <= 0L) return UNKNOWN
        val megabytes = totalPssKb / 1024.0
        return if (megabytes >= 1024.0) {
            String.format(Locale.GERMAN, "%.1f GB", megabytes / 1024.0)
        } else {
            val rounded = kotlin.math.round(megabytes).toLong().coerceAtLeast(1L)
            "$rounded MB"
        }
    }

    /** Millisekunden → "45 s", "12 Min", "2 Std 5 Min", "3 Tg 4 Std". */
    fun formatDuration(millis: Long?): String {
        if (millis == null || millis < 0L) return UNKNOWN
        val seconds = millis / 1000
        return when {
            seconds < 60L -> "$seconds s"
            seconds < 3600L -> "${seconds / 60L} Min"
            seconds < 86400L -> {
                val hours = seconds / 3600L
                val minutes = (seconds % 3600L) / 60L
                if (minutes > 0L) "$hours Std $minutes Min" else "$hours Std"
            }
            else -> {
                val days = seconds / 86400L
                val hours = (seconds % 86400L) / 3600L
                if (hours > 0L) "$days Tg $hours Std" else "$days Tg"
            }
        }
    }

    /** Zeitstempel → "gerade eben", "vor 5 Min", "gestern", "vor 3 Tagen". */
    fun formatRelativeTime(timestampMillis: Long?, nowMillis: Long): String {
        if (timestampMillis == null || timestampMillis <= 0L) return UNKNOWN
        val diff = nowMillis - timestampMillis
        return when {
            diff < 60_000L -> "gerade eben"
            diff < 3_600_000L -> "vor ${diff / 60_000L} Min"
            diff < 86_400_000L -> "vor ${diff / 3_600_000L} Std"
            diff < 172_800_000L -> "gestern"
            else -> "vor ${diff / 86_400_000L} Tagen"
        }
    }

    /** Prozentwert 0.0–1.0 → "42 %". */
    fun formatPercent(fraction: Float): String {
        val clamped = fraction.coerceIn(0f, 1f)
        return "${(clamped * 100).toInt()} %"
    }
}
