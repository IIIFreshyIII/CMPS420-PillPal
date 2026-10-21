import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/pillpal_colors.dart';
import '../../../presentation/widgets/pillpal_inline_logo.dart';
import '../../../presentation/widgets/pressable.dart';

/// Step 3: Name Input & In-Place Greeting Morph.
///
/// Single-view animated choreography executed over 1600ms across 4 beats:
/// - Beat 1 (0ms–450ms): Prompt header, subtitle, text field border, and submit button
///   slowly fade out while the user's typed name stays stationary in the exact center.
/// - Beat 2 (450ms–650ms): Pause/hold with ONLY the user's name floating in the center.
/// - Beat 3 (650ms–1250ms, Curves.easeInOutCubic): Name smoothly glides upward and
///   slightly to the right into its final inline position, while "Hi " fades in on
///   the left and "Welcome to PillPal!" fades in on line 2 (950ms–1250ms).
/// - Beat 4 (1250ms–1600ms): Bottom "Next >" button smoothly fades in.
class Step3NameMorph extends StatefulWidget {
  const Step3NameMorph({
    super.key,
    required this.onNameConfirmed,
    required this.onNext,
    this.initialName = '',
  });

  final Future<void> Function(String name) onNameConfirmed;
  final VoidCallback onNext;
  final String initialName;

  @override
  State<Step3NameMorph> createState() => _Step3NameMorphState();
}

class _Step3NameMorphState extends State<Step3NameMorph>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  bool _isSubmitted = false;
  String _confirmedName = '';

  late final AnimationController _morphController;

  // 4-Beat Choreography:
  // Beat 1 (0ms - 450ms): Fade out prompt and input box border/button
  late final Animation<double> _phaseAExitAnimation;

  // Beat 3 (650ms - 1250ms): Glide name smoothly upward and into inline greeting
  late final Animation<double> _nameGlideAnimation;
  late final Animation<double> _greetingRevealFade;
  late final Animation<double> _welcomeRevealFade;

  // Beat 4 (1250ms - 1600ms): Fade in Next button
  late final Animation<double> _nextButtonAnimation;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialName);
    _focusNode = FocusNode();

    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // Beat 1: 0ms - 450ms (0.0 to 450/1600 = 0.28125)
    _phaseAExitAnimation = CurvedAnimation(
      parent: _morphController,
      curve: const Interval(0.0, 0.28125, curve: Curves.easeOut),
    );

    // Beat 3: 650ms - 1250ms (650/1600 = 0.40625 to 1250/1600 = 0.78125)
    _nameGlideAnimation = CurvedAnimation(
      parent: _morphController,
      curve: const Interval(0.40625, 0.78125, curve: Curves.easeInOutCubic),
    );

    // Reveal "Hi " and "Welcome to PillPal!" (950ms - 1250ms: 0.59375 to 0.78125)
    _greetingRevealFade = CurvedAnimation(
      parent: _morphController,
      curve: const Interval(0.59375, 0.78125, curve: Curves.easeIn),
    );
    _welcomeRevealFade = CurvedAnimation(
      parent: _morphController,
      curve: const Interval(0.59375, 0.78125, curve: Curves.easeOutCubic),
    );

    // Beat 4: 1250ms - 1600ms (0.78125 to 1.0)
    _nextButtonAnimation = CurvedAnimation(
      parent: _morphController,
      curve: const Interval(0.78125, 1.0, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _morphController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final rawName = _textController.text.trim();
    if (rawName.isEmpty) return;

    // Dismiss keyboard without causing layout jumps
    FocusScope.of(context).unfocus();

    setState(() {
      _confirmedName = rawName;
      _isSubmitted = true;
    });

    // Run persistence in the background so animation starts instantly at 120 FPS
    unawaited(widget.onNameConfirmed(rawName));
    _morphController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            // Center interactive canvas offset vertically to true optical center
            Align(
              alignment: const Alignment(0.0, -0.18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Prompt Header & Subtitle: Keeps layout space to avoid jumps,
                    // fades out smoothly in Beat 1 (0ms - 450ms)
                    AnimatedBuilder(
                      animation: _morphController,
                      builder: (context, _) {
                        final exitVal = _isSubmitted
                            ? _phaseAExitAnimation.value
                            : 0.0;
                        final promptOpacity = (1.0 - exitVal).clamp(0.0, 1.0);

                        return Opacity(
                          opacity: promptOpacity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Hi! What's your name?",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: c.ink,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Just a first name or nickname is great—we'll use this to personalize your schedule.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: c.inkMuted,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 28),
                            ],
                          ),
                        );
                      },
                    ),

                    // Morphing Area:
                    // Phase A: Active input box with centered name text
                    // Phase B (Beat 1-2): Border and arrow fade to 0. Name stays centered.
                    // Phase C (Beat 3): Name glides into inline greeting; "Hi " & "Welcome" reveal
                    if (!_isSubmitted) ...[
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: c.borderChip, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: c.cardShadow,
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Center(
                              child: TextField(
                                controller: _textController,
                                focusNode: _focusNode,
                                textAlign: TextAlign.center,
                                textAlignVertical: TextAlignVertical.center,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _handleSubmit(),
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: c.ink,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'First name or nickname',
                                  hintStyle: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w400,
                                    color: c.inkMuted.withValues(alpha: 0.6),
                                  ),
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 52),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 6,
                              child: ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _textController,
                                builder: (context, value, _) {
                                  final hasText = value.text.trim().isNotEmpty;
                                  return Pressable(
                                    onTap: hasText ? _handleSubmit : null,
                                    scale: 0.92,
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: hasText ? c.teal : c.neutralChip,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.arrow_right,
                                        size: 18,
                                        color: hasText ? c.onTeal : c.neutralInk,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // SUBMITTED 4-BEAT MORPH
                      AnimatedBuilder(
                        animation: _morphController,
                        builder: (context, _) {
                          final exitVal = _phaseAExitAnimation.value;
                          final borderOpacity = (1.0 - exitVal).clamp(0.0, 1.0);
                          final glideVal = _nameGlideAnimation.value;
                          final greetingOpacity = _greetingRevealFade.value;
                          final welcomeOpacity = _welcomeRevealFade.value;

                          return Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // 1. Container border & arrow button fading out in Beat 1 (0ms-450ms)
                              if (borderOpacity > 0.0)
                                Opacity(
                                  opacity: borderOpacity,
                                  child: Container(
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: c.surface,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: c.borderChip,
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: c.cardShadow,
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Positioned(
                                          right: 6,
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: c.teal,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              CupertinoIcons.arrow_right,
                                              size: 18,
                                              color: c.onTeal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              // 2. Choreographed Name & Greeting
                              // Beat 1 & 2: Name text sits stationary in dead center.
                              // Beat 3: Glides upward and right into inline position;
                              //         "Hi " and "Welcome to PillPal!" fade in.
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Line 1: "Hi [Name]"
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      // "Hi " fades in on Beat 3 (950ms - 1250ms)
                                      Opacity(
                                        opacity: greetingOpacity,
                                        child: Text(
                                          'Hi ',
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800,
                                            color: c.ink,
                                            letterSpacing: -0.6,
                                          ),
                                        ),
                                      ),
                                      // The user's typed name: starts in dead center at (glide=0),
                                      // glides up and slightly right into inline position at (glide=1)
                                      Transform.translate(
                                        offset: Offset(
                                          (1.0 - glideVal) * -24.0,
                                          (1.0 - glideVal) * 28.0,
                                        ),
                                        child: Text(
                                          _confirmedName,
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800,
                                            color: c.tealDeep,
                                            letterSpacing: -0.6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Line 2: "Welcome to PillPal!" (fades in 950ms - 1250ms)
                                  const SizedBox(height: 12),
                                  Opacity(
                                    opacity: welcomeOpacity,
                                    child: Transform.translate(
                                      offset: Offset(
                                        0,
                                        (1.0 - welcomeOpacity) * 10,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Welcome to ',
                                            style: TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.w700,
                                              color: c.ink,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          const PillPalInlineLogo(
                                            fontSize: 27,
                                            fontWeight: FontWeight.w900,
                                          ),
                                          Text(
                                            '!',
                                            style: TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.w800,
                                              color: c.ink,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Beat 4: Bottom Next Button (1250ms - 1600ms)
            if (_isSubmitted)
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: AnimatedBuilder(
                  animation: _nextButtonAnimation,
                  builder: (context, _) {
                    final opacity = _nextButtonAnimation.value;
                    if (opacity <= 0.0) return const SizedBox.shrink();

                    return Opacity(
                      opacity: opacity,
                      child: Transform.translate(
                        offset: Offset(0, (1.0 - opacity) * 16),
                        child: Pressable(
                          onTap: widget.onNext,
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
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Next',
                                    style: TextStyle(
                                      color: c.onTeal,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    CupertinoIcons.chevron_right,
                                    size: 16,
                                    color: c.onTeal,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
