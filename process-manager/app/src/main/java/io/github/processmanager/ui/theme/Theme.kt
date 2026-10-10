package io.github.processmanager.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable

/**
 * App-Theme: Material 3 mit dezenten Farbakzenten (Indigo/Teal/Amber)
 * und klarer Typografie. Bewusst ohne dynamische Wallpaper-Farben, damit
 * das Design auf jedem Gerät identisch ruhig bleibt.
 */
@Composable
fun ProcessManagerTheme(
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = processManagerColors(),
        typography = ProcessManagerTypography,
        content = content,
    )
}
