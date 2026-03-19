# Smartwatch Companion App - C3Watch

A robust Flutter-based companion application built for the ESP32-C3/S3 smartwatch. This application serves as the central hub for the custom ESP32 smartwatch, offering seamless BLE communication, real-time data streaming, offline custom wallpaper processing, and system management.

## Features

- **Advanced BLE Auto-Connection**: Instantly connects to the `ESP32Watch` with timeout limits and robust error handling.
- **Offline Wallpaper Studio**: Pick an image locally and the app utilizes an isolated `compute()` engine to crop, resize to 240x280, adjust brightness, apply high-quality Floyd-Steinberg dithering, and convert exactly to 16-bit RGB565.
- **Flawless OTA Transfers**: Securely transmits the 134.4 KB custom watchface via a chunked BLE protocol with explicit multi-retry ACKs per chunk and CRC32 verification natively implemented in Dart isolates.
- **Heart Rate & Steps Dashboards**: A fully reactive ecosystem subscribing to HR (BPM/SpO2) and Step streams, securely storing 'Last Known' backups via `shared_preferences`.
- **Auto Time Synchronization**: Precisely encodes the phone's time into an 8-byte checksum packet and dispatches the sync instantly upon BLE connection.

---

## BLE Protocol Data Format Overview
The App communicates to the Smartwatch Firmware (FSD v2.1 compatible) using a standard GAP structure configured under the principal UUID:
**Service UUID**: `12345678-1234-1234-1234-123456789abc`

### Characteristics
| Name | UUID End | Function |
| - | - | - |
| **Control** | `...9006` | Handles Commands & Send Transfer ACKs |
| **Time Sync** | `...9001` | Sets the onboard RTC via 8-byte buffer |
| **Wallpaper**| `...9002` | Stream custom wallpaper chunks (up to 512 bytes) |
| **HR Data** | `...9003` | Streams `uint8` BPM & SpO2 pairs |
| **Steps** | `...9004` | Streams `uint32` continuous step metrics |
| **Battery** | `...9005` | Streams `uint8` percent and charging flags |

### How Data Is Formatted

**1. Auto Time Sync (8 Bytes)**
```c
[0] = Year - 2000
[1] = Month (1-12)
[2] = Day (1-31)
[3] = Hour (0-23)
[4] = Minute (0-59)
[5] = Second (0-59)
[6] = Weekday (0=Sun .. 6=Sat)
[7] = Checksum (XOR bytes 0..6)
```

**2. Wallpaper Chunk Protocol (6 Byte Header + 512 Payload)**
```c
// Starts via CHAR_CONTROL (0x01 + 4 Byte Total Size) -> Waits for 0x01 ACK
[0-1] = Chunk Index (uint16 LE)
[2-3] = Total Chunks (uint16 LE)
[4-5] = Payload Size (uint16 LE)
[6..n] = 512 Max RGB565 pixels (LE format) array
// Stream sends via CHAR_WALLPAPER -> Waits for 0x06 ACK
// Finishes via CHAR_CONTROL (0x02 + CRC32 Hash Check) -> Waits for 0x01 ACK
```

**3. HR Streams (4 Bytes Notifications)**
```c
[0] = Heart Rate BPM (uint8)
[1] = SpO2 Percentage (uint8)
[2-3] = Minutes since midnight (uint16 LE)
```

## How to use this project
To interface your physical ESP32-C3 watch with this app:
1. Ensure the ESP32 firmware is flashing under `ESP32Watch` ADV name.
2. Launch the App and hit **Scan** directly on the Connect Screen.
3. Once paired, Time Sync and Subscriptions orchestrate automatically!
