# Smartwatch Companion App
## Functional Specification Document — Flutter v1.0

> **Platform:** Android only (minSdk 21 / Android 5.0+)
> **Stack:** Flutter + Dart, target efisien dan ringan
> **Pasangan:** ESP32-C3 Super Mini Smartwatch (FSD Firmware v2.1)

---

## 0. Prinsip Desain & Arsitektur

### 0.1 Design Philosophy

- **Minimal, modern, dark-first** — UI gelap dengan accent warna yang vivid. Terasa seperti app jam kelas atas, bukan utility biasa
- **Satu tujuan per layar** — tidak ada screen yang overloaded. Tiap screen punya satu aksi utama yang jelas
- **Interaktif & responsif** — animasi yang meaningful, bukan decorative. Setiap interaksi ada visual feedback
- **Efisien** — tidak ada background service permanen. BLE hanya aktif saat user buka app atau ada transfer aktif

### 0.2 Tech Stack

| Layer | Pilihan | Alasan |
| :--- | :--- | :--- |
| Framework | Flutter 3.x (stable) | Cross-compile, widget rich, animasi smooth |
| State Management | Riverpod | Lightweight, testable, tidak overkill |
| BLE | `flutter_blue_plus` | Paling aktif di-maintain, Android support bagus |
| Image Processing | `image` package (pure Dart) | Tidak butuh native code, convert RGB565 di Dart |
| Storage | `shared_preferences` + `path_provider` | Simpan preset wallpaper dan setting |
| Permissions | `permission_handler` | Bluetooth + storage runtime permission |
| File picker | `file_picker` | Pilih gambar dari galeri/storage |

### 0.3 Golden Rules App

| ID | Rule |
| :--- | :--- |
| APP-001 | BLE scan **hanya** aktif saat user di halaman Connect. Tidak ada background scan |
| APP-002 | Image conversion dilakukan di **Isolate terpisah** — UI tidak boleh freeze saat proses |
| APP-003 | Semua BLE operation ada **timeout 10 detik** — tidak boleh hang selamanya |
| APP-004 | App bisa dipakai **offline penuh** untuk fitur konversi gambar — tidak butuh device |
| APP-005 | State koneksi BLE harus selalu **visible** di semua screen via persistent status bar |
| APP-006 | Tidak ada data yang dikirim ke internet — semua lokal |

---

## 1. Struktur Navigasi

```
App Launch
    │
    ▼
[ Dashboard / Home ]
    │
    ├──► [ Connect ]         — scan, pair, connection status
    │
    ├──► [ Wallpaper Studio ] — pilih gambar, preview, convert, send
    │
    ├──► [ Watch Data ]      — lihat HR history, steps (setelah BLE connected)
    │
    └──► [ Settings ]        — about, device info, sync preferences
```

**Bottom navigation bar** dengan 4 tab: Home, Wallpaper, Data, Settings.
Tab Wallpaper dan Data bisa diakses offline — Data akan tampil data terakhir yang di-cache.

---

## 2. BLE Protocol (Firmware Interface)

> Section ini adalah kontrak antara app dan firmware. **Kedua sisi harus implement persis ini.**

### 2.1 Service & Characteristic UUIDs

```dart
// Main service
const String WATCH_SERVICE_UUID = "12345678-1234-1234-1234-123456789abc";

// Characteristics
const String CHAR_TIME_SYNC_UUID    = "12345678-1234-1234-1234-123456789001";
const String CHAR_WALLPAPER_UUID    = "12345678-1234-1234-1234-123456789002";
const String CHAR_HR_DATA_UUID      = "12345678-1234-1234-1234-123456789003";
const String CHAR_STEPS_UUID        = "12345678-1234-1234-1234-123456789004";
const String CHAR_BATTERY_UUID      = "12345678-1234-1234-1234-123456789005";
const String CHAR_CONTROL_UUID      = "12345678-1234-1234-1234-123456789006";
```

### 2.2 BLE Device Name

Firmware harus advertise dengan nama: `"ESP32Watch"`
App scan dan filter berdasarkan nama ini.

### 2.3 Time Sync Protocol

App kirim timestamp ke `CHAR_TIME_SYNC_UUID`:

```
Format: 8 bytes
[0]   = year - 2000  (uint8, e.g. 25 untuk 2025)
[1]   = month        (uint8, 1-12)
[2]   = day          (uint8, 1-31)
[3]   = hour         (uint8, 0-23)
[4]   = minute       (uint8, 0-59)
[5]   = second       (uint8, 0-59)
[6]   = day_of_week  (uint8, 0=Sun, 1=Mon, ... 6=Sat)
[7]   = checksum     (XOR dari byte 0-6)
```

App kirim time sync otomatis setiap kali BLE connection established.

### 2.4 Wallpaper Transfer Protocol

Wallpaper 240×280 RGB565 = 240 × 280 × 2 bytes = **134,400 bytes (~131 KB)**

Transfer dilakukan dalam **chunks** karena BLE MTU terbatas:

```
Chunk size : 512 bytes
Total chunks: ceil(134400 / 512) = 263 chunks

Setiap chunk:
[0-1]  = chunk index (uint16, little-endian)
[2-3]  = total chunks (uint16, little-endian)
[4-5]  = data length in this chunk (uint16)
[6..n] = RGB565 pixel data

Flow:
1. App kirim CONTROL: CMD_START_WALLPAPER (0x01) + total_size (4 bytes)
2. Firmware ACK: 0x01
3. App kirim chunk 0, 1, 2, ... 262 ke CHAR_WALLPAPER_UUID
4. Firmware ACK tiap chunk: 0x06 (ACK) atau 0x15 (NAK — retry)
5. App kirim CONTROL: CMD_END_WALLPAPER (0x02) + CRC32 (4 bytes)
6. Firmware verify CRC, ACK: 0x01 (OK) atau 0x02 (CRC fail — retry dari awal)
```

### 2.5 Control Commands

Dikirim ke `CHAR_CONTROL_UUID`:

```dart
const int CMD_START_WALLPAPER = 0x01;
const int CMD_END_WALLPAPER   = 0x02;
const int CMD_REQUEST_HR      = 0x03;
const int CMD_REQUEST_STEPS   = 0x04;
const int CMD_REQUEST_BATTERY = 0x05;
const int CMD_SYNC_TIME       = 0x06;
const int CMD_REBOOT_WATCH    = 0x07;  // emergency only
```

### 2.6 Data dari Firmware ke App

Firmware notify app via characteristic notifications:

```
CHAR_HR_DATA:
  [0]   = bpm (uint8)
  [1]   = spo2 (uint8)
  [2-3] = timestamp minutes since midnight (uint16)

CHAR_STEPS:
  [0-3] = step count today (uint32, little-endian)

CHAR_BATTERY:
  [0]   = percentage (uint8, 0-100)
  [1]   = is_charging (uint8, 0 or 1)
```

---

## 3. Screens & UI Spec

### 3.1 Global UI Constants

```dart
// Color palette — dark theme
const Color bgPrimary    = Color(0xFF0D0D14);  // hampir hitam, sedikit biru
const Color bgSurface    = Color(0xFF16161F);  // card background
const Color bgElevated   = Color(0xFF1E1E2A);  // elevated surface
const Color accentPurple = Color(0xFF7F77DD);  // primary accent
const Color accentTeal   = Color(0xFF1D9E75);  // success / HR
const Color accentAmber  = Color(0xFFEF9F27);  // warning / battery
const Color accentRed    = Color(0xFFE24B4A);  // danger / low batt
const Color textPrimary  = Color(0xFFEEEEF5);
const Color textSecond   = Color(0xFF888799);
const Color textHint     = Color(0xFF44445A);

// Typography
// Font: Inter (Google Fonts) — clean, modern, readable kecil-kecil
// Jam display: tabular figures, weight 700
// Label: weight 400, 12-13px
// Value: weight 600, berbeda size per konteks
```

### 3.2 Screen: Home / Dashboard

**Layout:** Dark background. Jam besar di tengah atas. Card grid di bawahnya.

**Elemen:**
- Jam realtime HP (bukan dari watch) — besar, font tabular, di tengah atas
- Status bar BLE: pill kecil pojok kanan atas — "Connected" (teal) / "Disconnected" (merah) / "Scanning..." (amber animasi pulse)
- 4 metric cards dalam 2×2 grid:
  - Heart Rate: angka BPM + icon jantung animasi pulse kalau connected
  - Steps: angka + progress bar tipis menuju goal
  - Battery: persentase + icon + charging indicator
  - Last sync: waktu terakhir data di-update
- FAB bawah: "Sync Now" — trigger time sync + data refresh, hanya aktif kalau connected
- Animasi: cards fade-in staggered saat pertama load

**Empty state** (belum connected): cards tampil dengan data "—", ada hint "Connect your watch"

### 3.3 Screen: Connect

**Layout:** Minimalis. Center-focused.

**Elemen:**
- Ilustrasi watch kecil di tengah atas (SVG sederhana, bukan gambar besar)
- Status text besar: "Looking for watch..." / "Connected to ESP32Watch" / "Not found"
- Tombol besar rounded: "Scan" / "Disconnect"
- List hasil scan: tampilkan device name + RSSI bar (signal strength)
- Filter: hanya tampil device dengan nama "ESP32Watch"
- Animasi scan: rotating ring saat scanning aktif
- Setelah connect: otomatis kirim time sync, lalu navigate ke Home

**Permission handling:** kalau Bluetooth permission belum granted, tampil explanation sheet + tombol "Allow" sebelum scan.

### 3.4 Screen: Wallpaper Studio

**Layout:** Full screen preview di atas, controls di bawah.

**Ini screen paling complex dan paling menarik.**

**Elemen:**

*Preview area (atas ~55% screen):*
- Preview berbentuk layar jam (240:280 ratio, rounded corners, bezel hitam tipis)
- Menampilkan gambar yang dipilih setelah di-crop/resize ke 240×280
- Overlay jam kecil di preview (HH:MM putih) untuk liat bagaimana jam akan terlihat di atas wallpaper
- Tombol kecil pojok kanan atas preview: "Pick Image"

*Controls area (bawah ~45% screen):*
- Slider Brightness: adjust brightness gambar sebelum convert
- Slider Contrast: adjust contrast
- Toggle "Dither": aktifkan dithering untuk hasil RGB565 yang lebih smooth
- Preview stats: ukuran file (selalu ~131KB), resolusi (240×280)
- Tombol "Convert & Preview": proses gambar → tampilkan di preview (jalankan di Isolate)
- Progress bar tipis saat converting (karena di Isolate, UI tetap smooth)
- Tombol "Send to Watch": aktif hanya kalau converted + BLE connected
  - Progress dialog saat sending: "Sending chunk 45/263..."
  - Success/fail toast

*State flow:*
```
No image selected
    │ tap "Pick Image"
    ▼
Image picked (original preview)
    │ tap "Convert & Preview"
    ▼
Converting... (progress, non-blocking)
    │ done
    ▼
Converted preview (RGB565 rendered kembali ke RGB untuk preview)
    │ tap "Send to Watch" (if connected)
    ▼
Sending... (chunk progress)
    │ done
    ▼
Success toast
```

*Saved presets:* scroll horizontal di bawah controls, max 5 preset tersimpan. Tap untuk load langsung ke preview.

### 3.5 Screen: Watch Data

**Layout:** Tab kecil di atas (HR | Steps), content di bawah.

**HR Tab:**
- Angka BPM besar + SpO2 secondary
- Animasi: garis EKG sederhana (tidak perlu real-time, cukup animasi loop yang terlihat hidup)
- Last reading timestamp
- Tombol "Take Reading" — kirim CMD_REQUEST_HR ke watch, tunggu notification
- Tombol hanya aktif kalau connected

**Steps Tab:**
- Angka steps besar
- Circular progress menuju goal (default goal 10,000, bisa diset di Settings)
- Estimasi kalori (steps × 0.04 kkal, rough estimate)
- Estimasi jarak (steps × 0.762 meter)
- Tombol "Refresh"

**Empty / disconnected state:** data terakhir di-cache ditampilkan dengan label "Last known · [timestamp]"

### 3.6 Screen: Settings

**Layout:** Standard settings list. Dark surface cards per section.

**Sections:**

*Device:*
- Device name: "ESP32Watch" (static)
- Firmware info: tampil setelah connected
- Reboot watch: tombol destructive (merah), confirm dialog dulu

*Preferences:*
- Step goal: input number (default 10,000)
- Auto time sync on connect: toggle (default ON)
- BLE timeout: slider 5–30 detik (default 10)

*Wallpaper:*
- Default dither: toggle
- Clear saved presets: tombol

*About:*
- App version
- FSD version reference: "Compatible with Firmware FSD v2.1"

---

## 4. Image Conversion — RGB565 Pipeline

### 4.1 Alur Konversi (di Dart Isolate)

```dart
// Input: File gambar (PNG/JPG/BMP dari galeri)
// Output: Uint8List — 134,400 bytes RGB565 little-endian

Future<Uint8List> convertToRGB565({
  required File imageFile,
  required int targetWidth,   // 240
  required int targetHeight,  // 280
  double brightness = 1.0,    // 0.5 – 1.5
  double contrast   = 1.0,    // 0.5 – 1.5
  bool dither       = false,
}) async {
  // 1. Decode gambar dengan package:image
  // 2. Resize ke 240×280 dengan interpolation cubic
  // 3. Apply brightness & contrast adjustment
  // 4. Kalau dither: apply Floyd-Steinberg dithering
  // 5. Convert tiap pixel ke RGB565:
  //    r5 = (r >> 3) & 0x1F
  //    g6 = (g >> 2) & 0x3F
  //    b5 = (b >> 3) & 0x1F
  //    rgb565 = (r5 << 11) | (g6 << 5) | b5
  // 6. Store little-endian: low byte dulu, high byte kedua
  // 7. Return Uint8List
}
```

### 4.2 Preview Kembali ke Layar

Setelah convert, render preview dengan decode balik RGB565 → RGB888 untuk ditampilkan di Flutter:

```dart
// Untuk preview: decode balik RGB565 ke Color
Color rgb565ToColor(int rgb565) {
  final r = ((rgb565 >> 11) & 0x1F) * 255 ~/ 31;
  final g = ((rgb565 >> 5)  & 0x3F) * 255 ~/ 63;
  final b = (rgb565         & 0x1F) * 255 ~/ 31;
  return Color.fromARGB(255, r, g, b);
}
```

### 4.3 Export sebagai .cpp File (Bonus Feature)

Tombol "Export as .cpp" di Wallpaper Studio — generate file teks yang bisa langsung di-paste ke firmware:

```cpp
// Output format:
#include <pgmspace.h>
static const uint16_t WALLPAPER_DATA[] PROGMEM = {
    0x0000, 0x1234, 0xABCD, // ... 134400 values
};
const uint16_t* assets_get_wallpaper()       { return WALLPAPER_DATA; }
uint16_t        assets_get_wallpaper_width() { return 240; }
uint16_t        assets_get_wallpaper_height(){ return 280; }
```

File disimpan ke Downloads folder dengan nama `assets_wallpaper_[timestamp].cpp`

---

## 5. Directory Structure

```
smartwatch_companion/
├── lib/
│   ├── main.dart
│   ├── app.dart                    # MaterialApp, theme, router
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   ├── ble_constants.dart  # UUIDs, command codes
│   │   │   ├── app_colors.dart     # Color palette
│   │   │   └── app_config.dart     # Timeouts, defaults
│   │   ├── theme/
│   │   │   └── app_theme.dart      # ThemeData dark
│   │   └── utils/
│   │       ├── rgb565_converter.dart  # Isolate conversion logic
│   │       └── time_sync.dart         # Build time sync packet
│   │
│   ├── services/
│   │   ├── ble_service.dart        # flutter_blue_plus wrapper
│   │   └── wallpaper_service.dart  # Manage presets, file export
│   │
│   ├── providers/                  # Riverpod providers
│   │   ├── ble_provider.dart
│   │   ├── watch_data_provider.dart
│   │   └── wallpaper_provider.dart
│   │
│   └── screens/
│       ├── home/
│       │   └── home_screen.dart
│       ├── connect/
│       │   └── connect_screen.dart
│       ├── wallpaper/
│       │   ├── wallpaper_screen.dart
│       │   └── widgets/
│       │       ├── watch_preview_widget.dart   # jam preview frame
│       │       └── preset_strip_widget.dart    # horizontal preset scroll
│       ├── data/
│       │   └── data_screen.dart
│       └── settings/
│           └── settings_screen.dart
│
├── pubspec.yaml
└── docs/
    └── FSD_app_v1.0.md
```

---

## 6. pubspec.yaml

```yaml
name: smartwatch_companion
description: Companion app for ESP32-C3 Smartwatch

environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.10.0"

dependencies:
  flutter:
    sdk: flutter

  # BLE
  flutter_blue_plus: ^1.31.15

  # State management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Image processing
  image: ^4.1.7

  # File & storage
  file_picker: ^8.0.3
  path_provider: ^2.1.3
  shared_preferences: ^2.2.3

  # Permissions
  permission_handler: ^11.3.1

  # UI
  google_fonts: ^6.2.1
  flutter_animate: ^4.5.0     # animasi mudah & ringan

dev_dependencies:
  flutter_test:
    sdk: flutter
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.9
  flutter_lints: ^3.0.0
```

---

## 7. Firmware Implementation Guide

> Section ini untuk firmware developer — apa yang harus ditambahkan ke firmware FSD v2.1 untuk support app ini.

### 7.1 Tambahan di FSD v2.1 — Step 6: BLE

**File baru yang dibutuhkan:**
```
lib/drivers/ble_hal.cpp
lib/drivers/ble_hal.h
```

**Dependency tambahan di platformio.ini:**
```ini
lib_deps =
    ; ... existing deps ...
    h2zero/NimBLE-Arduino @ ^1.4.1  ; lebih ringan dari ESP32 BLE default
```

**Interface yang harus diimplementasi:**

```cpp
// ble_hal.h
void ble_hal_init();
void ble_hal_update();              // dipanggil di loop()
bool ble_hal_is_connected();

// Callbacks — di-set oleh state machine
void ble_hal_set_on_time_sync(void (*cb)(uint8_t* data, size_t len));
void ble_hal_set_on_wallpaper_chunk(void (*cb)(uint8_t* data, size_t len));
void ble_hal_set_on_control(void (*cb)(uint8_t cmd, uint8_t* data, size_t len));

// Notify ke app
void ble_hal_notify_hr(uint8_t bpm, uint8_t spo2);
void ble_hal_notify_steps(uint32_t steps);
void ble_hal_notify_battery(uint8_t percent, bool is_charging);
```

**Implementasi time sync di firmware:**

```cpp
// Saat callback time sync dipanggil:
void on_time_sync_received(uint8_t* data, size_t len) {
    if (len < 8) return;
    uint8_t checksum = 0;
    for (int i = 0; i < 7; i++) checksum ^= data[i];
    if (checksum != data[7]) return;  // invalid

    // Set RTC atau variabel waktu
    int year  = 2000 + data[0];
    int month = data[1];
    int day   = data[2];
    int hour  = data[3];
    int min   = data[4];
    int sec   = data[5];
    // Simpan ke RTC_DATA_ATTR agar persistent
}
```

**Wallpaper buffer di firmware:**

```cpp
// Di power_manager atau ble_hal:
// Buffer untuk terima wallpaper — 134400 bytes
// HATI-HATI: ini besar, pastikan masuk Flash, bukan RAM
// Pakai SPIFFS atau langsung tulis ke Flash partition

// Rekomendasi: pakai SPIFFS
// 1. Format SPIFFS di first boot jika belum ada
// 2. Terima chunk BLE → tulis ke /wallpaper.bin via SPIFFS
// 3. Setelah CMD_END_WALLPAPER + CRC OK → set flag "new wallpaper available"
// 4. Di loop berikutnya: baca dari SPIFFS → push ke TFT via pushImage
```

**PENTING — SPIFFS di platformio.ini:**
```ini
board_build.filesystem = spiffs
board_build.partitions = min_spiffs.csv
```

### 7.2 State Machine Update (ui_manager.cpp)

Tambahkan di `ui_manager_update()`:
```cpp
// Di setiap loop iteration, setelah button handling:
ble_hal_update();

// Saat state == EXEC_HR dan ada data baru:
if (max30100_hal_data_ready()) {
    ble_hal_notify_hr(
        (uint8_t)max30100_hal_get_bpm(),
        max30100_hal_get_spo2()
    );
}
```

### 7.3 Ringkasan Perubahan Firmware untuk BLE

| Yang Berubah | Detail |
| :--- | :--- |
| `platformio.ini` | Tambah NimBLE-Arduino, SPIFFS partition |
| `lib/drivers/ble_hal.cpp/h` | File baru — BLE service, characteristics, callbacks |
| `src/main.cpp` | Tambah `ble_hal_init()` di setup(), `ble_hal_update()` di loop() |
| `src/ui_manager.cpp` | Panggil `ble_hal_notify_*` saat ada data baru |
| Flash storage | SPIFFS untuk simpan wallpaper binary |

---

## 8. Development Steps App (Untuk Antigravity Agent)

| Step | Feature | Notes |
| :--- | :--- | :--- |
| 1 | Project setup + theme + navigation | Dark theme, bottom nav, routing |
| 2 | Wallpaper Studio (offline) | Image pick, convert RGB565, preview, export .cpp |
| 3 | BLE service + Connect screen | Scan, connect, disconnect, status |
| 4 | Time sync | Auto-send on connect |
| 5 | Home dashboard + Watch Data | Display data dari BLE notifications |
| 6 | Settings + presets | Persistance, preferences |

**Step 2 bisa jalan tanpa hardware sama sekali** — ini yang paling berguna untuk dikerjain duluan.

---

## 9. UI Interaction Details

### 9.1 Animasi yang Wajib Ada

| Element | Animasi | Library |
| :--- | :--- | :--- |
| BLE status pill | Pulse/breathe saat scanning | `flutter_animate` |
| HR value update | Count-up saat nilai berubah | `flutter_animate` |
| Metric cards | Staggered fade-in saat load | `flutter_animate` |
| Convert button | Loading shimmer saat processing | Custom |
| Send progress | Animated progress bar chunk by chunk | Built-in LinearProgressIndicator |
| Connect screen | Rotating ring saat scan | AnimationController |

### 9.2 Micro-interactions

- Tap metric card → ripple effect + brief scale(0.97)
- Long press preset di Wallpaper Studio → haptic feedback + delete option
- Pull to refresh di Data screen (kalau connected) → trigger data request
- Swipe preset → haptic + remove animation

### 9.3 Error States

| Kondisi | UI Response |
| :--- | :--- |
| BLE permission denied | Bottom sheet explanation + "Open Settings" button |
| BLE off | Snackbar "Please enable Bluetooth" + icon |
| Scan timeout (no watch found) | State change ke "Not found" + retry button |
| Send wallpaper gagal (CRC) | Retry dialog — "Retry", "Cancel" |
| Image too small to convert | Toast "Image too small (min 240×280)" |

---

## 10. Android Permissions (AndroidManifest.xml)

```xml
<!-- Bluetooth -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>

<!-- Location (required for BLE scan on Android < 12) -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>

<!-- Storage (untuk export .cpp file) -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
```

---

## 11. Success Criteria per Feature

### Offline (tidak butuh watch):
- [ ] Pilih gambar dari galeri, tampil di preview watch frame
- [ ] Slider brightness/contrast mengubah preview secara realtime
- [ ] Convert selesai < 3 detik untuk gambar 4MP (di Isolate, UI tidak freeze)
- [ ] Preview RGB565 kelihatan serupa dengan gambar asli
- [ ] Export .cpp menghasilkan file yang valid dan bisa langsung di-paste ke firmware
- [ ] Simpan preset, load preset, hapus preset — works

### BLE (butuh watch dengan Step 6 firmware):
- [ ] Scan menemukan "ESP32Watch" dalam 5 detik
- [ ] Connect berhasil, status pill berubah hijau
- [ ] Time sync otomatis terkirim — jam di watch update sesuai HP
- [ ] Data HR, steps, battery terbaca di Home screen
- [ ] Send wallpaper 131KB selesai < 30 detik
- [ ] Disconnect dan reconnect works tanpa restart app

---

*FSD App v1.0 — Companion untuk ESP32-C3 Smartwatch FSD Firmware v2.1*
*-- END OF DOCUMENT --*
