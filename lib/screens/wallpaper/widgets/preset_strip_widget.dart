import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class PresetStripWidget extends StatelessWidget {
  final List<String> presets;
  final Function(String) onPresetTapped;
  final Function(String) onPresetDeleted;

  const PresetStripWidget({
    super.key,
    required this.presets,
    required this.onPresetTapped,
    required this.onPresetDeleted,
  });

  @override
  Widget build(BuildContext context) {
    if (presets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Recent Presets",
              style: TextStyle(
                color: AppColors.textSecond, 
                fontSize: 13, 
                fontWeight: FontWeight.w600
              ),
            ),
            if (presets.length > 3)
              const Text(
                "Scroll right →",
                style: TextStyle(color: AppColors.textHint, fontSize: 10),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: ListView.separated(
            padding: const EdgeInsets.only(right: 20),
            scrollDirection: Axis.horizontal,
            itemCount: presets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final path = presets[index];
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () => onPresetTapped(path),
                    child: Hero(
                      tag: 'preset_$path',
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.bgElevated, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(50),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                          image: DecorationImage(
                            image: FileImage(File(path)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -5,
                    right: -5,
                    child: GestureDetector(
                      onTap: () => onPresetDeleted(path),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(80),
                              blurRadius: 4,
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          color: AppColors.accentRed,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
