import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../data/services/extractor.dart';
import '../../data/services/ocr_service.dart';
import '../../data/services/onnx_extractor.dart';
import '../../data/services/zero_disk_photo_picker.dart';

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
    final bytes = await ZeroDiskPhotoPicker.pickImage();
    if (!mounted) return;
    if (bytes == null) {
      Navigator.of(context).pop(); // user cancelled picker
      return;
    }

    setState(() => _status = _UploadStatus.processing);

    final ocr = OcrService();
    try {
      final text = await ocr.recognizeBytes(bytes);
      if (text.trim().isEmpty) {
        if (!mounted) return;
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

        if (!mounted) return;
        if (shouldRetry == true) {
          _run();
          return;
        } else if (shouldRetry == false) {
          // Empty extraction signals manual entry mode
          Navigator.of(context).pop(Extraction(rawText: ''));
          return;
        } else {
          Navigator.of(context).pop();
          return;
        }
      }

      final extractor = await OnnxExtractor.load();
      final extraction = await extractor.extract(text);
      if (!mounted) return;
      Navigator.of(context).pop(extraction);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _UploadStatus.error;
        _errorMessage = e.toString();
      });
    } finally {
      await ocr.close();
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
                  CircularProgressIndicator(color: c.teal),
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
