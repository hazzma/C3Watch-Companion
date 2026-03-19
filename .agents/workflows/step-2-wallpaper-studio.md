---
description: Run the Wallpaper Studio Agent to build the image processing engine, converter, and offline studio UI.
---

1.  Create `lib/utils/rgb565_converter.dart` for RGB565 conversion logic (approx. 131KB binary).
2.  Implement the conversion using a Dart Isolate to prevent UI jank (APP-002).
3.  Develop the "Wallpaper Studio" screen with high-fidelity preview frames.
4.  Add image manipulation sliders for brightness and contrast.
5.  Implement the persistent Wallpaper Presets strip (up to 5 images).
6.  Ensure the "Export as .cpp" feature is functional for firmware development.

// turbo
7. Verify conversion accuracy: Input (PNG/JPG) -> Output (134,400 bytes).
8. Verify preview-to-original similarity using the reversed RGB565->RGB mapping.
9. Verify performance stays smooth during the conversion process.
