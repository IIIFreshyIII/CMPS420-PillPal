import 'package:flutter/material.dart';

/// A high-performance tab stack that lazily mounts tab screens on their first
/// visit, keeps them alive across tab switches using [Offstage] and [TickerMode],
/// and plays a smooth [FadeTransition] when changing tabs without destroying
/// widget subtrees or resetting scroll positions.
class KeepAliveTabStack extends StatefulWidget {
  final int selectedIndex;
  final List<WidgetBuilder> builders;
  final Duration duration;

  const KeepAliveTabStack({
    super.key,
    required this.selectedIndex,
    required this.builders,
    this.duration = const Duration(milliseconds: 180),
  });

  @override
  State<KeepAliveTabStack> createState() => _KeepAliveTabStackState();
}

class _KeepAliveTabStackState extends State<KeepAliveTabStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  final Set<int> _activatedIndices = {};

  @override
  void initState() {
    super.initState();
    _activatedIndices.add(widget.selectedIndex);
    _fadeController = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(KeepAliveTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _activatedIndices.add(widget.selectedIndex);
      final disableAnim =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (widget.duration == Duration.zero || disableAnim) {
        _fadeController.value = 1.0;
      } else {
        _fadeController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(widget.builders.length, (index) {
        final isActive = index == widget.selectedIndex;
        final hasBeenActivated = _activatedIndices.contains(index);

        if (!hasBeenActivated) {
          return const SizedBox.shrink();
        }

        final child = widget.builders[index](context);

        // Keep widget tree structure identical whether active or offstage
        // so state, elements, and scroll positions are permanently preserved.
        return Offstage(
          offstage: !isActive,
          child: TickerMode(
            enabled: isActive,
            child: FadeTransition(
              opacity: isActive
                  ? _fadeAnimation
                  : const AlwaysStoppedAnimation(0.0),
              child: child,
            ),
          ),
        );
      }),
    );
  }
}
