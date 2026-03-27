import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../core/constants/ble_constants.dart';

class BleService {
  BluetoothDevice? _connectedDevice;
  final StreamController<List<ScanResult>> _scanResultsController = StreamController<List<ScanResult>>.broadcast();

  // APP-001: Scan only from ConnectScreen
  Future<void> startScan() async {
    // Check if Bluetooth is ON first
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      throw Exception("Bluetooth is turned off. Please enable it.");
    }

    // APP-003: 10s timeout
    if (FlutterBluePlus.isScanningNow) return;

    FlutterBluePlus.scanResults.listen((results) {
      // Return all results, no filtering in service anymore
      _scanResultsController.add(results);
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10), // APP-003
    );
  }

  Stream<List<ScanResult>> get scanResults => _scanResultsController.stream;

  Future<void> stopScan() async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      await stopScan();
      
      // APP-003: 10s timeout on connect
      await device.connect(timeout: const Duration(seconds: 10), autoConnect: false);
      _connectedDevice = device;
      await device.discoverServices();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
    }
  }

  // Write Characteristic with UUID
  Future<bool> writeCharacteristic(String uuid, List<int> data) async {
    if (_connectedDevice == null) return false;
    
    final services = _connectedDevice!.servicesList;
    
    for (var service in services) {
      if (service.uuid.toString().toLowerCase() == BleConstants.watchServiceUuid.toLowerCase()) {
        for (var char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() == uuid.toLowerCase()) {
            await char.write(data, withoutResponse: false, timeout: 10); // APP-003
            return true;
          }
        }
      }
    }
    return false;
  }

  Future<bool> sendCommand(int command) async {
    return writeCharacteristic(BleConstants.charControlUuid, [command]);
  }

  // Subscribe to characteristic
  Future<Stream<List<int>>?> subscribeToCharacteristic(String uuid) async {
    if (_connectedDevice == null) return null;
    
    final services = _connectedDevice!.servicesList;
    
    for (var service in services) {
      if (service.uuid.toString().toLowerCase() == BleConstants.watchServiceUuid.toLowerCase()) {
        for (var char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() == uuid.toLowerCase()) {
            if (!char.isNotifying) {
              await char.setNotifyValue(true);
            }
            return char.onValueReceived;
          }
        }
      }
    }
    return null;
  }
}
