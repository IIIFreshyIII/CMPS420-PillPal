import 'package:flutter/material.dart';

import '../services/extractor.dart';
import 'confirm_screen.dart';

/// STUB capture screen.
///
/// Real version: a live camera preview with a guided rectangular frame (spec —
/// helps the user line the label up), a shutter button, then on-device OCR
/// (ML Kit) turns the photo into text and hands it to the [Extractor]. If the
/// user doesn't confirm, the photo auto-deletes after a short idle period.
///
/// For now a button fakes the capture so the rest of the flow is testable.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final Extractor _extractor = StubExtractor();
  bool _busy = false;

  static const _fakeOcrText =
      'GOODHEALTH PHARMACY   (555) 123-4567\n'
      'Rx 4820193      Date filled: 08/01/2026\n'
      'METFORMIN HCL 500 MG TABLET\n'
      'Take 1 tablet by mouth twice daily with meals.\n'
      'Qty: 60      Days supply: 30';

  Future<void> _simulateCapture() async {
    setState(() => _busy = true);
    final extraction = await _extractor.extract(_fakeOcrText);
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ConfirmScreen(extraction: extraction),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add from label')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Camera preview + guided frame\n(not wired up yet)',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _simulateCapture,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_busy ? 'Reading label…' : 'Simulate capture'),
            ),
          ],
        ),
      ),
    );
  }
}
