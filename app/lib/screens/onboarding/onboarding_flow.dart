import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/permissions/camera_permission.dart';
import '../../core/state/app_state_manager.dart';
import '../../core/theme/pillpal_colors.dart';
import '../../data/local/app_database.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import '../../data/services/extractor.dart';
import '../../data/services/notification_service.dart';
import '../../services/bedtime_service.dart';
import '../scan/upload_scan_screen.dart';
import 'steps/step1_splash.dart';
import 'steps/step2_legal.dart';
import 'steps/step3_name_morph.dart';
import 'steps/step4_permissions.dart';
import 'steps/step5_bedtime.dart';
import 'steps/step5_first_reminder.dart';
import 'steps/step6_scan.dart';
import 'steps/step7_verification.dart';
import 'widgets/onboarding_progress_bar.dart';

/// Master Onboarding Container orchestrating Steps 1 through 8 with forward
/// and backward sliding transitions.
///
/// Flow:
///   1. Splash
///   2. Legal Disclaimer
///   3. Name Morph
///   4. Privacy & Protection (Face ID / Passcode & Notifications)
///   5. Sleep Schedule / Bedtime Setup
///   6. First Medication Prompt (Scan, Photo, Manual Entry, or Skip)
///   7. Full-Screen Camera OCR/NER Scanner
///   8. Verification Form & Celebratory Confirmation
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.appStateManager,
    required this.database,
    required this.notificationService,
    required this.onComplete,
    this.onStartFirstScan,
    this.requestCamera,
    this.checkCamera,
  });

  final AppStateManager appStateManager;
  final AppDatabase database;
  final NotificationService notificationService;
  final VoidCallback onComplete;
  final VoidCallback? onStartFirstScan;
  final Future<CameraPermissionResult> Function()? requestCamera;
  final Future<CameraPermissionResult> Function()? checkCamera;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _includeScannerStep = true;
  bool _isProcessingPhoto = false;
  Extraction? _scannedExtraction;
  BedtimeSchedule? _configuredBedtimeSchedule;

  static const _transitionDuration = Duration(milliseconds: 340);
  static const _transitionCurve = Curves.easeOutCubic;

  void _nextPage() {
    _pageController.nextPage(
      duration: _transitionDuration,
      curve: _transitionCurve,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: _transitionDuration,
      curve: _transitionCurve,
    );
  }

  Future<void> _handleNameConfirmed(String name) async {
    await widget.appStateManager.setUserName(name);

    final primaryProfile = Profile(
      id: '1',
      name: name,
      color: const Color(0xFF168B87), // PillPal teal
      isPrimary: true,
    );
    await widget.database.upsertProfile(primaryProfile);
  }

  Future<void> _handleBedtimeConfirmed(BedtimeSchedule? schedule) async {
    _configuredBedtimeSchedule = schedule;
    await widget.appStateManager.bedtimeService.updateSchedule(
      schedule ?? BedtimeSchedule.disabled(),
    );
  }

  void _openVerificationWithoutScanner(Extraction extraction) {
    setState(() {
      _scannedExtraction = extraction;
      _includeScannerStep = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pageController.animateToPage(
          6,
          duration: _transitionDuration,
          curve: _transitionCurve,
        );
      }
    });
  }

  Future<void> _handleUploadPhoto() async {
    try {
      final extraction = await pickAndExtractFromPhoto(
        context,
        onProcessingChanged: (processing) {
          if (mounted) {
            setState(() => _isProcessingPhoto = processing);
          }
        },
      );
      if (extraction != null && mounted) {
        _openVerificationWithoutScanner(extraction);
      }
    } catch (e) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Photo Scan Failed'),
          content: Text(e.toString()),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _handleManualEntry() {
    _openVerificationWithoutScanner(Extraction(rawText: ''));
  }

  Future<void> _finishOnboarding({bool launchScan = false}) async {
    widget.appStateManager.walkthroughService.armPostOnboardingTour();
    await widget.appStateManager.setHasCompletedOnboarding(true);
    widget.onComplete();
    if (launchScan && widget.onStartFirstScan != null) {
      widget.onStartFirstScan!();
    }
  }

  Future<void> _handleConfirmAndSaveFirstMedication(
    Prescription prescription,
    Profile? newProfile,
  ) async {
    // 1. If a secondary care recipient profile was created, persist it
    if (newProfile != null) {
      await widget.database.upsertProfile(newProfile);
    }

    // 2. Persist the newly verified prescription
    await widget.database.upsertPrescription(prescription);

    // 3. Ensure seeded test data is hidden so ONLY this newly scanned
    // medication is shown on the Schedule screen (per specification)
    await widget.appStateManager.setSeededTestingMode(false);

    // 4. Arm the first-run interactive walkthrough to trigger strictly once
    // upon arriving on the unified daily feed following this initial save
    widget.appStateManager.walkthroughService.armPostOnboardingTour();

    // 5. Mark onboarding as complete and hand off to main app
    await widget.appStateManager.setHasCompletedOnboarding(true);
    widget.onComplete();
  }

  Extraction _fallbackExtraction() {
    return Extraction(
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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (page) => setState(() => _currentPage = page),
            children: [
              // Step 1: Splash (Page 0)
              Step1Splash(onComplete: _nextPage),

              // Step 2: Legal (Page 1)
              Step2Legal(onAgree: _nextPage),

              // Step 3: Name Input & Greeting Morph (Page 2)
              Step3NameMorph(
                onNameConfirmed: _handleNameConfirmed,
                onNext: _nextPage,
                initialName: widget.appStateManager.userName,
              ),

              // Step 4: Privacy & Protection (Page 3)
              Step4Permissions(
                appStateManager: widget.appStateManager,
                notificationService: widget.notificationService,
                onNext: _nextPage,
              ),

              // Step 5: Sleep Schedule / Bedtime Setup (Page 4)
              Step5Bedtime(
                onBedtimeConfirmed: _handleBedtimeConfirmed,
                onNext: _nextPage,
                initialSchedule: _configuredBedtimeSchedule,
              ),

              // Step 6: First Medication Setup Prompt (Page 5)
              Step5FirstReminder(
                onStartScan: () {
                  if (_includeScannerStep) {
                    _nextPage();
                  } else {
                    setState(() => _includeScannerStep = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _nextPage();
                    });
                  }
                },
                onUploadPhoto: _handleUploadPhoto,
                onManualEntry: _handleManualEntry,
                onSkipToSchedule: () => _finishOnboarding(launchScan: false),
              ),

              // Step 7: Full-Screen Camera OCR/NER Scanner (Page 6 when active)
              if (_includeScannerStep)
                Step6Scan(
                  isActive: _currentPage == 6,
                  onScanExtracted: (extraction) {
                    setState(() {
                      _scannedExtraction = extraction;
                    });
                    _nextPage();
                  },
                  onBack: _previousPage,
                ),

              // Step 8: Verification & Celebratory Confirmation
              Step7Verification(
                extraction: _scannedExtraction ?? _fallbackExtraction(),
                primaryUserName: widget.appStateManager.userName,
                showProgressBar: false,
                onBack: _previousPage,
                onConfirmAndSave: _handleConfirmAndSaveFirstMedication,
              ),
            ],
          ),

          // Top Progress Indicator
          // Stationary across onboarding steps; temporarily hidden on the
          // full-screen camera scanner (Step6Scan) and reappears on verification.
          if (_currentPage > 0 && !(_includeScannerStep && _currentPage == 6))
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 24,
              right: 24,
              child: OnboardingProgressBar(
                currentStep: (_currentPage - 1).clamp(0, 5),
                totalSteps: 6,
              ),
            ),

          if (_isProcessingPhoto) const ReadingLabelOverlay(),
        ],
      ),
    );
  }
}
