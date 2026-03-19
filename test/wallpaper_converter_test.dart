import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartwatch_companion/core/utils/rgb565_converter.dart';

void main() {
  test('Convert image to rgb565 correctly outputs 134400 bytes', () async {
    final file = File('test_image.jpg');
    expect(file.existsSync(), true, reason: 'Test image must exist');
    
    final request = ConvertRequest(
      imagePath: 'test_image.jpg',
      brightness: 1.0, 
      contrast: 1.0, 
      dither: false
    );
    
    final result = await Rgb565Converter.convertImage(request);
    
    expect(result.rgb565Data.length, 134400, reason: 'RGB565 data should be exactly 240x280x2 = 134400 bytes');
    expect(result.previewPngData.isNotEmpty, true, reason: 'Preview PNG should be generated');
    
    print('SUCCESS! rgb565 length: ${result.rgb565Data.length} bytes');
    print('Preview PNG size: ${result.previewPngData.length} bytes');
  });
}
