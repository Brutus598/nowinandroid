package io.github.processmanager.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// -------------------------------------------------------------------------
// Basis-Palette: neutrale Grautöne mit dezenten Indigo- und Teal-Akzenten.
// -------------------------------------------------------------------------

// Indigo (Primär)
val Indigo40 = Color(0xFF4B57C7)
val Indigo80 = Color(0xFFBAC2FF)
val IndigoContainerLight = Color(0xFFDEE0FF)
val IndigoOnContainerLight = Color(0xFF101457)
val IndigoContainerDark = Color(0xFF35419E)
val IndigoOnContainerDark = Color(0xFFDEE0FF)

// Teal (Sekundär / System)
val Teal40 = Color(0xFF00696C)
val Teal80 = Color(0xFF80D5D5)
val TealContainerLight = Color(0xFF9CF1F1)
val TealOnContainerLight = Color(0xFF002020)
val TealContainerDark = Color(0xFF004F51)
val TealOnContainerDark = Color(0xFF9CF1F1)

// Amber (Tertiär / Hintergrund)
val Amber40 = Color(0xFF8B6000)
val Amber80 = Color(0xFFF2BF6B)
val AmberContainerLight = Color(0xFFFFDF9E)
val AmberOnContainerLight = Color(0xFF2B1700)
val AmberContainerDark = Color(0xFF654100)
val AmberOnContainerDark = Color(0xFFFFDF9E)

// Neutrale Flächen
val SurfaceLight = Color(0xFFF8F9FF)
val OnSurfaceLight = Color(0xFF1A1B21)
val SurfaceVariantLight = Color(0xFFE3E4EE)
val OnSurfaceVariantLight = Color(0xFF45464F)
val OutlineLight = Color(0xFF757680)
val OutlineVariantLight = Color(0xFFC6C6D0)

val SurfaceDark = Color(0xFF121318)
val OnSurfaceDark = Color(0xFFE3E4EC)
val SurfaceVariantDark = Color(0xFF45464F)
val OnSurfaceVariantDark = Color(0xFFC6C6D0)
val OutlineDark = Color(0xFF90909A)
val OutlineVariantDark = Color(0xFF2E3036)

val LightColors = lightColorScheme(
    primary = Indigo40,
    onPrimary = Color.White,
    primaryContainer = IndigoContainerLight,
    onPrimaryContainer = IndigoOnContainerLight,
    secondary = Teal40,
    onSecondary = Color.White,
    secondaryContainer = TealContainerLight,
    onSecondaryContainer = TealOnContainerLight,
    tertiary = Amber40,
    onTertiary = Color.White,
    tertiaryContainer = AmberContainerLight,
    onTertiaryContainer = AmberOnContainerLight,
    error = Color(0xFFBA1A1A),
    onError = Color.White,
    errorContainer = Color(0xFFFFDAD6),
    onErrorContainer = Color(0xFF410002),
    background = SurfaceLight,
    onBackground = OnSurfaceLight,
    surface = SurfaceLight,
    onSurface = OnSurfaceLight,
    surfaceVariant = SurfaceVariantLight,
    onSurfaceVariant = OnSurfaceVariantLight,
    outline = OutlineLight,
    outlineVariant = OutlineVariantLight,
    inverseSurface = OnSurfaceLight,
    inverseOnSurface = SurfaceLight,
    inversePrimary = Indigo80,
    surfaceContainerLowest = Color.White,
    surfaceContainerLow = Color(0xFFF2F3FA),
    surfaceContainer = Color(0xFFECEDF5),
    surfaceContainerHigh = Color(0xFFE6E8EF),
    surfaceContainerHighest = SurfaceVariantLight,
)

val DarkColors = darkColorScheme(
    primary = Indigo80,
    onPrimary = Color(0xFF17207A),
    primaryContainer = IndigoContainerDark,
    onPrimaryContainer = IndigoOnContainerDark,
    secondary = Teal80,
    onSecondary = Color(0xFF003738),
    secondaryContainer = TealContainerDark,
    onSecondaryContainer = TealOnContainerDark,
    tertiary = Amber80,
    onTertiary = Color(0xFF462B00),
    tertiaryContainer = AmberContainerDark,
    onTertiaryContainer = AmberOnContainerDark,
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF690005),
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFDAD6),
    background = SurfaceDark,
    onBackground = OnSurfaceDark,
    surface = SurfaceDark,
    onSurface = OnSurfaceDark,
    surfaceVariant = SurfaceVariantDark,
    onSurfaceVariant = OnSurfaceVariantDark,
    outline = OutlineDark,
    outlineVariant = OutlineVariantDark,
    inverseSurface = OnSurfaceDark,
    inverseOnSurface = SurfaceDark,
    inversePrimary = Indigo40,
    surfaceContainerLowest = Color(0xFF0D0E13),
    surfaceContainerLow = Color(0xFF1A1B21),
    surfaceContainer = Color(0xFF1E1F25),
    surfaceContainerHigh = Color(0xFF292A2F),
    surfaceContainerHighest = SurfaceVariantDark,
)

/** Aktive Farbschema-Auswahl (helles/dunkles System-Theme). */
@Composable
fun processManagerColors() = if (isSystemInDarkTheme()) DarkColors else LightColors
