import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/pillpal_colors.dart';
import 'pressable.dart';

/// Reusable "Add New Prescription" / "+ Scan Bottle" button component matching
/// the exact design token hierarchy and haptic interactions from the Schedule header.
class ScanBottleButton extends StatelessWidget {
  const ScanBottleButton({
    super.key,
    required this.onTap,
    this.label = '+ Scan Bottle',
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
      scale: 0.94,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 15),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: c.liftShadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.teal,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.camera, size: 16, color: c.tealDeep),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: c.tealDeep,
                      fontWeight: FontWeight.w700,
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
