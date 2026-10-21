import 'dart:async';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../core/theme/pillpal_colors.dart';
import '../../../presentation/widgets/pillpal_inline_logo.dart';

/// Step 1: Intro Animation Splash.
/// Minimalist launch animation container structured so a custom Lottie or Rive
/// animation asset can be dropped in later. Automatically fades out into Step 2.
class Step1Splash extends StatefulWidget {
  const Step1Splash({
    super.key,
    required this.onComplete,
    this.autoAdvanceDelay = const Duration(milliseconds: 2200),
  });

  final VoidCallback onComplete;
  final Duration autoAdvanceDelay;

  @override
  State<Step1Splash> createState() => _Step1SplashState();
}

class _Step1SplashState extends State<Step1Splash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;
  Timer? _timer;
  bool _fadingOut = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _timer = Timer(widget.autoAdvanceDelay, _advance);
  }

  void _advance() {
    if (!mounted || _fadingOut) return;
    _timer?.cancel();
    _pulseController.stop();
    setState(() => _fadingOut = true);
    // Allow the fade transition to trigger onComplete
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return GestureDetector(
      key: const Key('step1_splash_tap_area'),
      onTap: _advance,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        opacity: _fadingOut ? 0.0 : 1.0,
        child: Container(
          color: c.background,
          width: double.infinity,
          height: double.infinity,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Minimalist animated hero container -- swap in vector/Lottie asset here
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) => Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: 108,
                            height: 108,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [c.tint, c.mint.withValues(alpha: 0.6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: c.teal.withValues(
                                    alpha: _glowAnimation.value * 0.35,
                                  ),
                                  blurRadius: 36,
                                  spreadRadius: 4,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                CupertinoIcons.capsule_fill,
                                size: 52,
                                color: c.teal,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const PillPalInlineLogo(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Medication tracking, simplified & private.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: c.inkMuted,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Tap anywhere to continue',
                      style: TextStyle(
                        fontSize: 12,
                        color: c.inkMuted.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
