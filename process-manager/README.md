# Prozess-Manager

Eine minimalistische, moderne Android-App, die alle laufenden Prozesse und
Hintergrundprozesse übersichtlich anzeigt – inklusive Apps und Programme –
mit detaillierten Informationen zu **Prozessname, Ressourcenverbrauch und
Laufzeit**. Eine zentrale Scan-Funktion erkennt alle aktiven Prozesse;
über **Ein-Klick-Aktionen** werden alle ausgewählten oder alle Prozesse
automatisch beendet.

> Selbstständiges Android-Projekt (Kotlin + Jetpack Compose + Material 3),
> abgelegt unter `process-manager/` in diesem Repository.

---

## Funktionen

| Bereich | Umfang |
| --- | --- |
| **Zentraler Scan** | Ein großer Scan-Button erfasst alle sichtbaren Prozesse & kürzlich aktiven Apps (inkl. automatischem Scan beim Start) |
| **Prozessliste** | App-Label, Prozessname, PID, Status (Vordergrund / Hintergrund / Inaktiv / System), RAM-PSS, Laufzeit bzw. Vordergrundzeit, letzte Aktivität |
| **Details** | Aufklappbare Detailansicht pro Eintrag: Paket, UID, Priorität, Speicher, Laufzeit, Datenquelle |
| **Filter** | Alle · Vordergrund · Hintergrund · Inaktiv · System |
| **Ein-Klick-Beenden** | „Auswahl beenden“, „Alle beenden“ und „Prozess beenden“ (Detailzeile) |
| **Auswahl** | Checkboxen, „Alle auswählen“, „Auswahl aufheben“, Live-Zähler in der Aktionsleiste |
| **Systemübersicht** | Belegter / gesamter Arbeitsspeicher mit Fortschrittsbalken, Warnung bei wenig Speicher |
| **Berechtigungs-Hinweis** | Banner + Info-Dialog für den Sonderzugriff „Nutzungsdaten“, optionaler Root-Modus |
| **Design** | Material 3, heller/dunkler Modus, dezente Indigo-/Teal-/Amber-Akzente, klare Typografie, reaktionsschnelle Lazy-Liste |

## Bedienung

1. **Scannen** – Startet die zentrale Erfassung aller sichtbaren Prozesse.
2. **Liste durchsuchen** – Filter-Chips oben, Klick auf eine Karte öffnet die Details.
3. **Auswählen** – Checkboxen für gezielte Auswahl (oder „Alle auswählen“).
4. **Beenden** – „Auswahl beenden (n)“ bzw. „Alle beenden“ in der unteren
   Aktionsleiste; ein einziger Klick genügt. Die Liste wird danach automatisch
   neu gescannt, ein Snackbar fasst das Ergebnis zusammen.

## Design

* **Farben** (`ui/theme/Color.kt`): neutrale Grauflächen, dezent abgesetzte
  Akzente – Indigo (Aktion/Primär), Teal (System/Sekundär), Amber (Hintergrund).
  Bewusst ohne Wallpaper-Farben (dynamischer Farbmodus), damit das Design
  überall identisch ruhig wirkt.
* **Typografie** (`ui/theme/Type.kt`): halbfette Titel, großzügige
  Zeilenhöhen, geringe Laufweiten-Unterschiede – optimiert für schnelles
  Scannen langer Listen.
* **Status-Pillen** in drei ruhigen Tönen (Vordergrund / Hintergrund /
  Inaktiv) plus dezente „System“-Kennzeichnung.

## Architektur

Reaktiv, Single-Activity, unidirektionaler Datenfluss – denselben Stil
verfolgt das offizielle Referenzprojekt
[android/nowinandroid](https://github.com/android/nowinandroid):

```
app/src/main/java/io/github/processmanager/
├── MainActivity.kt              # Einstiegspunkt, Edge-to-Edge, Theme
├── data/
│   ├── ProcessItem.kt           # Domänenmodell (Prozess, Speicher, Scan, KillReport)
│   ├── ProcessSources.kt        # Interfaces: ProcessScanner / ProcessKiller
│   ├── AndroidProcessScanner.kt # Scan-Implementierung (öffentliche Android-APIs)
│   ├── AndroidProcessKiller.kt  # Beenden-Implementierung (+ optional Root)
│   └── Procfs.kt                # /proc-Fallback für Laufzeiten
├── util/Formatters.kt           # Deutsche Formatierung (RAM, Laufzeit, Zeit)
└── ui/
    ├── theme/                   # Material-3-Farben & Typografie
    ├── components/              # ScanCard, SummaryCard, ProcessCard, Badges
    └── home/                    # HomeScreen, HomeViewModel, HomeUiState
```

* **UI:** vollständig Jetpack Compose + Material 3
* **State:** `HomeUiState` als Single Source of Truth, `StateFlow` + einmalige
  `HomeEvent`-Meldungen (Snackbar)
* **ViewModel:** `HomeViewModel` mit manueller Dependency Injection
  (`ViewModelProvider.Factory`) – bewusst schlank ohne Hilt
* **Hintergrundarbeit:** Coroutines auf `Dispatchers.IO`

## Datenquellen & Android-Grenzen

Android schützt fremde Prozesse konsequent (Sandbox, seit Android 7
`hidepid=2` in `/proc`). Die App nutzt daher ausschließlich **öffentliche,
dokumentierte APIs** – dieselben Bausteine, die auch große App-Manager
verwenden:

1. `ActivityManager.getRunningAppProcesses()` – laufende Prozesse mit
   Priorität und PID (auf modernen Geräten primär die eigenen Prozesse).
2. `ActivityManager.getProcessMemoryInfo()` – PSS-Speicherverbrauch pro
   Prozess (ausdrücklich für Prozess-Manager-UIs freigegeben).
3. `UsageStatsManager` (Sonderzugriff „Nutzungsdaten“) – Apps mit kürzlicher
   Aktivität, Vordergrundzeit und letzter Nutzung; RESUMED/PAUSED-Ereignisse
   bestimmen den aktuellen Vordergrund.
4. `/proc/<pid>/stat` – Laufzeit, sofern lesbar (auf neueren Android-Versionen
   nur für die eigene App → dann zeigt die UI „–“ bzw. Nutzungswerte).
5. `ActivityManager.killBackgroundProcesses()` – Beenden von
   Hintergrundprozessen (benötigt die normale Berechtigung
   `KILL_BACKGROUND_PROCESSES`). Vordergrund- und Systemprozesse bleiben
   geschützt; optionaler **Root-Modus** nutzt zusätzlich `am force-stop`.

## Berechtigungen

| Berechtigung | Typ | Zweck |
| --- | --- | --- |
| `KILL_BACKGROUND_PROCESSES` | normal | Hintergrundprozesse beenden |
| `PACKAGE_USAGE_STATS` | Sonderzugriff (manuell in den Einstellungen) | Alle Apps & Aktivitätszeiten sichtbar machen |
| `QUERY_ALL_PACKAGES` | install-time | Alle installierten Apps benennen/beenden (nur für lokale App-Manager sinnvoll) |

## Build & Test

Voraussetzungen: **JDK 17+**, **Android SDK (API 36)**, Android Studio
(oder CLI). Die Gradle-Wrapper-Version (9.7.1) und die Toolchain-Versionen
sind bewusst an denen des umgebenden
[nowinandroid](https://github.com/android/nowinandroid)-Repositoriums
ausgerichtet (AGP 9.3, Kotlin 2.3, Compose-BOM 2025.09).

```bash
cd process-manager
./gradlew assembleDebug          # Debug-APK
./gradlew installDebug           # auf angeschlossenes Gerät
./gradlew testDebugUnitTest      # Unit-Tests
./gradlew lint                   # Lint-Prüfung
```

## Referenzen (GitHub)

Die Umsetzung orientiert sich an bewährten Open-Source-Projekten:

* [android/nowinandroid](https://github.com/android/nowinandroid) –
  Architektur, Compose-/Material-3-Design und Build-Konventionen
  (dieses Repository).
* [Hamza417/Inure](https://github.com/Hamza417/Inure) –
  „Elegant App Manager“: modernes UX-Vorbild für Listen, Analytics und
  Prozess-/App-Darstellung.
* [MuntashirAkon/AppManager](https://github.com/MuntashirAkon/AppManager) –
  Vollständiger Paket-/Prozess-Manager: Vorbild für die Kombination aus
  normalem Modus (`killBackgroundProcesses`) und erweiterten Modi
  (Root/Shizuku, `force-stop`).
* [jaredrummler/AndroidProcesses](https://github.com/jaredrummler/AndroidProcesses) –
  `/proc`-Basierte Prozesserfassung; zeigt anschaulich, warum `/proc` auf
  Android 7+ nur noch als Fallback für die eigene App taugt (hidepid=2).
* [orhun/PSAUX](https://github.com/orhun/PSAUX) –
  „Android task manager and automated background service killer“
  (u. a. AutoKill-Konzept).

## Hinweis zur App-Store-Policy

`QUERY_ALL_PACKAGES` ist für Play-Store-Veröffentlichungen nur für
bestimmte App-Kategorien (z. B. Geräte-/App-Manager) zugelassen. Für eine
Veröffentlichung müsste die Berechtigung begründet oder durch `<queries>`
ersetzt werden – lokal/sideloaded ist sie der richtige Weg.
