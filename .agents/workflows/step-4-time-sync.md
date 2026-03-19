---
description: Run the Time Sync Agent to create the 8-byte binary sync packet and integrate auto-update.
---

1.  Build the `time_sync.dart` utility to convert PHP's DateTime into the 8-byte format.
2.  Implement the XOR checksum for packet validation (FSD 2.3).
3.  Inject the auto-sync trigger into the `ble_service.dart` immediately after connection.
4.  Add manual sync functionality for the dashboard's "Sync Now" button.
5.  Verify the byte structure: [YY][MM][DD][HH][MM][SS][DW][CS].

// turbo
6. Test XOR checksum calculation logic.
7. Verify binary data ordering (Little-Endian) matches FSD v1.0.
8. Confirm sync action is logged upon each successful connection.
