package io.github.processmanager

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import io.github.processmanager.ui.home.HomeScreen
import io.github.processmanager.ui.theme.ProcessManagerTheme

/**
 * Einstiegspunkt: eine einzige Activity, komplette UI in Jetpack Compose.
 */
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            ProcessManagerTheme {
                HomeScreen()
            }
        }
    }
}
