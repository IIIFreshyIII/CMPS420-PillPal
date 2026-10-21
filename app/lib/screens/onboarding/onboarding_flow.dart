import 'package:flutter/material.dart';

import '../../core/permissions/camera_permission.dart';
import '../../core/state/app_state_manager.dart';
import '../../core/theme/pillpal_colors.dart';
import '../../data/local/app_database.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import '../../data/services/extractor.dart';
import '../../data/services/notification_service.dart';
import 'steps/step1_splash.dart';
import 'steps/step2_legal.dart';
import 'steps/step3_name_morph.dart';
import 'steps/step4_permissions.dart';
import 'steps/step5_first_reminder.dart';
import 'steps/step6_scan.dart';
import 'steps/step7_verification.dart';
import 'widgets/onboarding_progress_bar.dart';

/// Master Onboarding Container orchestrating Steps 1 through 7 with forward
/// and backward sliding transitions.
///
/// Flow:
///   1. Splash
///   2. Legal Disclaimer
///   3. Name Morph
///   4. Permissions & Settings
///   5. First Reminder Prompt
///   6. Full-Screen Camera OCR/NER Scanner
///   7. Verification Form & Celebratory Confirmation
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
  Extraction? _scannedExtraction;

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

    // Automatically create or update the primary CareRecipient profile
    final primaryProfile = Profile(
      id: '1',
      name: name,
      color: const Color(0xFF168B87), // PillPal teal
      isPrimary: true,
    );
    await widget.database.upsertProfile(primaryProfile);
  }

  Future<void> _finishOnboarding({bool launchScan = false}) async {
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

    // 4. Mark onboarding as complete and hand off to main app
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
              // Step 1: Splash
              Step1Splash(onComplete: _nextPage),

              // Step 2: Legal
              Step2Legal(onAgree: _nextPage),

              // Step 3: Name Input & Greeting Morph
              Step3NameMorph(
                onNameConfirmed: _handleNameConfirmed,
                onNext: _nextPage,
                initialName: widget.appStateManager.userName,
              ),

              // Step 4: Permissions & Settings
              Step4Permissions(
                appStateManager: widget.appStateManager,
                notificationService: widget.notificationService,
                onNext: _nextPage,
                requestCamera: widget.requestCamera,
                checkCamera: widget.checkCamera,
              ),

              // Step 5: First Reminder Prompt
              Step5FirstReminder(
                onStartScan: _nextPage,
                onSkipToSchedule: () => _finishOnboarding(launchScan: false),
              ),

              // Step 6: Full-Screen Camera OCR/NER Scanner
              Step6Scan(
                isActive: _currentPage == 5,
                onScanExtracted: (extraction) {
                  setState(() => _scannedExtraction = extraction);
                  _nextPage();
                },
                onBack: _previousPage,
              ),

              // Step 7: Verification & Celebratory Confirmation
              Step7Verification(
                extraction: _scannedExtraction ?? _fallbackExtraction(),
                primaryUserName: widget.appStateManager.userName,
                onBack: _previousPage,
                onConfirmAndSave: _handleConfirmAndSaveFirstMedication,
              ),
            ],
          ),

          // Top Progress Indicator
          // Visible on Steps 2, 3, 4, 5 (Steps 6 & 7 render their own progress bar inside their top area to prevent collision with navigation header)
          if (_currentPage > 0 && _currentPage < 5)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 24,
              right: 24,
              child: OnboardingProgressBar(
                currentStep: _currentPage - 1,
                totalSteps: 6,
              ),
            ),
        ],
      ),
    );
  }
}
