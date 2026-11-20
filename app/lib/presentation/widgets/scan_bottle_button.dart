import 'package:flutter/cupertino.dart';

import '../../core/theme/pillpal_colors.dart';
import 'platform_controls.dart';
import 'pressable.dart';

/// Reusable "+ Add Meds" action button component matching
/// the exact design token hierarchy and haptic interactions from the Schedule header.
class ScanBottleButton extends StatelessWidget {
  const ScanBottleButton({
    super.key,
    required this.onTap,
    this.label = 'Add Meds',
    this.isLoading = false,
  });

  final VoidCallback? onTap;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Pressable(
      onTap: isLoading ? null : onTap,
      scale: 0.95,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: c.borderLight.withValues(alpha: 0.5),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: c.liftShadow.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 13,
                height: 13,
                child: Center(
                  child: PlatformLoadingIndicator(
                    size: 13,
                    strokeWidth: 2,
                    color: c.tealDeep,
                  ),
                ),
              )
            else
              Icon(CupertinoIcons.plus, size: 13, color: c.tealDeep),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: c.tealDeep,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
