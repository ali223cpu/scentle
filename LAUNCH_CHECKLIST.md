# Scentle — Production Launch & Deployment Checklist 🏛️✨

Welcome to the definitive deployment and operations guide for **Scentle** — the offline-first luxury fragrance deduction game and real-time 1v1 multiplayer arena powered by your local SQL Server Fragrantica dataset.

---

## 1. System Architecture & Dataset Metrics

| Metric | Specification | Engineering Guarantee |
| :--- | :--- | :--- |
| **Searchable Catalog (Tier 1)** | **12,280 Perfumes** | Instant client-side prefix matching & diacritic-agnostic search |
| **Mystery Target Pool (Tier 2)** | **1,229 Iconic Fragrances** | Filtered by \(\ge 200\) community votes, complete 3-tier pyramids, \(\le 2\) flankers/line |
| **Asset Bundle Footprint** | **4.46 MB (`scentle_db.json`)** | Compressed minified JSON bundled directly into app assets |
| **Zero-Server Runtime Cost** | **$0 / month** | 100% offline-first single player; peer-to-peer style multiplayer over Firebase REST/SSE |
| **Security & Privacy** | **Zero Data Scraping** | Nominative fair-use attribution; anonymous local device IDs |
| **Network Resilience** | **Zero Hard Web Dependencies** | Graceful fallback for offline play, CDN failures, and clock manipulation |

---

## 2. Running Locally in Development Mode

Ensure Flutter 3.38+ is available on your PATH:

```bash
cd scentle_app
flutter pub get
flutter run
```

### Supported Development Targets:
- **Android Emulator / Device** (`flutter run -d android`)
- **iOS Simulator / Device** (`flutter run -d ios`)
- **Windows Desktop** (`flutter run -d windows`)
- **Chrome / Web** (`flutter run -d chrome`)

---

## 3. Worldwide 1v1 Live Multiplayer in 60 Seconds ($0 Setup)

Scentle uses a zero-SDK, zero-CocoaPods/Gradle network transport (`FirebaseRestSseTransport`) that speaks native HTTP REST + Server-Sent Events (`text/event-stream`).

### Step-by-Step Setup:
1. Open the [Firebase Console](https://console.firebase.google.com/) and create a free project (e.g. `scentle-live`).
2. In the left navigation, go to **Build** → **Realtime Database** and click **Create Database**.
3. Choose your nearest region (e.g., `us-central1` or `europe-west1`) and start in test mode.
4. Go to the **Rules** tab, paste the complete contents of [`scentle_app/firebase_database.rules.json`](./scentle_app/firebase_database.rules.json), and click **Publish**:

```json
{
  "rules": {
    ".read": false,
    ".write": false,
    "rooms": {
      ".read": true,
      "$roomCode": {
        ".write": "!data.exists() || data.child('status').val() != 'finished' || !newData.exists()",
        ".validate": "newData.hasChildren(['roomCode', 'status', 'targetPerfumeId']) && newData.child('targetPerfumeId').isNumber() && newData.child('roomCode').val().length == 4"
      }
    }
  }
}
```

5. Copy your database URL (e.g., `https://scentle-live-default-rtdb.firebaseio.com/`).
6. Run or compile the app passing your URL via `--dart-define`:

```bash
flutter run --dart-define=FIREBASE_DB_URL=https://scentle-live-default-rtdb.firebaseio.com
```

*Note: If no URL is provided, Scentle automatically operates in simulated offline mode with `SmartBotController` pairing immediately.*

---

## 4. Production Android Release Build

To build hardened, minified, split APKs ready for Google Play Store internal testing or side-loading:

```bash
cd scentle_app
flutter build apk --release --split-per-abi --dart-define=FIREBASE_DB_URL=https://your-project-default-rtdb.firebaseio.com
```

### Outputs Generated in `build/app/outputs/flutter-apk/`:
1. `app-armeabi-v7a-release.apk` (32-bit ARM mobile devices)
2. `app-arm64-v8a-release.apk` (64-bit modern Android devices)
3. `app-x86_64-release.apk` (64-bit emulators & tablets)

### Production Hardening Validations:
- `android.permission.INTERNET` and `android.permission.ACCESS_NETWORK_STATE` enabled in `AndroidManifest.xml`.
- App label set to `Scentle`.
- `proguard-rules.pro` protects Flutter engine, Hive NoSQL persistence, and SSL networking from R8 code-stripping.

---

## 5. Verification & Quality Assurance Audit

Run the test suite and static analysis at any time:

```bash
# Static analysis (zero warnings target)
flutter analyze

# Full unit, widget, and integration test suite
flutter test
```

### Test Suite Map:
- **`test/game_engine_test.dart`**: Game engine, 6-turn evaluation, flanker matching, clue pyramid unlocker, and daily persistence.
- **`test/perfume_repository_test.dart`**: In-memory database loading, index integrity, diacritic normalizer, and mystery pool.
- **`test/multiplayer_test.dart`**: Room serialization, 120s match clock, ELO rating updates, and rematch flow.
- **`test/smart_bot_and_matchmaking_test.dart`**: 6-second auto-bot queue fallback, AI deduction heuristics, network UTC anti-cheat, and settings modal.
- **`test/widget_smoke_test.dart`**: UI responsiveness, dark theme components, hotlink-shielded flacons, and zero-overflow layout.
- **`test/cabinet_and_release_test.dart`**: Scent Cabinet showcase, trophy unlocking, dossier modal, and daily streak reminders.
