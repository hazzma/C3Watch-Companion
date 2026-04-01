import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ble_service.dart';
import '../core/constants/ble_constants.dart';

class WallpaperService {
  static const String _presetsKey = "wallpaper_presets";

  /// Generates the .cpp file format defined in FSD v2.1
  static Future<String> exportCppFile(Uint8List rgbData) async {
    StringBuffer sb = StringBuffer();
    sb.writeln('// Output format:');
    sb.writeln('#include <pgmspace.h>');
    sb.writeln('static const uint16_t WALLPAPER_DATA[] PROGMEM = {');

    // Group into hex arrays
    for (int i = 0; i < rgbData.length; i += 2) {
      if (i % 24 == 0) {
        if (i > 0) sb.writeln();
        sb.write('    ');
      }
      
      // We stored it little-endian, so high byte is i+1, low byte is i
      int lowByte = rgbData[i];
      int highByte = rgbData[i + 1];
      int word = (highByte << 8) | lowByte;
      
      String hex = '0x${word.toRadixString(16).padLeft(4, '0').toUpperCase()}';
      sb.write('$hex, ');
    }
    
    sb.writeln();
    sb.writeln('};');
    sb.writeln('const uint16_t* assets_get_wallpaper()       { return WALLPAPER_DATA; }');
    sb.writeln('uint16_t        assets_get_wallpaper_width() { return 240; }');
    sb.writeln('uint16_t        assets_get_wallpaper_height(){ return 280; }');

    return sb.toString();
  }

  static Future<File> saveExportToDownloads(String cppContent) async {
    Directory? dir;
    if (Platform.isAndroid) {
      // Find downloads folder
      dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        dir = await getExternalStorageDirectory();
      }
    } else {
      dir = await getDownloadsDirectory();
    }
    
    if (dir == null) {
      dir = await getApplicationDocumentsDirectory();
    }

    String timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.-]'), '_').substring(0, 15);
    File file = File('${dir.path}/assets_wallpaper_$timestamp.cpp');
    await file.writeAsString(cppContent);
    return file;
  }

  // Preset management using SharedPreferences
  static Future<List<String>> getSavedPresets() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_presetsKey) ?? [];
  }

  static Future<void> savePreset(String imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> presets = prefs.getStringList(_presetsKey) ?? [];
    
    // Max 5 presets
    if (presets.contains(imagePath)) {
      // Move to front
      presets.remove(imagePath);
    }
    
    presets.insert(0, imagePath);
    if (presets.length > 5) {
      presets = presets.sublist(0, 5);
    }
    await prefs.setStringList(_presetsKey, presets);
  }

  static Future<void> removePreset(String imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> presets = prefs.getStringList(_presetsKey) ?? [];
    if (presets.contains(imagePath)) {
      presets.remove(imagePath);
      await prefs.setStringList(_presetsKey, presets);
    }
  }

  static Future<void> clearPresets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_presetsKey);
  }

  static int _computeCRC32MainIsolate(Uint8List data) {
    int crc = 0xFFFFFFFF;
    for (int i = 0; i < data.length; i++) {
      crc ^= data[i];
      for (int j = 0; j < 8; j++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ 0xEDB88320;
        } else {
          crc >>= 1;
        }
      }
    }
    return crc ^ 0xFFFFFFFF;
  }

  static Future<int> _computeCRC32(Uint8List data) async {
    return await compute(_computeCRC32MainIsolate, data);
  }

  static Stream<WallpaperSendProgress> sendToWatch(BleService bleService, Uint8List data) async* {
    if (data.length != 134400) {
      yield WallpaperSendProgress(chunksSent: 0, totalChunks: 0, error: "Invalid data size ${data.length}");
      return;
    }

    const int CHUNK_SIZE = 512;
    int totalChunks = (data.length / CHUNK_SIZE).ceil(); // 263
    
    final totalSize = data.length;
    final startCmd = Uint8List(5);
    startCmd[0] = BleConstants.cmdStartWallpaper;
    startCmd[1] = totalSize & 0xFF;
    startCmd[2] = (totalSize >> 8) & 0xFF;
    startCmd[3] = (totalSize >> 16) & 0xFF;
    startCmd[4] = (totalSize >> 24) & 0xFF;

    Stream<List<int>>? controlStream = await bleService.subscribeToCharacteristic(BleConstants.charControlUuid);
    Stream<List<int>>? wallpaperStream = await bleService.subscribeToCharacteristic(BleConstants.charWallpaperUuid);

    if (controlStream == null || wallpaperStream == null) {
      yield WallpaperSendProgress(chunksSent: 0, totalChunks: totalChunks, error: "Failed to subscribe to ACK streams.");
      return;
    }

    Future<bool> waitForAck(Stream<List<int>> stream, int expectedAck, {int timeoutSec = 10}) async {
      try {
        final res = await stream.firstWhere((d) => d.isNotEmpty && (d[0] == expectedAck || d[0] == 0x15 || d[0] == 0x02)).timeout(Duration(seconds: timeoutSec));
        return res[0] == expectedAck;
      } catch (e) {
        return false;
      }
    }

    await bleService.writeCharacteristic(BleConstants.charControlUuid, startCmd);
    bool startAck = await waitForAck(controlStream, 0x01);
    if (!startAck) {
      yield WallpaperSendProgress(chunksSent: 0, totalChunks: totalChunks, error: "Failed to start transfer. No ACK.");
      return;
    }

    for (int i = 0; i < totalChunks; i++) {
        int offset = i * CHUNK_SIZE;
        int len = (offset + CHUNK_SIZE > data.length) ? data.length - offset : CHUNK_SIZE;
        
        final chunkData = data.sublist(offset, offset + len);
        final payload = Uint8List(6 + len);
        
        payload[0] = i & 0xFF;
        payload[1] = (i >> 8) & 0xFF;
        payload[2] = totalChunks & 0xFF;
        payload[3] = (totalChunks >> 8) & 0xFF;
        payload[4] = len & 0xFF;
        payload[5] = (len >> 8) & 0xFF;
        payload.setRange(6, 6 + len, chunkData);

        bool chunkSuccess = false;
        for (int retry = 0; retry < 3; retry++) {
          await bleService.writeCharacteristic(BleConstants.charWallpaperUuid, payload);
          bool ack = await waitForAck(wallpaperStream, 0x06); // 0x06 is ACK
          if (ack) {
            chunkSuccess = true;
            break;
          }
        }

        if (!chunkSuccess) {
          yield WallpaperSendProgress(chunksSent: i, totalChunks: totalChunks, error: "Chunk $i failed after 3 retries.");
          return;
        }
        
        // Report progress every chunk or periodically 
        // Note: yielding on every standard chunk might clutter UI thread slightly but it's 263 updates.
        yield WallpaperSendProgress(chunksSent: i + 1, totalChunks: totalChunks);
    }

    int crc = await _computeCRC32(data);

    final endCmd = Uint8List(5); // CMD_END_WALLPAPER + CRC32
    endCmd[0] = BleConstants.cmdEndWallpaper;
    endCmd[1] = crc & 0xFF;
    endCmd[2] = (crc >> 8) & 0xFF;
    endCmd[3] = (crc >> 16) & 0xFF;
    endCmd[4] = (crc >> 24) & 0xFF;

    await bleService.writeCharacteristic(BleConstants.charControlUuid, endCmd);
    bool endAck = await waitForAck(controlStream, 0x01, timeoutSec: 15);

    if (endAck) {
      yield WallpaperSendProgress(chunksSent: totalChunks, totalChunks: totalChunks, done: true);
    } else {
      yield WallpaperSendProgress(chunksSent: totalChunks, totalChunks: totalChunks, error: "CRC mismatch. Wallpaper transfer failed.");
    }
  }
}

class WallpaperSendProgress {
  final int chunksSent;
  final int totalChunks;
  final bool done;
  final String? error;
  WallpaperSendProgress({required this.chunksSent, required this.totalChunks, this.done = false, this.error});
}
