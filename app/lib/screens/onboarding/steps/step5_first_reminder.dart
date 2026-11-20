import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/pillpal_colors.dart';
import '../../../presentation/widgets/pressable.dart';

/// Step 6 (formerly Step 5): First Medication Setup Prompt.
/// Offers full parity with the Schedule header's popover menu:
/// - Scan Bottle (Live OCR camera stream)
/// - Import from Photos (Zero-disk photo picker)
/// - Enter Manually (Direct form entry)
/// - Bottom capsule button to skip straight to the Schedule screen.
class Step5FirstReminder extends StatelessWidget {
  const Step5FirstReminder({
    super.key,
    required this.onStartScan,
    required this.onSkipToSchedule,
    this.onUploadPhoto,
    this.onManualEntry,
  });

  /// Triggers the full-screen camera scanner.
  final VoidCallback onStartScan;

  /// Launches the photo picker for label OCR.
  final VoidCallback? onUploadPhoto;

  /// Opens the manual medication entry form.
  final VoidCallback? onManualEntry;

  /// Proceeds straight to the Schedule screen without logging a first med.
  final VoidCallback onSkipToSchedule;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // Hero Icon Container
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: c.tint,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: c.teal.withValues(alpha: 0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          CupertinoIcons.checkmark_seal_fill,
                          size: 46,
                          color: c.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Title
                    Text(
                      "Now, let's add your first medication!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                        letterSpacing: -0.6,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subtitle
                    Text(
                      'Scan your prescription bottle label, upload a photo, or enter the details manually.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.inkMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Option 1: Primary Scan Bottle Button
                    Pressable(
                      onTap: onStartScan,
                      scale: 0.97,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: c.teal,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: c.teal.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.camera_fill,
                              color: c.onTeal,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Scan Prescription Label',
                              style: TextStyle(
                                color: c.onTeal,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Option 2 & 3: Secondary Options Row
                    Row(
                      children: [
                        // Import from Photos
                        Expanded(
                          child: Pressable(
                            onTap: onUploadPhoto ?? onStartScan,
                            scale: 0.97,
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: c.borderLight),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.cardShadow,
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.photo_on_rectangle,
                                    color: c.tealDeep,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'From Photos',
                                    style: TextStyle(
                                      color: c.ink,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Enter Manually
                        Expanded(
                          child: Pressable(
                            onTap: onManualEntry ?? onStartScan,
                            scale: 0.97,
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: c.borderLight),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.cardShadow,
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.square_pencil,
                                    color: c.tealDeep,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Enter Manually',
                                    style: TextStyle(
                                      color: c.ink,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(flex: 3),
                  ],
                ),
              ),

              // Bottom Capsule Action: "Or go directly to Schedule"
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Pressable(
                  onTap: onSkipToSchedule,
                  scale: 0.97,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: c.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: c.borderLight.withValues(alpha: 0.8),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: c.liftShadow.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Or go directly to Schedule',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
