import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class _YuvConversionData {
  _YuvConversionData({
    required this.width,
    required this.height,
    required this.yPlaneBytes,
    required this.yBytesPerRow,
    required this.uPlaneBytes,
    required this.uBytesPerRow,
    required this.uBytesPerPixel,
    required this.vPlaneBytes,
    required this.vBytesPerRow,
    required this.vBytesPerPixel,
  });
  final int width;
  final int height;
  final Uint8List yPlaneBytes;
  final int yBytesPerRow;
  final Uint8List uPlaneBytes;
  final int uBytesPerRow;
  final int uBytesPerPixel;
  final Uint8List vPlaneBytes;
  final int vBytesPerRow;
  final int vBytesPerPixel;
}

/// Wraps `google_mlkit_text_recognition` (on-device OCR) behind the two
/// shapes the app actually needs input in -- a live camera frame, and an
/// in-memory decoded image. Neither entry point ever writes anything to
/// disk; that guarantee lives here, not just in the screens that call it.
class OcrService {
  OcrService() : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  /// Live-scan entry point: one frame straight from `CameraController`'s
  /// `startImageStream`, never `takePicture()` -- the frame exists only in
  /// memory for the duration of this call. Android-only (YUV_420_888,
  /// matching this project's Android-first target); [rotation] is the
  /// caller's job to compute from the camera's sensor orientation and the
  /// device's current orientation, since that's screen/controller state,
  /// not something an OCR wrapper should own.
  Future<String> recognizeFrame(CameraImage image, InputImageRotation rotation) async {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final data = _YuvConversionData(
      width: image.width,
      height: image.height,
      yPlaneBytes: yPlane.bytes,
      yBytesPerRow: yPlane.bytesPerRow,
      uPlaneBytes: uPlane.bytes,
      uBytesPerRow: uPlane.bytesPerRow,
      uBytesPerPixel: uPlane.bytesPerPixel ?? 2,
      vPlaneBytes: vPlane.bytes,
      vBytesPerRow: vPlane.bytesPerRow,
      vBytesPerPixel: vPlane.bytesPerPixel ?? 2,
    );

    // Offload heavy byte-packing to a background thread to prevent UI jank.
    final bytes = await compute(_yuv420ToNv21Isolate, data);

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: ui.Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width, // tightly packed after the conversion below
      ),
    );

    final result = await _recognizer.processImage(inputImage);
    return result.text;
  }

  /// Real Android hardware (confirmed on a Galaxy S25 Ultra) pads each row
  /// of a YUV_420_888 camera frame to a hardware-aligned stride that's wider
  /// than the actual image width, and the U/V planes are typically
  /// interleaved with a pixel stride of 2. Naively concatenating the raw
  /// plane bytes (which works by coincidence on some emulators, where
  /// stride == width) produces a buffer of the wrong size on real devices --
  /// ML Kit's `InputImage.fromByteArray` then throws `IllegalArgumentException`
  /// on every single frame, which is exactly what was happening here. This
  /// strips the row padding and re-packs everything into a standard,
  /// tightly-packed NV21 buffer (Y plane, then interleaved V/U) that ML Kit
  /// can rely on having no hidden padding.
  static Uint8List _yuv420ToNv21Isolate(_YuvConversionData data) {
    final width = data.width;
    final height = data.height;
    final ySize = width * height;
    final uvSize = width * height ~/ 2;
    final nv21 = Uint8List(ySize + uvSize);

    final yPlaneBytes = data.yPlaneBytes;
    var offset = 0;
    for (var row = 0; row < height; row++) {
      final rowStart = row * data.yBytesPerRow;
      nv21.setRange(offset, offset + width, yPlaneBytes, rowStart);
      offset += width;
    }

    final uPlaneBytes = data.uPlaneBytes;
    final vPlaneBytes = data.vPlaneBytes;
    final uPixelStride = data.uBytesPerPixel;
    final vPixelStride = data.vBytesPerPixel;
    final chromaWidth = width ~/ 2;
    final chromaHeight = height ~/ 2;

    var uvIndex = ySize;
    for (var row = 0; row < chromaHeight; row++) {
      final uRowStart = row * data.uBytesPerRow;
      final vRowStart = row * data.vBytesPerRow;
      for (var col = 0; col < chromaWidth; col++) {
        nv21[uvIndex++] = vPlaneBytes[vRowStart + col * vPixelStride];
        nv21[uvIndex++] = uPlaneBytes[uRowStart + col * uPixelStride];
      }
    }

    return nv21;
  }

  /// Decodes already-in-memory encoded image bytes (JPEG/PNG/etc, e.g. from
  /// the zero-disk-write upload-fallback platform channel) and runs OCR on
  /// the raw bitmap -- `InputImage.fromBytes` needs raw pixel data, not a
  /// compressed image, so decoding happens here rather than asking every
  /// caller to do it themselves.
  Future<String> recognizeBytes(Uint8List encodedBytes) async {
    final codec = await ui.instantiateImageCodec(encodedBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return '';

    final inputImage = InputImage.fromBitmap(
      bitmap: byteData.buffer.asUint8List(),
      width: image.width,
      height: image.height,
    );
    final result = await _recognizer.processImage(inputImage);
    return result.text;
  }

  /// File-path entry point -- kept for completeness/testing against a real
  /// file on disk; the app's own upload-fallback path uses [recognizeBytes]
  /// instead, specifically to avoid ever touching disk.
  Future<String> recognizeFile(String path) async {
    final result = await _recognizer.processImage(InputImage.fromFilePath(path));
    return result.text;
  }

  Future<void> close() => _recognizer.close();
}
