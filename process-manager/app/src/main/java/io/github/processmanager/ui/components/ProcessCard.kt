package io.github.processmanager.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import io.github.processmanager.R
import io.github.processmanager.data.ProcessItem
import io.github.processmanager.data.ScanSource
import io.github.processmanager.util.Formatters

/**
 * Karte für einen Prozess: Name, Zustand, Ressourcen und Laufzeit,
 * aufklappbare Details und Ein-Klick-Beenden-Option.
 */
@Composable
fun ProcessCard(
    item: ProcessItem,
    isSelected: Boolean,
    isExpanded: Boolean,
    nowMillis: Long,
    onToggleSelection: () -> Unit,
    onToggleExpanded: () -> Unit,
    onKillItem: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val containerColor = if (isSelected) {
        MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.55f)
    } else {
        MaterialTheme.colorScheme.surfaceContainerLow
    }
    val arrowRotation by animateFloatAsState(
        targetValue = if (isExpanded) 180f else 0f,
        label = "expandArrow",
    )

    Card(
        modifier = modifier.fillMaxWidth(),
        onClick = onToggleExpanded,
        colors = CardDefaults.cardColors(containerColor = containerColor),
    ) {
        Column(modifier = Modifier.padding(horizontal = 8.dp, vertical = 10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Checkbox(
                    checked = isSelected,
                    onCheckedChange = { onToggleSelection() },
                )
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = item.label,
                        style = MaterialTheme.typography.titleMedium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        text = item.processName,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                Spacer(modifier = Modifier.width(8.dp))
                Column(
                    horizontalAlignment = Alignment.End,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    ProcessStateBadge(state = item.state)
                    if (item.isSystem) {
                        SystemBadge()
                    }
                }
                Icon(
                    imageVector = Icons.Default.KeyboardArrowDown,
                    contentDescription = null,
                    modifier = Modifier
                        .padding(start = 4.dp)
                        .rotate(arrowRotation),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Text(
                text = statLine(item, nowMillis),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(start = 48.dp, top = 2.dp, end = 12.dp),
            )

            AnimatedVisibility(visible = isExpanded) {
                Column(modifier = Modifier.padding(top = 8.dp)) {
                    HorizontalDivider()
                    Spacer(modifier = Modifier.height(8.dp))
                    DetailRow(
                        label = stringResource(R.string.detail_package),
                        value = item.packageName ?: Formatters.UNKNOWN,
                    )
                    DetailRow(
                        label = stringResource(R.string.detail_process),
                        value = item.processName,
                    )
                    DetailRow(
                        label = stringResource(R.string.detail_pid),
                        value = item.pid?.toString() ?: Formatters.UNKNOWN,
                    )
                    DetailRow(
                        label = stringResource(R.string.detail_uid),
                        value = item.uid?.toString() ?: Formatters.UNKNOWN,
                    )
                    DetailRow(
                        label = stringResource(R.string.detail_importance),
                        value = item.importance?.toString() ?: Formatters.UNKNOWN,
                    )
                    DetailRow(
                        label = stringResource(R.string.detail_memory),
                        value = Formatters.formatMemory(item.memoryKb),
                    )
                    DetailRow(
                        label = stringResource(R.string.detail_uptime),
                        value = Formatters.formatDuration(item.uptimeMillis),
                    )
                    DetailRow(
                        label = stringResource(R.string.detail_foreground_time),
                        value = Formatters.formatDuration(item.foregroundTimeMillis),
                    )
                    DetailRow(
                        label = stringResource(R.string.detail_last_used),
                        value = Formatters.formatRelativeTime(item.lastUsedMillis, nowMillis),
                    )
                    DetailRow(
                        label = stringResource(R.string.detail_source),
                        value = stringResource(
                            when (item.source) {
                                ScanSource.RUNNING_PROCESS -> R.string.source_running
                                ScanSource.USAGE_STATS -> R.string.source_usage
                            },
                        ),
                    )
                    if (item.isKillable) {
                        TextButton(onClick = onKillItem) {
                            Text(
                                text = stringResource(R.string.action_kill_item),
                                color = MaterialTheme.colorScheme.error,
                            )
                        }
                    }
                }
            }
        }
    }
}

private fun statLine(item: ProcessItem, nowMillis: Long): String {
    val segments = buildList {
        item.memoryKb?.let { add("RAM " + Formatters.formatMemory(it)) }
        item.uptimeMillis?.let { add("seit " + Formatters.formatDuration(it)) }
            ?: item.foregroundTimeMillis?.let { add("Fg " + Formatters.formatDuration(it)) }
        item.lastUsedMillis?.let {
            add("aktiv " + Formatters.formatRelativeTime(it, nowMillis))
        }
    }
    return segments.joinToString(" · ").ifEmpty { Formatters.UNKNOWN }
}

@Composable
private fun DetailRow(
    label: String,
    value: String,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 2.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(end = 12.dp),
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodySmall,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}
