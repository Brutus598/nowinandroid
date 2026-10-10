package io.github.processmanager.ui.components

import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import io.github.processmanager.R
import io.github.processmanager.data.ProcessState

/**
 * Dezente Status-Pille (Vordergrund / Hintergrund / Inaktiv).
 */
@Composable
fun ProcessStateBadge(
    state: ProcessState,
    modifier: Modifier = Modifier,
) {
    val containerColor = when (state) {
        ProcessState.FOREGROUND -> MaterialTheme.colorScheme.primaryContainer
        ProcessState.BACKGROUND -> MaterialTheme.colorScheme.tertiaryContainer
        ProcessState.INACTIVE -> MaterialTheme.colorScheme.surfaceVariant
    }
    val contentColor = when (state) {
        ProcessState.FOREGROUND -> MaterialTheme.colorScheme.onPrimaryContainer
        ProcessState.BACKGROUND -> MaterialTheme.colorScheme.onTertiaryContainer
        ProcessState.INACTIVE -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    val label = when (state) {
        ProcessState.FOREGROUND -> stringResource(R.string.badge_foreground)
        ProcessState.BACKGROUND -> stringResource(R.string.badge_background)
        ProcessState.INACTIVE -> stringResource(R.string.badge_inactive)
    }
    Surface(
        modifier = modifier,
        shape = CircleShape,
        color = containerColor,
        contentColor = contentColor,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
        )
    }
}

/**
 * Kleine Kennzeichnung für System-Apps/-Prozesse.
 */
@Composable
fun SystemBadge(modifier: Modifier = Modifier) {
    Surface(
        modifier = modifier,
        shape = CircleShape,
        color = MaterialTheme.colorScheme.secondaryContainer,
        contentColor = MaterialTheme.colorScheme.onSecondaryContainer,
    ) {
        Text(
            text = stringResource(R.string.badge_system),
            style = MaterialTheme.typography.labelSmall,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
        )
    }
}
