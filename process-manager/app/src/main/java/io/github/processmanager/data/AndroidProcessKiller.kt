package io.github.processmanager.data

import android.app.ActivityManager
import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

/**
 * Beendet Hintergrundprozesse über die öffentliche
 * `ActivityManager.killBackgroundProcesses()`-API (benötigt die normale
 * Berechtigung `KILL_BACKGROUND_PROCESSES`).
 *
 * Optionale Root-Ebene: `am force-stop` über `su` – analog zu den
 * erweiterten Modi großer App-Manager (siehe MuntashirAkon/AppManager).
 */
class AndroidProcessKiller(
    context: Context,
) : ProcessKiller {

    private val appContext = context.applicationContext
    private val activityManager =
        appContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager

    override suspend fun kill(items: List<ProcessItem>, useRoot: Boolean): KillReport =
        withContext(Dispatchers.IO) {
            val killed = mutableListOf<String>()
            val failed = mutableListOf<String>()
            val skipped = mutableListOf<ProcessItem>()

            val targets = items.distinctBy { it.packageName ?: it.id }
            for (item in targets) {
                val packageName = item.packageName
                if (packageName == null || item.isSelf) {
                    skipped += item
                    continue
                }
                if (item.state == ProcessState.FOREGROUND && !useRoot) {
                    // Vordergrund-Prozesse sind ohne Root geschützt.
                    skipped += item
                    continue
                }

                var success = false
                try {
                    activityManager.killBackgroundProcesses(packageName)
                    success = true
                } catch (_: Exception) {
                    success = false
                }

                if (!success && useRoot) {
                    success = forceStopWithRoot(packageName)
                }
                if (useRoot && item.state == ProcessState.FOREGROUND) {
                    success = forceStopWithRoot(packageName) || success
                }

                if (success) {
                    killed += packageName
                } else {
                    failed += packageName
                }
            }

            KillReport(
                killedPackages = killed,
                failedPackages = failed,
                skipped = skipped,
            )
        }

    private fun forceStopWithRoot(packageName: String): Boolean = try {
        val process = Runtime.getRuntime()
            .exec(arrayOf("su", "-c", "am force-stop $packageName"))
        val finished = process.waitFor(FORCE_STOP_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        process.destroy()
        finished && runCatching { process.exitValue() == 0 }.getOrDefault(false)
    } catch (_: Exception) {
        false
    }

    private companion object {
        const val FORCE_STOP_TIMEOUT_SECONDS = 3L
    }
}
