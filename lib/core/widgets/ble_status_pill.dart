import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/ble_provider.dart';
import '../constants/app_colors.dart';

class BleStatusPill extends ConsumerWidget {
  const BleStatusPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleConnectionStateProvider);

    Color bgColor;
    Color iconColor;
    String label;
    bool animate = false;

    switch (bleState) {
      case BleConnectionState.connected:
        bgColor = AppColors.accentTeal.withAlpha(51);
        iconColor = AppColors.accentTeal;
        label = 'Connected';
        break;
      case BleConnectionState.scanning:
        bgColor = AppColors.accentAmber.withAlpha(51);
        iconColor = AppColors.accentAmber;
        label = 'Scanning...';
        animate = true;
        break;
      case BleConnectionState.disconnected:
        bgColor = AppColors.accentRed.withAlpha(51);
        iconColor = AppColors.accentRed;
        label = 'Disconnected';
        break;
    }

    Widget pill = Container(
      margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bluetooth, color: iconColor, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: iconColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (animate) {
      return pill.animate(onPlay: (controller) => controller.repeat(reverse: true))
          .fade(duration: 800.ms, begin: 0.5, end: 1.0);
    }

    return pill;
  }
}
