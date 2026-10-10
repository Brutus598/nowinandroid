/*
 * Root build script. Listing all plugins here keeps the build script classpath
 * identical for all projects (same convention as android/nowinandroid).
 */
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.compose) apply false
}
