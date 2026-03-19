import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../core/utils/rgb565_converter.dart';
import '../services/wallpaper_service.dart';
import '../services/ble_service.dart';

class WallpaperState {
  final File? originalImage;
  final Uint8List? convertedRgb565;
  final Uint8List? previewPng;
  final double brightness;
  final double contrast;
  final bool dither;
  final bool isConverting;
  final String? errorMessage;
  final List<String> presets;
  final WallpaperSendProgress? sendProgress;

  WallpaperState({
    this.originalImage,
    this.convertedRgb565,
    this.previewPng,
    this.brightness = 1.0,
    this.contrast = 1.0,
    this.dither = false,
    this.isConverting = false,
    this.errorMessage,
    this.presets = const [],
    this.sendProgress,
  });

  WallpaperState copyWith({
    File? originalImage,
    Uint8List? convertedRgb565,
    Uint8List? previewPng,
    double? brightness,
    double? contrast,
    bool? dither,
    bool? isConverting,
    String? errorMessage,
    List<String>? presets,
    WallpaperSendProgress? sendProgress,
    bool clearError = false, // helper to clear error
  }) {
    return WallpaperState(
      originalImage: originalImage ?? this.originalImage,
      convertedRgb565: convertedRgb565 ?? this.convertedRgb565,
      previewPng: previewPng ?? this.previewPng,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      dither: dither ?? this.dither,
      isConverting: isConverting ?? this.isConverting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      presets: presets ?? this.presets,
      sendProgress: sendProgress ?? this.sendProgress,
    );
  }
}

class WallpaperNotifier extends StateNotifier<WallpaperState> {
  WallpaperNotifier() : super(WallpaperState()) {
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final presets = await WallpaperService.getSavedPresets();
    state = state.copyWith(presets: presets);
  }

  Future<void> pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result != null && result.files.single.path != null) {
        state = state.copyWith(
          originalImage: File(result.files.single.path!),
          convertedRgb565: null,
          previewPng: null,
          clearError: true,
          sendProgress: null,
        );
      }
    } catch (e) {
      state = state.copyWith(errorMessage: "Failed to pick image: $e");
    }
  }

  void loadPreset(String path) {
    state = state.copyWith(
      originalImage: File(path),
      convertedRgb565: null,
      previewPng: null,
      clearError: true,
      sendProgress: null,
    );
  }

  void updateBrightness(double value) => state = state.copyWith(brightness: value);
  void updateContrast(double value) => state = state.copyWith(contrast: value);
  void updateDither(bool value) => state = state.copyWith(dither: value);

  Future<void> convertImage() async {
    if (state.originalImage == null) return;

    state = state.copyWith(isConverting: true, clearError: true, sendProgress: null);

    try {
      final request = ConvertRequest(
        imagePath: state.originalImage!.path,
        brightness: state.brightness,
        contrast: state.contrast,
        dither: state.dither,
      );

      final result = await Rgb565Converter.convertImage(request);

      await WallpaperService.savePreset(state.originalImage!.path);
      final newPresets = await WallpaperService.getSavedPresets();

      state = state.copyWith(
        isConverting: false,
        convertedRgb565: result.rgb565Data,
        previewPng: result.previewPngData,
        presets: newPresets,
      );
    } catch (e) {
      state = state.copyWith(
        isConverting: false,
        errorMessage: "Conversion failed: $e",
      );
    }
  }

  Future<String?> exportCpp() async {
    if (state.convertedRgb565 == null) return null;
    try {
      final cpp = await WallpaperService.exportCppFile(state.convertedRgb565!);
      final file = await WallpaperService.saveExportToDownloads(cpp);
      return file.path;
    } catch (e) {
      state = state.copyWith(errorMessage: "Export failed: $e");
      return null;
    }
  }

  Future<void> sendToWatch(BleService bleService) async {
    if (state.convertedRgb565 == null) return;
    
    state = state.copyWith(clearError: true);
    
    final stream = WallpaperService.sendToWatch(bleService, state.convertedRgb565!);
    
    await for (final progress in stream) {
      if (!mounted) break;
      state = state.copyWith(sendProgress: progress);
      if (progress.error != null) {
        state = state.copyWith(errorMessage: progress.error);
        break; // Stop listening 
      }
    }
  }
}

final wallpaperProvider = StateNotifierProvider<WallpaperNotifier, WallpaperState>((ref) {
  return WallpaperNotifier();
});
