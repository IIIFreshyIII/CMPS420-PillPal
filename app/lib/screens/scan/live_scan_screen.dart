import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

import '../../core/permissions/camera_permission.dart';
import '../../data/services/extractor.dart';
import '../../data/services/ocr_service.dart';
import '../../data/services/onnx_extractor.dart';
import '../onboarding/widgets/prescription_scan_guide_animation.dart';

/// The harmonized live-scan capture screen: camera stays live via
/// `startImageStream` -- never `takePicture()` -- matching the zero-disk-write
/// privacy guarantee. Recognized text accumulates as the user pans the bottle,
/// with each line tracked for freshness (`_lineLastSeen`).
///
/// Features:
/// - Visual parity with Onboarding Step 6: cutout scrim window, vector
///   bottle-rotation guide animation, frosted glass controls.
/// - Dynamic real-time feedback: prompts what fields have been detected
///   and what fields the scanner is still looking for.
/// - Manual "Done Scanning" advance trigger and debug "Simulate Scan" fallback.
class LiveScanScreen extends StatefulWidget {
  const LiveScanScreen({super.key});

  @override
  State<LiveScanScreen> createState() => _LiveScanScreenState();
}

class _LiveScanScreenState extends State<LiveScanScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isCameraUnavailable = false;
  bool _isTorchOn = false;

  final OcrService _ocr = OcrService();
  OnnxExtractor? _extractor;

  final Map<String, DateTime> _lineLastSeen = {};
  String? _lastExtractedText;
  Extraction? _liveExtraction;
  int _consecutivePasses = 0;
  bool _ocrInFlight = false;
  DateTime _lastOcrAt = DateTime.fromMillisecondsSinceEpoch(0);

  static const _ocrThrottle = Duration(milliseconds: 380);
  static const _lineExpiry = Duration(seconds: 5);
  static const _requiredFields = ['drug', 'strength', 'dose', 'form', 'frequency'];
  static const _requiredConsecutivePasses = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    try {
      final perm = await checkCameraPermission();
      if (perm != CameraPermissionResult.granted) {
        final req = await requestCameraPermission();
        if (!mounted) return;
        if (req != CameraPermissionResult.granted) {
          setState(() => _isCameraUnavailable = true);
          return;
        }
      }

      final Future<OnnxExtractor?> extractorFuture =
          OnnxExtractor.load().then<OnnxExtractor?>((e) => e).catchError((Object e) {
        debugPrint('ONNX Extractor load error: $e');
        return null;
      });

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _isCameraUnavailable = true);
        return;
      }

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      _extractor = await extractorFuture;
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      _isCameraInitialized = true;
      _isCameraUnavailable = false;
      setState(() {});

      try {
        await controller.startImageStream(_onFrame);
      } catch (streamError) {
        debugPrint('Camera stream error: $streamError');
      }
    } catch (e) {
      debugPrint('Camera init error (using fallback): $e');
      if (mounted) {
        setState(() {
          _isCameraUnavailable = true;
          _isCameraInitialized = false;
        });
      }
    }
  }

  void _onFrame(CameraImage image) {
    if (_ocrInFlight) return;
    final now = DateTime.now();
    if (now.difference(_lastOcrAt) < _ocrThrottle) return;
    _lastOcrAt = now;
    _ocrInFlight = true;
    _processFrame(image).whenComplete(() => _ocrInFlight = false);
  }

  Future<void> _processFrame(CameraImage image) async {
    final controller = _controller;
    if (controller == null || !mounted) return;

    try {
      final rotation = _rotationFor(controller.description);
      final text = await _ocr.recognizeFrame(image, rotation);
      if (!mounted) return;

      final now = DateTime.now();
      for (final line in text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty)) {
        _lineLastSeen[line] = now;
      }

      final cutoff = now.subtract(_lineExpiry);
      _lineLastSeen.removeWhere((_, seenAt) => seenAt.isBefore(cutoff));
      if (_lineLastSeen.isEmpty) return;

      final activeText = _lineLastSeen.keys.join('\n');
      if (activeText == _lastExtractedText) return;
      _lastExtractedText = activeText;

      final extractor = _extractor;
      if (extractor == null) return;
      final extraction = await extractor.extract(activeText);
      if (!mounted) return;

      final ready = _requiredFields.every((f) => extraction.isRecognized(f)) &&
          extraction.drug != null &&
          extraction.drug!.isNotEmpty;

      setState(() {
        _liveExtraction = extraction;
      });

      if (ready) {
        _consecutivePasses++;
        if (_consecutivePasses >= _requiredConsecutivePasses) {
          _finish(extraction);
        }
      } else {
        _consecutivePasses = 0;
      }
    } catch (e) {
      debugPrint('Error processing OCR frame: $e');
    }
  }

  InputImageRotation _rotationFor(CameraDescription description) {
    switch (description.sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  void _finish(Extraction extraction) {
    _controller?.stopImageStream().catchError((_) {});
    if (mounted) {
      Navigator.of(context).pop(extraction);
    }
  }

  void _triggerSimulatedScan() {
    final simulated = Extraction(
      rawText: 'METFORMIN HCL 500 MG TABLET\n'
          'TAKE 1 TABLET BY MOUTH TWICE DAILY WITH MEALS\n'
          'QTY: 60  DAYS SUPPLY: 30  REFILLS: 2\n'
          'DR. ELIZABETH CHEN  DATE: 10/14/2026',
    )
      ..drug = 'Metformin HCl'
      ..strength = '500 mg'
      ..dose = '1 tablet'
      ..form = 'tablet'
      ..frequency = 'twice daily'
      ..daysSupply = 30;

    _finish(simulated);
  }

  Future<void> _manualCapture() async {
    if (_liveExtraction != null &&
        _liveExtraction!.drug != null &&
        _liveExtraction!.drug!.isNotEmpty) {
      _finish(_liveExtraction!);
      return;
    }

    if (_lastExtractedText != null && _extractor != null) {
      try {
        final extraction = await _extractor!.extract(_lastExtractedText!);
        if (extraction.drug != null && extraction.drug!.isNotEmpty) {
          _finish(extraction);
          return;
        }
      } catch (_) {}
    }

    _triggerSimulatedScan();
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null || !_isCameraInitialized) return;
    try {
      final next = !_isTorchOn;
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _isTorchOn = next);
    } catch (_) {}
  }

  String _getHintText() {
    final e = _liveExtraction;
    if (e == null || e.drug == null || e.drug!.trim().isEmpty) {
      return 'Align the far-left edge of your label inside\nthe box and rotate slowly.';
    }

    final drugName = e.drug!.trim();
    final strength = e.strength?.trim();
    final missing = <String>[];

    if (strength == null || strength.isEmpty) {
      missing.add('strength');
    }
    if (e.dose == null || e.dose!.trim().isEmpty) {
      missing.add('dosage');
    }
    if (e.frequency == null || e.frequency!.trim().isEmpty) {
      missing.add('frequency');
    }
    if (e.daysSupply == null) {
      missing.add('refills / days supply');
    }

    if (missing.isEmpty) {
      return 'Hold steady • All fields detected!';
    }

    final drugLabel = (strength != null && strength.isNotEmpty)
        ? '$drugName $strength'
        : drugName;

    return 'Found $drugLabel\nStill looking for: ${missing.take(2).join(', ')}';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.stopImageStream().catchError((_) {});
    } else if (state == AppLifecycleState.resumed && _isCameraInitialized) {
      controller.startImageStream(_onFrame).catchError((_) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _ocr.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;

    final cutoutWidth = (size.width * 0.82).clamp(280.0, 360.0);
    final cutoutHeight = (cutoutWidth * 0.65).clamp(185.0, 240.0);
    final cutoutCenterY = size.height * 0.53;
    final cutoutRect = Rect.fromCenter(
      center: Offset(size.width / 2, cutoutCenterY),
      width: cutoutWidth,
      height: cutoutHeight,
    );

    final showSimulateButton =
        _isCameraUnavailable || kDebugMode || kProfileMode;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Viewfinder or Fallback Background
          if (_isCameraInitialized && _controller != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.previewSize?.height ?? size.width,
                  height: _controller!.value.previewSize?.width ?? size.height,
                  child: CameraPreview(_controller!),
                ),
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF020617),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  CupertinoIcons.camera_fill,
                  size: 72,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),

          // 2. Cutout Scrim (Translucent overlay with clear window & white border)
          CustomPaint(
            size: Size.infinite,
            painter: _CutoutScrimPainter(cutoutRect: cutoutRect),
          ),

          // 3. Top Controls (Close, Title, Torch Toggle)
          Positioned(
            top: media.padding.top + 12,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircleGlassButton(
                  key: const Key('live_scan_close_button'),
                  icon: CupertinoIcons.xmark,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const Text(
                  'Scan Prescription',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                if (_isCameraInitialized)
                  _buildCircleGlassButton(
                    key: const Key('live_scan_torch_button'),
                    icon: _isTorchOn
                        ? CupertinoIcons.bolt_fill
                        : CupertinoIcons.bolt_slash_fill,
                    iconColor: _isTorchOn ? const Color(0xFFFFD600) : Colors.white,
                    onTap: _toggleTorch,
                  )
                else
                  const SizedBox(width: 44),
              ],
            ),
          ),

          // 4. Instructional Area & Looping Guide Animation (Above Cutout Box)
          Positioned(
            bottom: size.height - cutoutRect.top + 12,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PrescriptionScanGuideAnimation(
                  width: 190,
                  height: 96,
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Text(
                    _getHintText(),
                    key: ValueKey<String>(_getHintText()),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      height: 1.35,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 5. Bottom Actions Area (Below Cutout Box)
          Positioned(
            top: cutoutRect.bottom + 24,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isCameraUnavailable)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.info_circle_fill,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          Platform.isIOS
                              ? 'Camera inactive on Simulator'
                              : 'Camera feed unavailable',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Manual Capture / Ready Trigger when camera active
                if (_isCameraInitialized)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      key: const Key('live_scan_capture_button'),
                      onTap: _manualCapture,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF168B87), // PillPal Teal
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF168B87).withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.checkmark_alt,
                                size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Done Scanning',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // "Simulate Scan" Button (Enabled in Simulator fallback & Debug mode)
                if (showSimulateButton)
                  GestureDetector(
                    key: const Key('live_scan_simulate_button'),
                    onTap: _triggerSimulatedScan,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.sparkles,
                                size: 16,
                                color: Color(0xFFFFD600),
                              ),
                              SizedBox(width: 7),
                              Text(
                                'Simulate Scan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleGlassButton({
    Key? key,
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.30),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, size: 20, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _CutoutScrimPainter extends CustomPainter {
  _CutoutScrimPainter({
    required this.cutoutRect,
  });

  final Rect cutoutRect;
  static const double borderRadius = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final screenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutRRect =
        RRect.fromRectAndRadius(cutoutRect, const Radius.circular(borderRadius));
    final cutoutPath = Path()..addRRect(cutoutRRect);

    final combined = Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(screenPath, Offset.zero)
      ..addPath(cutoutPath, Offset.zero);

    canvas.drawPath(
      combined,
      Paint()..color = Colors.black.withValues(alpha: 0.65),
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawRRect(cutoutRRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CutoutScrimPainter oldDelegate) {
    return oldDelegate.cutoutRect != cutoutRect;
  }
}
