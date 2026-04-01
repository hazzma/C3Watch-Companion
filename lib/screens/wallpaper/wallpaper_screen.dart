import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/ble_status_pill.dart';
import '../../providers/wallpaper_provider.dart';
import '../../providers/ble_provider.dart';
import 'widgets/watch_preview_widget.dart';
import 'widgets/preset_strip_widget.dart';

class WallpaperScreen extends ConsumerWidget {
  const WallpaperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wallpaperProvider);
    final notifier = ref.read(wallpaperProvider.notifier);
    final isConnected = ref.watch(bleConnectionStateProvider) == BleConnectionState.connected;

    // Show error if any
    ref.listen(wallpaperProvider, (previous, next) {
      if (next.errorMessage != null && previous?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.accentRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      if (next.sendProgress != null && next.sendProgress!.done && previous?.sendProgress?.done != true) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Wallpaper successfully sent!"),
            backgroundColor: AppColors.accentTeal,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallpaper Studio'),
        actions: const [BleStatusPill()],
      ),
      body: Column(
        children: [
          // 1. Preview Area (~55%)
          Expanded(
            flex: 55,
            child: Container(
              width: double.infinity,
              color: AppColors.bgPrimary,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  WatchPreviewWidget(
                    content: _buildPreviewContent(state),
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Builder(
                      builder: (context) => IconButton.filled(
                        onPressed: notifier.pickImage,
                        icon: const Icon(Icons.add_photo_alternate),
                        style: IconButton.styleFrom(backgroundColor: AppColors.accentPurple),
                        tooltip: "Pick Image",
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Controls Area (~45%)
          Expanded(
            flex: 45,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              decoration: const BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSlider(
                      label: "Brightness",
                      value: state.brightness,
                      onChanged: notifier.updateBrightness,
                    ),
                    _buildSlider(
                      label: "Contrast",
                      value: state.contrast,
                      onChanged: notifier.updateContrast,
                    ),
                    SwitchListTile(
                      title: const Text("Dithering", style: TextStyle(color: AppColors.textPrimary)),
                      subtitle: const Text("Better gradients for 16-bit color", style: TextStyle(color: AppColors.textSecond, fontSize: 12)),
                      value: state.dither,
                      activeTrackColor: AppColors.accentPurple,
                      contentPadding: EdgeInsets.zero,
                      onChanged: notifier.updateDither,
                    ),
                    
                    const SizedBox(height: 12),
                    if (state.presets.isNotEmpty) ...[
                      PresetStripWidget(
                        presets: state.presets,
                        onPresetTapped: notifier.loadPreset,
                        onPresetDeleted: notifier.deletePreset,
                      ),
                      const SizedBox(height: 20),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (state.originalImage == null || state.isConverting)
                              ? null 
                              : notifier.convertImage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: state.isConverting 
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text("Convert & Preview"),
                          ),
                        ),
                      ],
                    ),
                    
                    if (state.convertedRgb565 != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final path = await notifier.exportCpp();
                                if (path != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Exported to: \n$path'), backgroundColor: AppColors.accentTeal),
                                  );
                                }
                              },
                              icon: const Icon(Icons.code),
                              label: const Text("Export .cpp"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accentTeal,
                                side: const BorderSide(color: AppColors.accentTeal),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (!isConnected || (state.sendProgress != null && !state.sendProgress!.done && state.sendProgress!.error == null))
                                ? null 
                                : () => notifier.sendToWatch(ref.read(bleServiceProvider)),
                              icon: const Icon(Icons.watch),
                              label: const Text("Send to Watch"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accentTeal,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppColors.bgElevated,
                                disabledForegroundColor: AppColors.textHint,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      if (state.sendProgress != null && !state.sendProgress!.done && state.sendProgress!.error == null) ...[
                         Text("Sending chunk ${state.sendProgress!.chunksSent}/${state.sendProgress!.totalChunks}...", style: const TextStyle(color: AppColors.accentTeal, fontSize: 12)),
                         const SizedBox(height: 4),
                         LinearProgressIndicator(
                           value: state.sendProgress!.chunksSent / state.sendProgress!.totalChunks,
                           backgroundColor: AppColors.bgPrimary,
                           color: AppColors.accentTeal,
                         ),
                      ] else ...[
                        const Center(
                           child: Text(
                             "Ready: ~131 KB (240x280 RGB565)",
                             style: TextStyle(color: AppColors.textSecond, fontSize: 12),
                           ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 20), // Bottom padding
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(WallpaperState state) {
    if (state.previewPng != null) {
      return Image.memory(
        state.previewPng!,
        width: 240,
        height: 280,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    } else if (state.originalImage != null) {
      return Image.file(
        state.originalImage!,
        width: 240,
        height: 280,
        fit: BoxFit.cover,
      );
    }
    return const Center(child: Icon(Icons.image, color: AppColors.textHint, size: 48));
  }

  Widget _buildSlider({required String label, required double value, required Function(double) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecond, fontSize: 13)),
            Text(value.toStringAsFixed(2), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: 0.5,
          max: 1.5,
          activeColor: AppColors.accentPurple,
          inactiveColor: AppColors.bgElevated,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
