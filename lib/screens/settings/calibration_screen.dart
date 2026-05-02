import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/ble_constants.dart';
import '../../providers/ble_provider.dart';

class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  // Form Controllers
  final TextEditingController _thresholdController = TextEditingController(text: '250');
  int _durationSamples = 3;
  bool _axisX = true;
  bool _axisY = true;
  bool _axisZ = true;
  final TextEditingController _screenTimeoutController = TextEditingController(text: '10');

  int _stepCalMode = 0;
  final TextEditingController _strideLengthController = TextEditingController(text: '700');
  final TextEditingController _heightController = TextEditingController(text: '165');
  final TextEditingController _weightController = TextEditingController(text: '60');
  int _stepTuneOption = 1;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _listenToCalibrationNotify();
  }

  void _listenToCalibrationNotify() async {
    final bleService = ref.read(bleServiceProvider);
    if (bleService.connectedDevice != null) {
      final stream = await bleService.subscribeToCharacteristic(BleConstants.charCalibrationUuid);
      stream?.listen((data) {
        if (data.length >= 14 && data[0] == 0x02) {
          _parseCalibrationPacket(data);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Calibration received from watch!'), backgroundColor: AppColors.accentTeal)
            );
          }
        }
      });
    }
  }

  void _parseCalibrationPacket(List<int> data) {
    if (data.length < 14) return;
    
    // Checksum
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      sum += data[i];
    }
    int expectedChecksum = (data[12] | (data[13] << 8));
    if ((sum % 65536) != expectedChecksum) {
      print("Checksum mismatch");
      return;
    }

    setState(() {
      int thresholdRaw = data[1];
      _thresholdController.text = (thresholdRaw * 3.91).round().toString();
      _durationSamples = data[2];
      int axisMask = data[3];
      _axisX = (axisMask & 0x01) != 0;
      _axisY = (axisMask & 0x02) != 0;
      _axisZ = (axisMask & 0x04) != 0;
      _screenTimeoutController.text = data[4].toString();
      
      _stepCalMode = data[5];
      int stride = data[6] | (data[7] << 8);
      _strideLengthController.text = stride.toString();
      _heightController.text = data[8].toString();
      _weightController.text = data[9].toString();
      _stepTuneOption = data[10];
    });
  }

  List<int> _buildCalibrationPacket() {
    List<int> packet = List.filled(14, 0);
    packet[0] = 0x01; // App -> Watch
    
    int mg = int.tryParse(_thresholdController.text) ?? 250;
    packet[1] = (mg / 3.91).round().clamp(0, 255);
    packet[2] = _durationSamples;
    
    int mask = 0;
    if (_axisX) mask |= 0x01;
    if (_axisY) mask |= 0x02;
    if (_axisZ) mask |= 0x04;
    packet[3] = mask;
    
    packet[4] = int.tryParse(_screenTimeoutController.text) ?? 10;
    packet[5] = _stepCalMode;
    
    int stride = int.tryParse(_strideLengthController.text) ?? 700;
    packet[6] = stride & 0xFF;
    packet[7] = (stride >> 8) & 0xFF;
    
    packet[8] = int.tryParse(_heightController.text) ?? 165;
    packet[9] = int.tryParse(_weightController.text) ?? 60;
    packet[10] = _stepTuneOption;
    packet[11] = 0x00; // Reserved
    
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      sum += packet[i];
    }
    packet[12] = sum & 0xFF;
    packet[13] = (sum >> 8) & 0xFF;
    
    return packet;
  }

  Future<void> _sendToWatch() async {
    setState(() => _isLoading = true);
    final bleService = ref.read(bleServiceProvider);
    if (bleService.connectedDevice == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Watch not connected'), backgroundColor: AppColors.accentRed));
      setState(() => _isLoading = false);
      return;
    }
    
    final packet = _buildCalibrationPacket();
    await bleService.sendCommand(BleConstants.cmdSendCalibration);
    await Future.delayed(const Duration(milliseconds: 100)); // wait for device to be ready to receive command 0x0A
    await bleService.writeCharacteristic(BleConstants.charControlUuid, [BleConstants.cmdSendCalibration] + packet);
    
    setState(() => _isLoading = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent calibration'), backgroundColor: AppColors.accentTeal));
  }

  Future<void> _requestFromWatch() async {
    setState(() => _isLoading = true);
    final bleService = ref.read(bleServiceProvider);
    if (bleService.connectedDevice == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Watch not connected'), backgroundColor: AppColors.accentRed));
      setState(() => _isLoading = false);
      return;
    }
    
    await bleService.sendCommand(BleConstants.cmdRequestCalibration);
    setState(() => _isLoading = false);
  }

  Future<void> _resetToFactory() async {
    setState(() => _isLoading = true);
    final bleService = ref.read(bleServiceProvider);
    if (bleService.connectedDevice != null) {
      await bleService.sendCommand(BleConstants.cmdResetCalibration);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Factory Reset command sent'), backgroundColor: AppColors.accentTeal));
    }
    setState(() {
      _isLoading = false;
      _thresholdController.text = '250';
      _durationSamples = 3;
      _axisX = true; _axisY = true; _axisZ = true;
      _screenTimeoutController.text = '10';
      _stepCalMode = 0;
      _strideLengthController.text = '700';
      _heightController.text = '165';
      _weightController.text = '60';
      _stepTuneOption = 1;
    });
  }

  Future<void> _exportJson() async {
    final packet = _buildCalibrationPacket();
    
    final data = {
      "version": 1,
      "device": BleConstants.deviceName,
      "exported_at": DateTime.now().toIso8601String(),
      "wake_gesture": {
        "threshold_mg": int.tryParse(_thresholdController.text) ?? 250,
        "threshold_raw": packet[1],
        "duration_samples": _durationSamples,
        "axis_mask": packet[3],
        "screen_timeout_sec": packet[4]
      },
      "step_counter": {
        "mode": _stepCalMode == 0 ? "default" : _stepCalMode == 1 ? "manual_stride" : "auto",
        "stride_length_mm": packet[6] | (packet[7] << 8),
        "height_cm": packet[8],
        "weight_kg": packet[9],
        "tune_option": _stepTuneOption
      },
      "checksum": packet[12] | (packet[13] << 8)
    };
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/c3watch_calibration_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(path);
      await file.writeAsString(jsonEncode(data));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to: $path'), backgroundColor: AppColors.accentTeal));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export: $e'), backgroundColor: AppColors.accentRed));
    }
  }

  Future<void> _importJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final map = jsonDecode(content);
        
        if (map['version'] == 1 && map['device'] == BleConstants.deviceName) {
          setState(() {
            _thresholdController.text = map['wake_gesture']['threshold_mg'].toString();
            _durationSamples = map['wake_gesture']['duration_samples'];
            int mask = map['wake_gesture']['axis_mask'];
            _axisX = (mask & 0x01) != 0;
            _axisY = (mask & 0x02) != 0;
            _axisZ = (mask & 0x04) != 0;
            _screenTimeoutController.text = map['wake_gesture']['screen_timeout_sec'].toString();
            
            String modeStr = map['step_counter']['mode'];
            _stepCalMode = modeStr == 'default' ? 0 : modeStr == 'manual_stride' ? 1 : 2;
            _strideLengthController.text = map['step_counter']['stride_length_mm'].toString();
            _heightController.text = map['step_counter']['height_cm'].toString();
            _weightController.text = map['step_counter']['weight_kg'].toString();
            _stepTuneOption = map['step_counter']['tune_option'];
          });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import successful'), backgroundColor: AppColors.accentTeal));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid JSON format'), backgroundColor: AppColors.accentRed));
        }
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'), backgroundColor: AppColors.accentRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calibration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Export JSON',
            onPressed: _exportJson,
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Import JSON',
            onPressed: _importJson,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text("WAKE GESTURE", style: TextStyle(color: AppColors.accentPurple, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              _buildCard([
                _buildTextField("Threshold (mg)", _thresholdController),
                const Divider(color: AppColors.bgPrimary, height: 1),
                _buildDropdown("Duration Samples", _durationSamples, [0, 1, 2, 3], (val) => setState(() => _durationSamples = val!)),
                const Divider(color: AppColors.bgPrimary, height: 1),
                _buildTextField("Screen Timeout (s)", _screenTimeoutController),
                const Divider(color: AppColors.bgPrimary, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text("Axis Mask", style: TextStyle(color: Colors.white)),
                      const Spacer(),
                      _buildCheckbox("X", _axisX, (val) => setState(() => _axisX = val!)),
                      _buildCheckbox("Y", _axisY, (val) => setState(() => _axisY = val!)),
                      _buildCheckbox("Z", _axisZ, (val) => setState(() => _axisZ = val!)),
                    ],
                  ),
                ),
              ]),

              const SizedBox(height: 24),
              const Text("STEP COUNTER", style: TextStyle(color: AppColors.accentPurple, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              _buildCard([
                _buildDropdown("Mode", _stepCalMode, [0, 1, 2], (val) => setState(() => _stepCalMode = val!), labels: {0: "Default", 1: "Manual Stride", 2: "Auto (H/W)"}),
                const Divider(color: AppColors.bgPrimary, height: 1),
                if (_stepCalMode == 1) ...[
                  _buildTextField("Stride Length (mm)", _strideLengthController),
                  const Divider(color: AppColors.bgPrimary, height: 1),
                ],
                if (_stepCalMode == 2) ...[
                  _buildTextField("Height (cm)", _heightController),
                  const Divider(color: AppColors.bgPrimary, height: 1),
                  _buildTextField("Weight (kg)", _weightController),
                  const Divider(color: AppColors.bgPrimary, height: 1),
                ],
                _buildDropdown("Tune Option", _stepTuneOption, [1, 2, 3], (val) => setState(() => _stepTuneOption = val!)),
              ]),

              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text('Send to Watch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _sendToWatch,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.download, color: AppColors.accentPurple),
                label: const Text('Request from Watch', style: TextStyle(color: AppColors.accentPurple, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.accentPurple),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _requestFromWatch,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.restore, color: AppColors.accentRed),
                label: const Text('Factory Reset Watch', style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.bold)),
                onPressed: _resetToFactory,
              ),
            ],
          ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16)
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: SizedBox(
        width: 80,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.end,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>(String label, T value, List<T> items, ValueChanged<T?> onChanged, {Map<T, String>? labels}) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: DropdownButton<T>(
        value: value,
        dropdownColor: AppColors.bgElevated,
        underline: const SizedBox(),
        style: const TextStyle(color: AppColors.textSecond),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(labels != null ? labels[e]! : e.toString()))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, ValueChanged<bool?> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecond)),
        Checkbox(
          value: value,
          activeColor: AppColors.accentPurple,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
