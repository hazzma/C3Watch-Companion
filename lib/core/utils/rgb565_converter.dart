import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ConvertRequest {
  final String imagePath;
  final double brightness;
  final double contrast;
  final bool dither;

  ConvertRequest({
    required this.imagePath,
    required this.brightness,
    required this.contrast,
    required this.dither,
  });
}

class ConvertResult {
  final Uint8List rgb565Data;
  final Uint8List previewPngData;

  ConvertResult(this.rgb565Data, this.previewPngData);
}

class Rgb565Converter {
  static Future<ConvertResult> convertImage(ConvertRequest request) async {
    // APP-002: Conversion isolated from main thread
    return await compute(_processImage, request);
  }

  static Future<ConvertResult> _processImage(ConvertRequest request) async {
    final file = File(request.imagePath);
    final bytes = await file.readAsBytes();
    
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception("Could not decode image");

    // 1. Resize/Crop to 240x280
    int srcWidth = image.width;
    int srcHeight = image.height;
    
    double targetRatio = 240 / 280;
    double srcRatio = srcWidth / srcHeight;
    
    int cropWidth = srcWidth;
    int cropHeight = srcHeight;
    
    if (srcRatio > targetRatio) {
      cropWidth = (srcHeight * targetRatio).round();
    } else {
      cropHeight = (srcWidth / targetRatio).round();
    }
    
    int cropX = (srcWidth - cropWidth) ~/ 2;
    int cropY = (srcHeight - cropHeight) ~/ 2;
    
    image = img.copyCrop(image, x: cropX, y: cropY, width: cropWidth, height: cropHeight);
    image = img.copyResize(image, width: 240, height: 280, interpolation: img.Interpolation.cubic);

    final targetWidth = 240;
    final targetHeight = 280;
    final rgb565Data = Uint8List(targetWidth * targetHeight * 2);
    final previewImage = img.Image(width: targetWidth, height: targetHeight);

    // Floyd-Steinberg Error Buffers (simplified for RGB)
    List<List<double>> errR = List.generate(targetHeight + 1, (_) => List.filled(targetWidth + 1, 0.0));
    List<List<double>> errG = List.generate(targetHeight + 1, (_) => List.filled(targetWidth + 1, 0.0));
    List<List<double>> errB = List.generate(targetHeight + 1, (_) => List.filled(targetWidth + 1, 0.0));

    int offset = 0;
    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        final pixel = image.getPixel(x, y);
        
        num rNum = pixel.r;
        num gNum = pixel.g;
        num bNum = pixel.b;

        // Apply brightness and contrast
        rNum = ((rNum - 128) * request.contrast + 128) * request.brightness;
        gNum = ((gNum - 128) * request.contrast + 128) * request.brightness;
        bNum = ((bNum - 128) * request.contrast + 128) * request.brightness;

        // Apply Dither error
        if (request.dither) {
          rNum += errR[y][x];
          gNum += errG[y][x];
          bNum += errB[y][x];
        }

        int r = rNum.clamp(0, 255).toInt();
        int g = gNum.clamp(0, 255).toInt();
        int b = bNum.clamp(0, 255).toInt();

        // Convert to RGB565
        final r5 = (r >> 3) & 0x1F;
        final g6 = (g >> 2) & 0x3F;
        final b5 = (b >> 3) & 0x1F;
        final rgb565 = (r5 << 11) | (g6 << 5) | b5;

        // Little-endian
        rgb565Data[offset++] = rgb565 & 0xFF;
        rgb565Data[offset++] = (rgb565 >> 8) & 0xFF;

        // Decode back to RGB for preview exact match
        final previewR = ((rgb565 >> 11) & 0x1F) * 255 ~/ 31;
        final previewG = ((rgb565 >> 5) & 0x3F) * 255 ~/ 63;
        final previewB = (rgb565 & 0x1F) * 255 ~/ 31;

        if (request.dither) {
          double quantErrorR = r - previewR.toDouble();
          double quantErrorG = g - previewG.toDouble();
          double quantErrorB = b - previewB.toDouble();

          if (x + 1 < targetWidth) {
            errR[y][x + 1] += quantErrorR * 7 / 16;
            errG[y][x + 1] += quantErrorG * 7 / 16;
            errB[y][x + 1] += quantErrorB * 7 / 16;
          }
          if (y + 1 < targetHeight) {
            if (x - 1 >= 0) {
              errR[y + 1][x - 1] += quantErrorR * 3 / 16;
              errG[y + 1][x - 1] += quantErrorG * 3 / 16;
              errB[y + 1][x - 1] += quantErrorB * 3 / 16;
            }
            errR[y + 1][x] += quantErrorR * 5 / 16;
            errG[y + 1][x] += quantErrorG * 5 / 16;
            errB[y + 1][x] += quantErrorB * 5 / 16;
            if (x + 1 < targetWidth) {
              errR[y + 1][x + 1] += quantErrorR * 1 / 16;
              errG[y + 1][x + 1] += quantErrorG * 1 / 16;
              errB[y + 1][x + 1] += quantErrorB * 1 / 16;
            }
          }
        }

        previewImage.setPixelRgb(x, y, previewR, previewG, previewB);
      }
    }

    final previewPng = Uint8List.fromList(img.encodePng(previewImage));
    return ConvertResult(rgb565Data, previewPng);
  }
}
