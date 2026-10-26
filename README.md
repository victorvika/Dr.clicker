# ⚡ Dr.Clicker — Auto Accept for Rapido & Ola Drivers

**Package:** `com.dr.clicker.atikapp`  
**Version:** 1.0.0  
**100% Free · No Firebase · No Login · No Ads · Fully Offline**

---

## 📱 What it does

Dr.Clicker automatically taps the **Accept** button on **Rapido Captain** and **Ola Driver** the instant a ride request appears. It uses Android's Accessibility Service to read the screen and dispatch a tap gesture — no screenshots, no image recognition, no internet.

### Features
- ⚡ **Instant Auto-Accept** — 10–100ms human-like delay for natural behavior
- 🌍 **7 Language Support** — English, Tamil, Telugu, Kannada, Hindi, Marathi, Bengali
- 💰 **Price Filter** — Accept only rides within your price range
- 📍 **Distance Filter** — Filter by pickup & drop distance
- 🟢 **Floating Panel** — Live status overlay on top of Rapido/Ola
- 🔋 **Battery Optimization** — Keeps engine alive in background
- 🔄 **Boot Auto-Start** — Engine restarts when phone turns on
- 📊 **Stats Tracking** — Rides accepted count & click speed

---

## 📥 Download APK

Go to **Actions** tab → Click latest build → Download APK from Artifacts section.

Or build locally:
```bash
flutter pub get
flutter build apk --release
```

---

## 🛠️ First-time Setup on Phone

| Step | Action |
|------|--------|
| 1 | Install the APK and open Dr.Clicker |
| 2 | Tap **"Accessibility Enable Karo"** → Find Dr.Clicker → Enable it |
| 3 | Tap **"Overlay Permission Do"** → Allow display over other apps |
| 4 | Tap **"Battery Optimization Off"** → Allow unrestricted battery |
| 5 | Set your price/distance filters (optional) |
| 6 | Tap **Save Settings** |
| 7 | Flip **Engine Activation** ON ⚡ |
| 8 | Switch to Rapido or Ola — done ✓ |

---

## 🏗️ How to Build

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.24+ (stable channel)
- Android SDK with API level 35
- Java 17

### Steps
```bash
# Clone the repository
git clone <repo-url>
cd Dr.clicker

# Install dependencies
flutter pub get

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/`

---

## 📂 Project Structure

```
lib/
  main.dart              ← Flutter entry point & dark theme
  home_screen.dart       ← Full UI: engine switch, filters, stats

android/app/src/main/
  kotlin/com/dr/clicker/atikapp/
    MainActivity.kt           ← Flutter ↔ Kotlin MethodChannel bridge
    MyAccessibilityService.kt ← Accessibility engine: scan → tap → beep
    FloatingPanelService.kt   ← Draggable overlay panel
    BootReceiver.kt           ← Auto-start on device boot
  res/
    xml/accessibility_service_config.xml
    drawable/                 ← Launcher icon vectors
    mipmap-*/                 ← Launcher icon PNGs (all densities)
    values/strings.xml        ← App name & accessibility description
  AndroidManifest.xml
```

---

## ⚙️ Engine Logic

1. Every Accessibility event from Rapido/Ola is received (50ms throttle)
2. All text nodes in visible windows are scanned for accept keywords in **7 languages**
3. Visible price/distance numbers are extracted and checked against saved filters
4. Matching ride → tap dispatched after **10–100ms** random human-like delay
5. Dual beep plays, counter increments, latency is recorded

---

## 🔒 Privacy

- ❌ No internet permission
- ❌ No data collection
- ❌ No Firebase / analytics
- ❌ No login required
- ❌ No ads
- ✅ 100% offline
- ✅ All data stored locally on device

---

## 📋 Requirements

- Android 6.0 (API 23) or newer
- Rapido Captain app or Ola Driver app installed
- Accessibility Service permission

---

## 📄 License

This project is free to use and distribute.
