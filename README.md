# Malltopia: My Dream Mall

Native Android 2D mall-management game. **Godot 4.3 + GDScript**. Portrait, touch controls.
Not a web game. APK is built by GitHub Actions.

## Gameplay (prototype v0.1)
- Menu, new game, nickname + avatar (6 colors x 3 styles)
- Walk the mall with the on-screen joystick
- 8 shop plots (Fashion, Snacks, Books, Gadgets, Toys, Pharmacy, Sports, Jewelry). Tap a shop to open / upgrade (Lv 1-5) / hire staff (0-3)
- Customers walk in, pick a shop, spend coins. No staff: **walk near the shop to collect**. With staff: auto-collect, fewer "Too busy!" walk-outs, wages 8 coins/min each
- Customer satisfaction (Happy %) changes income and customer flow; decorations raise it
- Mall expansion unlocks plots (needs level + coins)
- Arcade machine (tap it or Arcade button): 15s tap game for coins + happiness
- 9 missions, 10 achievements, XP + levels
- Music + SFX (WAV in `assets/audio`), toggles in Menu
- Autosave every 15s, on pause, and from Menu (`user://malltopia_save.json`)

## Project layout
```
project.godot            export_presets.cfg      icon.svg
scenes/Main.tscn Game.tscn
scripts/GS.gd (state, economy, save)  Game.gd (map, AI, UI)  Main.gd (menu)
        Audio.gd  Joystick.gd  Preview.gd
assets/audio/*.wav
tests/smoke.gd           headless gameplay test
.github/workflows/build-android.yml
```

## Get the APK (GitHub Actions)
1. Create a GitHub repo, push this folder to branch `main`.
2. Open **Actions** tab -> **Build Android APK** (runs on push, or click **Run workflow**).
3. When green, open the run -> **Artifacts** -> download `malltopia-debug-apk` (zip) -> unzip -> `malltopia-debug.apk`.

The workflow: installs JDK 17 + Android SDK, downloads Godot 4.3 + export templates, makes a throwaway debug keystore, imports and validates the project (runs `tests/smoke.gd`), exports the debug APK, uploads it.

## Install on Android
1. Copy the APK to the phone (or download it there).
2. Open it. Allow "Install unknown apps" for your file manager/browser when asked.
3. Install, open **Malltopia**.
Or with USB debugging: `adb install -r malltopia-debug.apk`

## Run locally
Open folder in Godot 4.3, press F5. Keyboard arrows move the player on desktop.
Headless test: `godot --headless --path . -s tests/smoke.gd`

## Release signing (later)
Debug APK only for now. **Never commit keystores.** For a release build, store keystore as GitHub Secrets (base64 keystore + passwords), decode in the workflow, add a `Android Release` preset. `.gitignore` already blocks `*.keystore`, `*.jks`, `export_credentials.cfg`.

## Roadmap
Phase 2: more shops/NPC types, customer wishlists, staff skills, second arcade game. Phase 3: events, offline earnings, art pass, localization.
