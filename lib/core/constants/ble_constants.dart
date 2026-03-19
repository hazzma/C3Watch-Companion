class BleConstants {
  // Main service
  static const String watchServiceUuid = "12345678-1234-1234-1234-123456789abc";

  // Characteristics
  static const String charTimeSyncUuid = "12345678-1234-1234-1234-123456789001";
  static const String charWallpaperUuid = "12345678-1234-1234-1234-123456789002";
  static const String charHrDataUuid = "12345678-1234-1234-1234-123456789003";
  static const String charStepsUuid = "12345678-1234-1234-1234-123456789004";
  static const String charBatteryUuid = "12345678-1234-1234-1234-123456789005";
  static const String charControlUuid = "12345678-1234-1234-1234-123456789006";

  // Device Name
  static const String deviceName = "ESP32Watch";

  // Control Commands
  static const int cmdStartWallpaper = 0x01;
  static const int cmdEndWallpaper = 0x02;
  static const int cmdRequestHr = 0x03;
  static const int cmdRequestSteps = 0x04;
  static const int cmdRequestBattery = 0x05;
  static const int cmdSyncTime = 0x06;
  static const int cmdRebootWatch = 0x07;
}
