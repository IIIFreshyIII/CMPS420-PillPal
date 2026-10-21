import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/pillpal_colors.dart';
import '../../../presentation/widgets/scan_bottle_button.dart';

/// Step 5: First Reminder Setup Prompt.
/// Displays "Thanks! Now, let's set up your first reminder!" and directly below
/// renders the exact ScanBottleButton component from the Schedule header.
class Step5FirstReminder extends StatelessWidget {
  const Step5FirstReminder({
    super.key,
    required this.onStartScan,
    required this.onSkipToSchedule,
  });

  /// Triggers the scan loop (Step 6, built in Stage 2).
  final VoidCallback onStartScan;

  /// Lets the user proceed straight to the Schedule screen.
  final VoidCallback onSkipToSchedule;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // Hero Illustration Container
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
                "Thanks! Now, let's set up your first reminder!",
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
                'Scan your prescription bottle label to automatically detect the drug name, dosage, and refill schedule.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: c.inkMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // The exact same Add New Prescription button component from Schedule header
              ScanBottleButton(
                onTap: onStartScan,
                label: 'Add New Prescription',
              ),

              const Spacer(flex: 3),

              // Secondary action to explore schedule directly
              TextButton(
                onPressed: onSkipToSchedule,
                style: TextButton.styleFrom(
                  foregroundColor: c.inkMuted,
                ),
                child: const Text(
                  'Or go directly to Schedule',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
