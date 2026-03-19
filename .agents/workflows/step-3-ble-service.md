---
description: Run the BLE Service Agent to integrate flutter_blue_plus and build the Connect screen.
---

1.  Set up the `flutter_blue_plus` dependency in `pubspec.yaml`.
2.  Implement the logical BLE state machine in `lib/services/ble_service.dart`.
3.  Develop the "Connect" screen for device scanning and pairing.
4.  Configure Bluetooth permissions using `permission_handler` for Android.
5.  Add filtering logic to only show "ESP32Watch" device name (FSD 2.2).
6.  Implement 10s timeout logic for all BLE operations (APP-003).
7.  Verify device discovery and RSSI reporting.

// turbo
8. Test discovery accuracy with real or simulated Bluetooth hardware.
9. Verify "BLE Status Pill" reflects real-time connection state.
10. Ensure the scan is ONLY active on the Connect screen (APP-001).
