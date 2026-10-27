import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../presentation/widgets/pressable.dart';

/// Describes a single step in the first-run spotlight walkthrough sequence.
class WalkthroughStep {
  const WalkthroughStep({
    this.targetKey,
    this.targetKeys,
    required this.title,
    required this.description,
    required this.icon,
    this.borderRadius = 18.0,
    this.padding = EdgeInsets.zero,
    this.pulseTarget = false,
  }) : assert(targetKey != null || (targetKeys != null && targetKeys.length > 0));

  /// The [GlobalKey] attached to the widget to highlight.
  /// If the widget is not mounted or off-screen, a fallback highlight or
  /// centered card is gracefully rendered.
  final GlobalKey? targetKey;

  /// Optional list of [GlobalKey]s when multiple discrete widgets should be
  /// simultaneously highlighted with individual cutouts (e.g., individual
  /// profile switcher pill tabs).
  final List<GlobalKey>? targetKeys;

  final String title;
  final String description;
  final IconData icon;
  final double borderRadius;
  final EdgeInsets padding;

  /// Retained for backwards compatibility with existing step definitions.
  final bool pulseTarget;
}

/// Lightweight, zero-dependency spotlight walkthrough and contextual guidance
/// system built strictly with native Flutter widgets (`CustomPainter`,
/// `AnimatedOpacity`, `Matrix4` transforms, and `OverlayEntry`).
class WalkthroughOverlay extends StatefulWidget {
  const WalkthroughOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    this.onSkip,
    this.onStepChanged,
  });

  final List<WalkthroughStep> steps;
  final VoidCallback onComplete;
  final VoidCallback? onSkip;
  final ValueChanged<int>? onStepChanged;

  /// Shows the walkthrough as an [OverlayEntry] above the current screen.
  static OverlayEntry show({
    required BuildContext context,
    required List<WalkthroughStep> steps,
    required VoidCallback onComplete,
    VoidCallback? onSkip,
    ValueChanged<int>? onStepChanged,
  }) {
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => WalkthroughOverlay(
        steps: steps,
        onComplete: () {
          if (entry.mounted) entry.remove();
          onComplete();
        },
        onSkip: () {
          if (entry.mounted) entry.remove();
          (onSkip ?? onComplete)();
        },
        onStepChanged: onStepChanged,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    return entry;
  }

  @override
  State<WalkthroughOverlay> createState() => _WalkthroughOverlayState();
}

class _WalkthroughOverlayState extends State<WalkthroughOverlay>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isClosing = false;

  late final AnimationController _transitionController;

  WalkthroughStep? _outgoingStep;
  List<Rect> _outgoingRects = const [];
  double _outgoingRadius = 18.0;
  Rect? _outgoingCombinedRect;

  Rect? _currentRect;
  double _currentRadius = 18.0;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _transitionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted && _outgoingStep != null) {
          setState(() {
            _outgoingStep = null;
            _outgoingRects = const [];
            _outgoingCombinedRect = null;
          });
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recalculateTargetRect();
      final disableAnimations =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (disableAnimations) {
        _transitionController.value = 1.0;
      } else {
        _transitionController.forward();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Dynamically recalculate on screen orientation changes, safe area updates,
    // or accessible text scaling changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recalculateTargetRect();
    });
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  WalkthroughStep get _activeStep => widget.steps[_currentIndex];

  Rect? _measureKeyRect(GlobalKey key, EdgeInsets padding) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final renderObj = ctx.findRenderObject();
    if (renderObj is! RenderBox || !renderObj.hasSize || !renderObj.attached) {
      return null;
    }
    final topLeft = renderObj.localToGlobal(Offset.zero);
    final size = renderObj.size;
    if (size.width <= 0 || size.height <= 0) return null;
    final raw = topLeft & size;
    return Rect.fromLTRB(
      raw.left - padding.left,
      raw.top - padding.top,
      raw.right + padding.right,
      raw.bottom + padding.bottom,
    );
  }

  List<Rect> _measureKeyRects(List<GlobalKey> keys, EdgeInsets padding) {
    final rects = <Rect>[];
    for (final key in keys) {
      final r = _measureKeyRect(key, padding);
      if (r != null) {
        rects.add(r);
      }
    }
    return rects;
  }

  List<Rect> get _activeTargetRects {
    final step = _activeStep;
    if (step.targetKeys != null && step.targetKeys!.isNotEmpty) {
      final rects = _measureKeyRects(step.targetKeys!, step.padding);
      if (rects.isNotEmpty) return rects;
    }
    return const [];
  }

  Rect? get _activeCombinedRect {
    final multi = _activeTargetRects;
    if (multi.isNotEmpty) {
      double left = multi.first.left;
      double top = multi.first.top;
      double right = multi.first.right;
      double bottom = multi.first.bottom;
      for (final r in multi) {
        if (r.left < left) left = r.left;
        if (r.top < top) top = r.top;
        if (r.right > right) right = r.right;
        if (r.bottom > bottom) bottom = r.bottom;
      }
      return Rect.fromLTRB(left, top, right, bottom);
    }
    if (_activeStep.targetKey != null) {
      return _measureKeyRect(_activeStep.targetKey!, _activeStep.padding) ??
          _currentRect;
    }
    return _currentRect;
  }

  void _recalculateTargetRect() {
    if (!mounted || widget.steps.isEmpty) return;
    final step = _activeStep;
    final measured = step.targetKey != null
        ? _measureKeyRect(step.targetKey!, step.padding)
        : null;
    setState(() {
      _currentRect = measured;
      _currentRadius = step.borderRadius;
    });
  }

  void _handleNext() {
    if (_isClosing) return;
    if (_outgoingStep != null && _transitionController.isAnimating) return;
    HapticFeedback.selectionClick();
    if (_currentIndex < widget.steps.length - 1) {
      final prevIndex = _currentIndex;
      final prevStep = widget.steps[prevIndex];
      final nextIndex = _currentIndex + 1;
      final nextStep = widget.steps[nextIndex];

      final currentActiveRects = _activeTargetRects;
      final currentCombined = _activeCombinedRect;
      final outgoingRects = currentActiveRects.isNotEmpty
          ? currentActiveRects
          : (currentCombined != null ? [currentCombined] : <Rect>[]);
      final outgoingRadius = _currentRadius;

      setState(() {
        _outgoingStep = prevStep;
        _outgoingRects = outgoingRects;
        _outgoingCombinedRect = currentCombined;
        _outgoingRadius = outgoingRadius;

        _currentIndex = nextIndex;
        _currentRect = nextStep.targetKey != null
            ? _measureKeyRect(nextStep.targetKey!, nextStep.padding)
            : null;
        _currentRadius = nextStep.borderRadius;
      });

      _transitionController.duration = const Duration(milliseconds: 350);
      _transitionController.forward(from: 0.0);
      widget.onStepChanged?.call(nextIndex);
    } else {
      _close(skipped: false);
    }
  }

  void _handleSkip() {
    if (_isClosing) return;
    HapticFeedback.lightImpact();
    _close(skipped: true);
  }

  Future<void> _close({required bool skipped}) async {
    setState(() => _isClosing = true);
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!disableAnimations) {
      await _transitionController.animateBack(
        0.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeInCubic,
      );
    }
    if (!mounted) return;
    if (skipped) {
      (widget.onSkip ?? widget.onComplete)();
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);
    final screenSize = mq.size;
    final safeTop = mq.padding.top;
    // Account for bottom safe area + custom sliding bottom navigation bar (~92pt)
    final safeBottom = math.max(mq.padding.bottom + 88.0, 104.0);
    final disableAnimations = mq.disableAnimations;

    // Re-measure on build if layout shifted due to orientation or text scale
    final individualRects = _activeTargetRects;
    final liveRect = _activeCombinedRect;

    return Material(
      type: MaterialType.transparency,
      child: AnimatedOpacity(
        opacity: _isClosing ? 0.0 : 1.0,
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.fastOutSlowIn,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedBuilder(
              animation: _transitionController,
              builder: (context, _) {
                final v = _transitionController.value;
                final isStepTransition = _outgoingStep != null;

                // --- Calculate 3-Beat Animation Progress ---
                double outgoingBrightness = 0.0;
                double outgoingCardOpacity = 0.0;
                double incomingBrightness = 1.0;
                double cardProgress = 1.0;

                if (disableAnimations) {
                  outgoingBrightness = 0.0;
                  outgoingCardOpacity = 0.0;
                  incomingBrightness = 1.0;
                  cardProgress = 1.0;
                } else if (isStepTransition) {
                  // Beat 1: Outgoing Element Greys Out & Outgoing Card Fades Out (0.0 to 0.26)
                  if (v < 0.26) {
                    final outT = (1.0 - (v / 0.26)).clamp(0.0, 1.0);
                    outgoingBrightness = Curves.easeInCubic.transform(outT);
                    outgoingCardOpacity = Curves.easeInCubic.transform(outT);
                  } else {
                    outgoingBrightness = 0.0;
                    outgoingCardOpacity = 0.0;
                  }

                  // Beat 2: Visual Recovery Window (0.26 to 0.32) & Incoming Element Un-greys (0.32 to 0.58)
                  if (v <= 0.32) {
                    incomingBrightness = 0.0;
                  } else if (v < 0.58) {
                    final inT = ((v - 0.32) / (0.58 - 0.32)).clamp(0.0, 1.0);
                    incomingBrightness = Curves.easeOutCubic.transform(inT);
                  } else {
                    incomingBrightness = 1.0;
                  }

                  // Beat 3: Info Box Drops In & Fades In Below The Element (0.58 to 1.0)
                  if (v < 0.58) {
                    cardProgress = 0.0;
                  } else {
                    final cardT = ((v - 0.58) / (1.0 - 0.58)).clamp(0.0, 1.0);
                    cardProgress = Curves.easeOutCubic.transform(cardT);
                  }
                } else {
                  // Step 0: Initial Entrance
                  if (v < 0.35) {
                    final inT = (v / 0.35).clamp(0.0, 1.0);
                    incomingBrightness = Curves.easeOutCubic.transform(inT);
                  } else {
                    incomingBrightness = 1.0;
                  }

                  if (v < 0.30) {
                    cardProgress = 0.0;
                  } else {
                    final cardT = ((v - 0.30) / (1.0 - 0.30)).clamp(0.0, 1.0);
                    cardProgress = Curves.easeOutCubic.transform(cardT);
                  }
                }

                final isExitingOldStep = isStepTransition && v < 0.26;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Clean dimmed backdrop with cutout directly on target element(s)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {}, // Consume background taps cleanly
                      child: CustomPaint(
                        key: const Key('walkthrough_spotlight_painter'),
                        size: screenSize,
                        painter: SpotlightCutoutPainter(
                          targetRect: individualRects.isNotEmpty ? null : liveRect,
                          targetRects: individualRects,
                          borderRadius: _currentRadius,
                          targetBrightness: incomingBrightness,
                          outgoingRects: _outgoingRects,
                          outgoingRadius: _outgoingRadius,
                          outgoingBrightness: outgoingBrightness,
                          backdropColor: Colors.black.withValues(alpha: 0.52),
                        ),
                      ),
                    ),

                    // 2. Positioned Frosted Glass Tooltip Card (with drop-down entrance)
                    if (isExitingOldStep)
                      _buildPositionedTooltip(
                        context: context,
                        screenSize: screenSize,
                        safeTop: safeTop,
                        safeBottom: safeBottom,
                        targetRect: _outgoingCombinedRect,
                        step: _outgoingStep!,
                        stepIndex: _currentIndex - 1,
                        cardProgress: 1.0,
                        cardOpacity: outgoingCardOpacity,
                        disableAnimations: disableAnimations,
                      )
                    else
                      _buildPositionedTooltip(
                        context: context,
                        screenSize: screenSize,
                        safeTop: safeTop,
                        safeBottom: safeBottom,
                        targetRect: liveRect,
                        step: _activeStep,
                        stepIndex: _currentIndex,
                        cardProgress: cardProgress,
                        cardOpacity: isStepTransition && v < 0.58 ? 0.0 : cardProgress,
                        disableAnimations: disableAnimations,
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPositionedTooltip({
    required BuildContext context,
    required Size screenSize,
    required double safeTop,
    required double safeBottom,
    required Rect? targetRect,
    required WalkthroughStep step,
    required int stepIndex,
    required double cardProgress,
    required double cardOpacity,
    required bool disableAnimations,
  }) {
    const horizontalMargin = 20.0;
    const maxCardWidth = 380.0;
    final availableWidth =
        math.min(screenSize.width - horizontalMargin * 2, maxCardWidth);
    final left = (screenSize.width - availableWidth) / 2;

    // Decide whether the tooltip sits below or above the highlighted target
    const estimatedCardHeight = 220.0;
    bool placeBelow = true;
    double topOffset;

    if (targetRect != null) {
      final spaceBelow = screenSize.height - safeBottom - targetRect.bottom;
      final spaceAbove = targetRect.top - safeTop;

      if (spaceBelow >= 180 || spaceBelow >= spaceAbove) {
        placeBelow = true;
        topOffset = math.max(
          safeTop + 12,
          math.min(
            targetRect.bottom + 16,
            screenSize.height - safeBottom - estimatedCardHeight,
          ),
        );
      } else {
        placeBelow = false;
        topOffset = math.max(
          safeTop + 12,
          math.min(
            targetRect.top - 16 - estimatedCardHeight,
            screenSize.height - safeBottom - estimatedCardHeight,
          ),
        );
      }
    } else {
      topOffset = math.max(
        safeTop + 12,
        (screenSize.height - estimatedCardHeight) / 2,
      );
    }

    final maxCardHeight =
        math.max(160.0, screenSize.height - safeTop - safeBottom - 16);

    final opacityVal =
        disableAnimations ? 1.0 : cardOpacity.clamp(0.0, 1.0);
    final slideY = disableAnimations
        ? 0.0
        : (1.0 - cardProgress.clamp(0.0, 1.0)) * (placeBelow ? -10.0 : 10.0);

    final transform = Matrix4.identity()
      ..translateByDouble(0.0, slideY, 0.0, 1.0);

    return Positioned(
      left: left,
      width: availableWidth,
      top: topOffset,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxCardHeight,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Opacity(
            opacity: opacityVal,
            child: Transform(
              alignment: Alignment.center,
              transform: transform,
              child: _FrostedTooltipCard(
                step: step,
                stepIndex: stepIndex,
                totalSteps: widget.steps.length,
                onNext: _handleNext,
                onSkip: _handleSkip,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter that renders the dimmed backdrop with an anti-aliased
/// rounded-rectangle cutout. The target element remains at 100% natural
/// brightness without any borders, outlines, or pulsing halo rings.
class SpotlightCutoutPainter extends CustomPainter {
  const SpotlightCutoutPainter({
    this.targetRect,
    this.targetRects = const [],
    required this.borderRadius,
    this.targetBrightness = 1.0,
    this.outgoingRects = const [],
    this.outgoingRadius = 18.0,
    this.outgoingBrightness = 0.0,
    required this.backdropColor,
    this.accentColor,
    this.pulseProgress,
  });

  final Rect? targetRect;
  final List<Rect> targetRects;
  final double borderRadius;
  final double targetBrightness;

  final List<Rect> outgoingRects;
  final double outgoingRadius;
  final double outgoingBrightness;

  final Color backdropColor;
  final Color? accentColor;
  final double? pulseProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;
    final backdropPaint = Paint()
      ..color = backdropColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final activeRects = <Rect>[
      if (targetRect != null) targetRect!,
      ...targetRects,
    ];

    final hasActive = activeRects.isNotEmpty && targetBrightness > 0.001;
    final hasOutgoing = outgoingRects.isNotEmpty && outgoingBrightness > 0.001;

    if (!hasActive && !hasOutgoing) {
      canvas.drawRect(fullRect, backdropPaint);
      return;
    }

    // Use PathOperation.difference for a crisp rounded-rect spotlight cutout
    // with zero clipping artifacts.
    final fullPath = Path()..addRect(fullRect);
    final cutoutPath = Path();

    if (hasActive) {
      for (final r in activeRects) {
        cutoutPath.addRRect(RRect.fromRectAndRadius(
          r,
          Radius.circular(borderRadius),
        ));
      }
    }

    if (hasOutgoing) {
      for (final r in outgoingRects) {
        cutoutPath.addRRect(RRect.fromRectAndRadius(
          r,
          Radius.circular(outgoingRadius),
        ));
      }
    }

    final spotlightPath = Path.combine(
      PathOperation.difference,
      fullPath,
      cutoutPath,
    );

    canvas.drawPath(spotlightPath, backdropPaint);

    // Fade active rects from dimmed/grey backdrop to natural brightness
    if (hasActive && targetBrightness < 0.999) {
      final dimAlpha = (backdropColor.a * (1.0 - targetBrightness)).clamp(0.0, 1.0);
      if (dimAlpha > 0.001) {
        final dimPaint = Paint()
          ..color = backdropColor.withValues(alpha: dimAlpha)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;
        for (final r in activeRects) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, Radius.circular(borderRadius)),
            dimPaint,
          );
        }
      }
    }

    // Fade outgoing rects from natural brightness back to dimmed/grey backdrop
    if (hasOutgoing && outgoingBrightness < 0.999) {
      final dimAlpha = (backdropColor.a * (1.0 - outgoingBrightness)).clamp(0.0, 1.0);
      if (dimAlpha > 0.001) {
        final dimPaint = Paint()
          ..color = backdropColor.withValues(alpha: dimAlpha)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;
        for (final r in outgoingRects) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, Radius.circular(outgoingRadius)),
            dimPaint,
          );
        }
      }
    }
    // Intentionally no border or pulsing ring drawn over or around the cutout,
    // leaving the target cleanly highlighted at natural brightness.
  }

  @override
  bool shouldRepaint(covariant SpotlightCutoutPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.targetRects != targetRects ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.targetBrightness != targetBrightness ||
        oldDelegate.outgoingRects != outgoingRects ||
        oldDelegate.outgoingRadius != outgoingRadius ||
        oldDelegate.outgoingBrightness != outgoingBrightness ||
        oldDelegate.backdropColor != backdropColor;
  }
}

/// Frosted glass tooltip card displaying walkthrough step guidance.
/// Blurs and softens the background behind the card so the text is 100%
/// crisp, legible, and uncluttered without feeling like a dark mode bug.
class _FrostedTooltipCard extends StatelessWidget {
  const _FrostedTooltipCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  final WalkthroughStep step;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isLast = stepIndex == totalSteps - 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          key: Key('walkthrough_step_card_$stepIndex'),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.70),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Minimal Teal Step Tag + Skip Tour Link
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: c.tint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          step.icon,
                          color: c.tealDeep,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${stepIndex + 1} of $totalSteps',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: c.tealDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const Key('walkthrough_skip_button'),
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: c.inkMuted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Skip Tour',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Step Title
              Text(
                step.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              // Step Description
              Text(
                step.description,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.42,
                  fontWeight: FontWeight.w500,
                  color: c.inkMuted,
                ),
              ),
              const SizedBox(height: 16),
              // Bottom Row: Dot Progress Indicator + Next / Got It Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dot Progress Indicator
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(totalSteps, (idx) {
                      final active = idx == stepIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.only(right: 5),
                        width: active ? 16 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: active
                              ? c.teal
                              : c.inkMuted.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      );
                    }),
                  ),
                  Pressable(
                    key: const Key('walkthrough_next_button'),
                    onTap: onNext,
                    scale: 0.96,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: c.teal,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: c.teal.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLast ? 'Got It' : 'Next',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: c.onTeal,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isLast
                                ? CupertinoIcons.checkmark_alt
                                : CupertinoIcons.arrow_right,
                            size: 13,
                            color: c.onTeal,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline dismissible contextual helper card for secondary screens (e.g.,
/// History/Logs or Caregiver/Profile Management) visited for the first time.
class ContextualHintCard extends StatelessWidget {
  const ContextualHintCard({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.onDismiss,
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: c.tint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: c.tealDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.38,
                    fontWeight: FontWeight.w500,
                    color: c.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            key: const Key('contextual_hint_dismiss_button'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onDismiss();
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                CupertinoIcons.xmark_circle_fill,
                size: 18,
                color: c.inkMuted.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle animated illustration and call-to-action empty state widget for
/// empty feeds, respecting reduced-motion settings and dynamic text scaling.
class AnimatedEmptyFeedState extends StatefulWidget {
  const AnimatedEmptyFeedState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onCtaTap,
    this.icon = CupertinoIcons.checkmark_seal,
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onCtaTap;
  final IconData icon;

  @override
  State<AnimatedEmptyFeedState> createState() => _AnimatedEmptyFeedStateState();
}

class _AnimatedEmptyFeedStateState extends State<AnimatedEmptyFeedState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.fastOutSlowIn,
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _entranceController,
              builder: (context, child) {
                final scale = disableAnimations
                    ? 1.0
                    : (0.85 + 0.15 * _scaleAnimation.value).clamp(0.8, 1.08);
                final dy = disableAnimations
                    ? 0.0
                    : (1.0 - _fadeAnimation.value) * 8.0;
                return Opacity(
                  opacity:
                      disableAnimations ? 1.0 : _fadeAnimation.value.clamp(0.0, 1.0),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..translateByDouble(0.0, dy, 0.0, 1.0)
                      ..scaleByDouble(scale, scale, 1.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: c.tint,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c.teal.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  color: c.tealDeep,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: c.inkMuted,
                height: 1.38,
              ),
            ),
            const SizedBox(height: 18),
            Pressable(
              key: const Key('empty_feed_cta_button'),
              onTap: widget.onCtaTap,
              scale: 0.95,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: c.teal,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: c.teal.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.camera, size: 15, color: c.onTeal),
                    const SizedBox(width: 7),
                    Text(
                      widget.ctaLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.onTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
