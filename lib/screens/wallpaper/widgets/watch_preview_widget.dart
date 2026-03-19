import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class WatchPreviewWidget extends StatelessWidget {
  final Widget? content;

  const WatchPreviewWidget({super.key, this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240 + 20, // 240 plus 10 bezel on each side
      height: 280 + 20, // 280 plus 10 bezel on each side
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.bgElevated, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(128), // withAlpha(128) replaces withOpacity(0.5)
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10), // The physical bezel
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // User Content (Image or Placeholder)
            Container(
              color: AppColors.bgSurface,
              width: 240,
              height: 280,
              child: content ?? 
                const Center(
                  child: Icon(Icons.image, color: AppColors.textHint, size: 48),
                ),
            ),
            
            // Watch Time Overlay
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "10:09",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withAlpha(200),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
