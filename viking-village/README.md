# Nordheim – Wikinger-Dorf

Ein **komplett neues 3D-Dorfspiel für Android** (und Linux) im Wikinger-Stil,
inspiriert von *Age of Empires*. Entwickelt mit **Godot 4.3** – alle 3D-Modelle,
Animationen, Texturen und sogar der Sieges-Sound werden **prozedural im Code
erzeugt** (keine externen Assets nötig).

![Stil](icon.svg)

## Spielprinzip

Du gründest das Wikinger-Dorf **Nordheim** an einem Fjord. Schicke deine
Dorfbewohner los, um **Ressourcen** zu sammeln, errichte Gebäude, steigere
durch drei Zeitalter auf und vollende die **Große Halle**, um zu gewinnen.

### Ressourcen

| Ressource | Woher |
|---|---|
| **Holz** | Kiefern und Bäume fällen |
| **Essen** | Beerenbüsche, Bauernhöfe (wachsen nach), Angelstellen im Fjord |
| **Gold** | Goldadern in den Felsen |
| **Stein** | Steinbrüche |
| **Metall** | Eisenerze |
| **Ölstein** | geheimnisvoll grün glühende Steine in den Bergen |

### Gebäude

| Gebäude | Kosten | Funktion |
|---|---|---|
| **Langhaus** | 150 Holz, 50 Stein | +5 Bevölkerung, nimmt Essen an |
| **Lagerhaus** | 100 Holz | nimmt Holz, Stein, Metall, Gold, Ölstein an |
| **Schmiede** | 100 Holz, 100 Stein | nötig für den Aufstieg in die Handelszeit |
| **Große Halle** | 300 Holz, 200 Stein, 100 Gold | Sieges-Gebäude (nur ab Siedlungszeit) |

### Zeitalter

1. **Wikingerzeit** (Start)
2. **Handelszeit** – erfordert 300 Essen + eine Schmiede
3. **Siedlungszeit** – erfordert 300 Gold + 200 Holz → schaltet die Große Halle frei

### Steuerung

- **Linksklick**: Dorfbewohner wählen / Befehle geben (Ressource = sammeln,
  Gebäude = bauen bzw. abliefern, Boden = laufen)
- **Rechte Maustaste (halten)**: Kamera drehen
- **Mausrad**: Zoomen
- **WASD / Pfeiltasten**: Kamera verschieben
- **Touch (Android)**: 1 Finger = Kamera verschieben & tippen, 2 Finger = zoomen/drehen
- **ESC**: Bau-Modus abbrechen / Selektion aufheben

## 3D-Animation & Visuals

- Dorfbewohner: prozedurale Charaktere (Körper, Kopf, Eisenhelm, Axt) mit
  **Idle-Atmung, Geh-Bobbing, Axtschwung beim Sammeln**, Trag-Sack am Rücken
  (wächst mit der Menge) und pulsierendem Selektionsring
- Ressourcen: Bäume **schwanken** und **fallen animiert um**, Felsen
  **pulsieren** beim Abbau, Fische **springen** aus dem Fjord, Ölsteine glühen
- Gebäude: **Geister-Vorschau** während des Bauens, Fortschrittsanzeige,
  **Pop-Animation** bei Fertigstellung, flackernde Schmiede/Esse, Banner
- Welt: gewellter Fjord (**Shader-Wellen**), prozedurale Berge, Kiefern,
  Zäune, Lagerfeuer, **Langschiff mit rot-weiß gestreiftem Segel**,
  prozedurale Hügel, Himmel mit prozeduraler Sky-Textur, Nebel, Schatten
- Sieg: Fanfare, **komplett prozedural synthetisiert** (AudioStreamGenerator)

## KI-Berater: „Sigrid die Seherin“ (GitHub Responses API)

Im Spiel (unten rechts: **„Seherin (KI)“**) kannst du die Seherin um Rat
fragen – z. B. *„Was soll ich als Nächstes bauen?“*. Die Anfrage geht an die
**GitHub Models Responses API**:

```
POST https://models.github.ai/inference/responses
Authorization: Bearer <GITHUB_TOKEN>
{"model": "gpt-4.1-mini", "input": [{"role": "system", ...}, {"role": "user", ...}]}
```

Der aktuelle Spielstand (Ressourcen, Bevölkerung, Zeitalter, Gebäude) wird als
Kontext mitgeschickt. So antwortet die KI **situationsbezogen**.

**Token hinterlegen:** In der App im Panel unten ein GitHub-Token eintragen
(lokal in `user://nordheim_advisor.cfg` gespeichert, needs „Models“-Zugriff).
Auf Desktop/CI kann stattdessen die Umgebungsvariable `GITHUB_TOKEN` gesetzt
werden. **Ohne Token** antwortet die Seherin im Offline-Modus mit lokalen,
kontextbezogenen Tipps – das Spiel ist also auch komplett offline spielbar.

## Projekt-Struktur

```
viking-village/
├── project.godot               # Godot-4.3-Projekt (Autoloads: Game, AiAdvisor, InputSetup)
├── export_presets.cfg          # Linux- & Android-Export-Presets
├── icon.svg                    # Spiel-Icon (Wikingerhelm)
├── scenes/                     # main, villager, resource_node, building, test_runner, UI
├── scripts/
│   ├── autoload/               # game.gd (Spielzustand), ai_advisor.gd (Responses API)
│   ├── ui/                     # hud.gd, advisor_panel.gd
│   ├── util/                   # proc_materials, proc_3d, fanfare (prozeduraler Sound)
│   ├── test/                   # test_runner.gd (headless Test-Harness)
│   ├── main.gd                 # Spiel-Loop: Selektion, Befehle, Bau-Modus
│   ├── camera_controller.gd    # RTS-Kamera (Maus + Touch)
│   ├── villager.gd             # Dorfbewohner-KI & Animation
│   ├── resource_node.gd        # Ressourcen-Quellen
│   ├── building.gd             # Gebäude
│   └── world_gen.gd            # prozeduraler Weltgenerator (Fjord, Ressourcen, Deko)
└── shaders/water.gdshader      # Wellen-Shader für den Fjord
```

## Lokal bauen & testen

Voraussetzung: Godot 4.3 (Editor oder `linux.headless` Build).

```bash
# Projekt im Editor öffnen (zum Spielen)
godot --path viking-village

# Headless-Tests ausführen (Exit-Code 0 = bestanden)
godot --headless --path viking-village res://scenes/test/test_runner.tscn

# Linux-Build exportieren
godot --headless --path viking-village --export-release "Linux"

# Android-APK exportieren (Export-Templates + Android SDK nötig;
# ein Debug-Keystore unter viking-village/keystore/debug.keystore wird erwartet)
godot --headless --path viking-village --export-release "Android"
```

## Android-APK

Die GitHub-Action [`.github/workflows/viking-village.yml`](../.github/workflows/viking-village.yml)

1. führt den **headless-Test-Harness** aus,
2. exportiert den **Linux-Build** und die **Android-APK** (arm64 + x86_64,
   mit INTERNET-Berechtigung für die KI),
3. veröffentlicht beides als **GitHub-Release** (`nordheim-v1.0.0`),
4. testet zusätzlich die **GitHub Models Responses API**.

Die APK findest du im Release unter
`Nordheim-v1.0.0.apk` – auf einem Android-Gerät installieren (arm64 oder x86_64).
