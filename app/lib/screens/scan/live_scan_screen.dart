import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

import '../../core/permissions/camera_permission.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/extractor.dart';
import '../../data/services/ocr_service.dart';
import '../../data/services/onnx_extractor.dart';

/// The live-scan capture screen (med-tracker-spec.md §1): the camera stays
/// live via `startImageStream` -- never `takePicture()` -- so no photo is
/// ever taken or saved; frames exist only in memory for the instant each one
/// is OCR'd. Recognized text accumulates as the user pans the bottle, with
/// each line's freshness tracked (`_lineLastSeen`) so anything not re-read
/// within `_lineExpiry` ages out on its own -- a stray misread self-heals
/// without the user needing to do anything, while text that's actually part
/// of the label stays in the buffer as long as the camera keeps re-reading
/// it. The extractor re-runs on the current buffer until enough fields are
/// confidently recognized to auto-advance, or the user taps Done.
///
/// Pops with the confirmed [Extraction] when the user is done, or `null` if
/// they back out.
class LiveScanScreen extends StatefulWidget {
  const LiveScanScreen({super.key});

  @override
  State<LiveScanScreen> createState() => _LiveScanScreenState();
}

enum _ScanStatus { requestingPermission, permissionDenied, initializing, scanning, error }

/// Fields that matter enough to auto-advance on -- the three things a user
/// most needs to use a medication safely. The rest (dose/form/route/
/// duration/dates) are nice-to-have and user-completable on Confirm.
const _requiredFields = ['drug', 'strength', 'frequency'];

/// How many consecutive OCR passes all three required fields must stay
/// recognized for before auto-advancing -- guards against a one-frame fluke.
const _requiredConsecutivePasses = 3;

const _ocrThrottle = Duration(milliseconds: 400);

/// How long a line stays in the extraction buffer without being re-read.
/// Real label text keeps getting re-confirmed every OCR pass as long as the
/// camera is roughly still over it, so it never gets close to this age. A
/// stray one-off capture (a laptop screen glimpsed while moving the phone
/// into position) ages out on its own well within this window -- no manual
/// "clear" needed for the common case.
const _lineExpiry = Duration(seconds: 5);

class _LiveScanScreenState extends State<LiveScanScreen> with WidgetsBindingObserver {
  _ScanStatus _status = _ScanStatus.requestingPermission;
  String? _errorMessage;

  CameraController? _controller;
  final OcrService _ocr = OcrService();
  OnnxExtractor? _extractor;

  final Map<String, DateTime> _lineLastSeen = {};
  String? _lastExtractedText;
  Extraction? _liveExtraction;
  int _consecutivePasses = 0;
  bool _ocrInFlight = false;
  DateTime _lastOcrAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    final permission = await requestCameraPermission();
    if (!mounted) return;
    if (permission != CameraPermissionResult.granted) {
      setState(() => _status = _ScanStatus.permissionDenied);
      return;
    }

    setState(() => _status = _ScanStatus.initializing);
    try {
      final extractorFuture = OnnxExtractor.load();

      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();

      _extractor = await extractorFuture;
      if (!mounted) return;

      _controller = controller;
      await controller.startImageStream(_onFrame);
      setState(() => _status = _ScanStatus.scanning);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _ScanStatus.error;
        _errorMessage = e.toString();
      });
    }
  }

  void _onFrame(CameraImage image) {
    if (_ocrInFlight) return; // backpressure: never queue, just skip
    final now = DateTime.now();
    if (now.difference(_lastOcrAt) < _ocrThrottle) return;
    _lastOcrAt = now;
    _ocrInFlight = true;
    _processFrame(image).whenComplete(() => _ocrInFlight = false);
  }

  Future<void> _processFrame(CameraImage image) async {
    final controller = _controller;
    if (controller == null) return;

    final rotation = _rotationFor(controller.description);
    final text = await _ocr.recognizeFrame(image, rotation);
    if (!mounted) return;

    final now = DateTime.now();
    for (final line in text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty)) {
      _lineLastSeen[line] = now;
    }

    // Age out anything not re-read recently -- this is what lets a stray,
    // one-off misread (a laptop screen glimpsed while moving into position)
    // heal itself without the user doing anything. Real label text keeps
    // getting re-confirmed every pass as long as the camera is roughly over
    // it, so it never approaches this age.
    final cutoff = now.subtract(_lineExpiry);
    _lineLastSeen.removeWhere((_, seenAt) => seenAt.isBefore(cutoff));
    if (_lineLastSeen.isEmpty) return;

    final activeText = _lineLastSeen.keys.join('\n');
    if (activeText == _lastExtractedText) return; // buffer unchanged, skip re-running the model
    _lastExtractedText = activeText;

    final extractor = _extractor;
    if (extractor == null) return;
    final extraction = await extractor.extract(activeText);
    if (!mounted) return;

    final ready = _requiredFields.every((f) => extraction.isRecognized(f) && _fieldValue(extraction, f) != null);
    setState(() {
      _liveExtraction = extraction;
      _consecutivePasses = ready ? _consecutivePasses + 1 : 0;
    });

    if (_consecutivePasses >= _requiredConsecutivePasses) {
      _finish();
    }
  }

  String? _fieldValue(Extraction e, String field) {
    switch (field) {
      case 'drug':
        return e.drug;
      case 'strength':
        return e.strength;
      case 'frequency':
        return e.frequency;
      default:
        return null;
    }
  }

  InputImageRotation _rotationFor(CameraDescription description) {
    // Portrait-locked assumption (matches this app's scan UI convention).
    // A landscape mode would need to also account for the device's current
    // orientation, not just the sensor's fixed mount angle.
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

  void _finish() {
    if (_liveExtraction == null) return;
    Navigator.of(context).pop(_liveExtraction);
  }

  /// Manual escape hatch, kept as a backup alongside the automatic expiry
  /// above (`_lineExpiry`) -- lets the user wipe the buffer immediately
  /// rather than waiting out the few seconds it takes to self-heal.
  void _clearBuffer() {
    setState(() {
      _lineLastSeen.clear();
      _lastExtractedText = null;
      _liveExtraction = null;
      _consecutivePasses = 0;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.stopImageStream();
    } else if (state == AppLifecycleState.resumed && _status == _ScanStatus.scanning) {
      controller.startImageStream(_onFrame);
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Label'),
      ),
      body: switch (_status) {
        _ScanStatus.requestingPermission || _ScanStatus.initializing => _CenteredMessage(
            child: const CircularProgressIndicator(color: Colors.white),
          ),
        _ScanStatus.permissionDenied => _PermissionDeniedView(onOpenSettings: openCameraPermissionSettings),
        _ScanStatus.error => _CenteredMessage(
            child: Text(
              "Couldn't start the camera.\n${_errorMessage ?? ''}",
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        _ScanStatus.scanning => _ScanningView(
            controller: _controller!,
            extraction: _liveExtraction,
            onDone: _liveExtraction == null ? null : _finish,
            onClear: _lineLastSeen.isEmpty ? null : _clearBuffer,
          ),
      },
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: child));
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({required this.onOpenSettings});
  final Future<bool> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 48),
          const SizedBox(height: 16),
          const Text(
            "PillPal needs camera access to scan a label.",
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onOpenSettings, child: const Text('Open Settings')),
        ],
      ),
    );
  }
}

class _ScanningView extends StatelessWidget {
  const _ScanningView({
    required this.controller,
    required this.extraction,
    required this.onDone,
    required this.onClear,
  });

  final CameraController controller;
  final Extraction? extraction;
  final VoidCallback? onDone;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            // Edge-to-edge (main.dart) means the gesture bar no longer
            // reserves its own space, so its height is added on top of the
            // usual bottom padding here too.
            padding: EdgeInsets.fromLTRB(16, 24, 16, 32 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (extraction == null)
                  const Text(
                    'Pan the camera slowly over the label',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (extraction!.drug != null) _FieldChip('Drug', extraction!.drug!),
                      if (extraction!.strength != null) _FieldChip('Strength', extraction!.strength!),
                      if (extraction!.dose != null) _FieldChip('Dose', extraction!.dose!),
                      if (extraction!.frequency != null) _FieldChip('Frequency', extraction!.frequency!),
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (onClear != null)
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          onPressed: onClear,
                          child: const Text('Clear & Rescan'),
                        ),
                      ),
                    if (onClear != null) const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.interactiveTeal),
                        onPressed: onDone,
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldChip extends StatelessWidget {
  const _FieldChip(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: Colors.white,
      label: Text('$label: $value', style: const TextStyle(fontSize: 12)),
    );
  }
}
