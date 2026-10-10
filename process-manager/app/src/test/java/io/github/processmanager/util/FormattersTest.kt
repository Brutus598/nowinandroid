package io.github.processmanager.util

import com.google.common.truth.Truth.assertThat
import org.junit.Test

class FormattersTest {

    @Test
    fun formatMemory_unknownForNullOrZero() {
        assertThat(Formatters.formatMemory(null)).isEqualTo(Formatters.UNKNOWN)
        assertThat(Formatters.formatMemory(0)).isEqualTo(Formatters.UNKNOWN)
        assertThat(Formatters.formatMemory(-5)).isEqualTo(Formatters.UNKNOWN)
    }

    @Test
    fun formatMemory_megabytes() {
        assertThat(Formatters.formatMemory(512L * 1024)).isEqualTo("512 MB")
        assertThat(Formatters.formatMemory(96L * 1024)).isEqualTo("96 MB")
    }

    @Test
    fun formatMemory_gigabytesWithComma() {
        // 1,2 GB
        assertThat(Formatters.formatMemory(1_258_291L)).isEqualTo("1,2 GB")
        // 2,0 GB
        assertThat(Formatters.formatMemory(2L * 1024 * 1024)).isEqualTo("2,0 GB")
    }

    @Test
    fun formatDuration_secondsMinutesHoursDays() {
        assertThat(Formatters.formatDuration(null)).isEqualTo(Formatters.UNKNOWN)
        assertThat(Formatters.formatDuration(-1)).isEqualTo(Formatters.UNKNOWN)
        assertThat(Formatters.formatDuration(45_000)).isEqualTo("45 s")
        assertThat(Formatters.formatDuration(12L * 60_000)).isEqualTo("12 Min")
        assertThat(Formatters.formatDuration(2L * 3_600_000)).isEqualTo("2 Std")
        assertThat(Formatters.formatDuration((2L * 3_600 + 5 * 60) * 1000)).isEqualTo("2 Std 5 Min")
        assertThat(Formatters.formatDuration((3L * 86_400 + 4 * 3_600) * 1000))
            .isEqualTo("3 Tg 4 Std")
    }

    @Test
    fun formatRelativeTime_buckets() {
        val now = 1_700_000_000_000L
        assertThat(Formatters.formatRelativeTime(null, now)).isEqualTo(Formatters.UNKNOWN)
        assertThat(Formatters.formatRelativeTime(now, now)).isEqualTo("gerade eben")
        assertThat(Formatters.formatRelativeTime(now - 5 * 60_000L, now)).isEqualTo("vor 5 Min")
        assertThat(Formatters.formatRelativeTime(now - 2 * 3_600_000L, now)).isEqualTo("vor 2 Std")
        assertThat(Formatters.formatRelativeTime(now - 25 * 3_600_000L, now)).isEqualTo("gestern")
        assertThat(Formatters.formatRelativeTime(now - 3 * 86_400_000L, now)).isEqualTo("vor 3 Tagen")
    }

    @Test
    fun formatPercent_clampsAndRounds() {
        assertThat(Formatters.formatPercent(0.42f)).isEqualTo("42 %")
        assertThat(Formatters.formatPercent(0f)).isEqualTo("0 %")
        assertThat(Formatters.formatPercent(1.5f)).isEqualTo("100 %")
    }
}
