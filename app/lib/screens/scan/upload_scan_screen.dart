import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../data/services/extractor.dart';
import '../../data/services/ocr_service.dart';
import '../../data/services/onnx_extractor.dart';
import '../../data/services/zero_disk_photo_picker.dart';
import '../../presentation/widgets/platform_controls.dart';

/// Launches the zero-disk photo picker in-place, then runs OCR + NER extraction.
///
/// Calls [onProcessingChanged] with `true` while OCR/NER is running and `false`
/// when finished or before prompting. Returns an [Extraction] on success (or
/// `Extraction(rawText: '')` if the user chooses manual entry after an
/// unreadable photo), or `null` if the user cancels.
Future<Extraction?> pickAndExtractFromPhoto(
  BuildContext context, {
  ValueChanged<bool>? onProcessingChanged,
}) async {
  while (context.mounted) {
    final bytes = await ZeroDiskPhotoPicker.pickImage();
    if (!context.mounted || bytes == null) return null;

    onProcessingChanged?.call(true);
    final ocr = OcrService();
    OnnxExtractor? extractor;
    try {
      final text = await ocr.recognizeBytes(bytes);
      if (text.trim().isEmpty) {
        onProcessingChanged?.call(false);
        if (!context.mounted) return null;
        final shouldRetry = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text("Couldn't Read Label"),
            content: const Text(
              "We couldn't detect prescription text on this photo. Please make sure the label is clear and well-lit.",
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Enter Manually'),
                onPressed: () => Navigator.pop(ctx, false),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('Try Another Photo'),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        );
        if (shouldRetry == true) continue;
        if (shouldRetry == false) return Extraction(rawText: '');
        return null;
      }

      extractor = await OnnxExtractor.load();
      final extraction = await extractor.extract(text);
      onProcessingChanged?.call(false);
      return extraction;
    } finally {
      onProcessingChanged?.call(false);
      await extractor?.dispose();
      await ocr.close();
    }
  }
  return null;
}

/// Full-screen translucent overlay shown while OCR + NER processes a picked
/// photo in place without pushing an intermediate route.
class ReadingLabelOverlay extends StatelessWidget {
  const ReadingLabelOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Positioned.fill(
      child: ColoredBox(
        color: c.background.withValues(alpha: 0.85),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlatformLoadingIndicator(size: 26, color: c.teal),
              const SizedBox(height: 16),
              Text(
                'Reading the label...',
                style: TextStyle(
                  color: c.inkMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Backup capture path for when the user doesn't have the bottle in hand:
/// pick an existing photo, OCR it once, extract once, done. Same
/// process-and-discard privacy guarantee as the live scan -- the picked
/// image's bytes are read straight into memory by a custom platform channel
/// (see `zero_disk_photo_picker.dart`) and never written to disk.
///
/// Pops with the confirmed [Extraction] on success, or `null` if the user cancels.
class UploadScanScreen extends StatefulWidget {
  const UploadScanScreen({super.key});

  @override
  State<UploadScanScreen> createState() => _UploadScanScreenState();
}

enum _UploadStatus { pickingPhoto, processing, error }

class _UploadScanScreenState extends State<UploadScanScreen> {
  _UploadStatus _status = _UploadStatus.pickingPhoto;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final extraction = await pickAndExtractFromPhoto(
        context,
        onProcessingChanged: (processing) {
          if (mounted) {
            setState(() {
              _status = processing
                  ? _UploadStatus.processing
                  : _UploadStatus.pickingPhoto;
            });
          }
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(extraction);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _UploadStatus.error;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Enter from a Photo')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (_status) {
            _UploadStatus.pickingPhoto => const SizedBox.shrink(),
            _UploadStatus.processing => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlatformLoadingIndicator(size: 26, color: c.teal),
                  const SizedBox(height: 16),
                  Text('Reading the label...',
                      style: TextStyle(color: c.inkMuted)),
                ],
              ),
            _UploadStatus.error => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: c.alert, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage ?? 'Something went wrong.',
                    style: TextStyle(color: c.ink),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back'),
                  ),
                ],
              ),
          },
        ),
      ),
    );
  }
}
