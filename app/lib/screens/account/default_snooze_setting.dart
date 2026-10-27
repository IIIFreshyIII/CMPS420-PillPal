import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../services/snooze_settings_service.dart';

/// Profile → Preferences & Storage → Default Snooze Duration:
/// Provides selectable preset options (`5m`, `9m` default, `15m`, `30m`) and a
/// `Custom` button that opens a modal dialog for entering any positive minute
/// duration, persisted via `shared_preferences`.
class DefaultSnoozeSetting extends StatefulWidget {
  const DefaultSnoozeSetting({
    super.key,
    this.service,
  });

  final SnoozeSettingsService? service;

  @override
  State<DefaultSnoozeSetting> createState() => _DefaultSnoozeSettingState();
}

class _DefaultSnoozeSettingState extends State<DefaultSnoozeSetting> {
  late SnoozeSettingsService _service;
  bool _ownsService = false;

  @override
  void initState() {
    super.initState();
    if (widget.service != null) {
      _service = widget.service!;
      if (!_service.isLoaded) {
        _service.load();
      }
    } else {
      _service = SnoozeSettingsService();
      _ownsService = true;
      _service.load();
    }
  }

  @override
  void didUpdateWidget(covariant DefaultSnoozeSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.service != oldWidget.service) {
      if (_ownsService) {
        _service.dispose();
        _ownsService = false;
      }
      if (widget.service != null) {
        _service = widget.service!;
        if (!_service.isLoaded) {
          _service.load();
        }
      } else {
        _service = SnoozeSettingsService();
        _ownsService = true;
        _service.load();
      }
    }
  }

  @override
  void dispose() {
    if (_ownsService) {
      _service.dispose();
    }
    super.dispose();
  }

  Future<void> _selectPreset(int minutes) async {
    HapticFeedback.selectionClick();
    await _service.setSnoozeDurationMinutes(minutes);
  }

  Future<void> _openCustomDialog(BuildContext context) async {
    HapticFeedback.selectionClick();
    final initialValue = _service.customSnoozeDurationMinutes ??
        (_service.isCustomSelected ? _service.snoozeDurationMinutes : 10);
    final controller = TextEditingController(text: '$initialValue');

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            void submit() {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null || parsed <= 0 || parsed > 720) {
                setDialogState(() {
                  errorText = 'Enter a duration between 1 and 720 minutes.';
                });
                return;
              }
              Navigator.of(ctx).pop(parsed);
            }

            return AlertDialog(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: c.borderLight),
              ),
              title: Text(
                'Custom Snooze Duration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set your preferred snooze length in minutes for live reminder countdowns.',
                    style: TextStyle(
                      fontSize: 13,
                      color: c.inkMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('custom_snooze_input'),
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Minutes',
                      suffixText: 'min',
                      errorText: errorText,
                      filled: true,
                      fillColor: c.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.borderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.teal, width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => submit(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  key: const Key('custom_snooze_cancel_button'),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: c.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton(
                  key: const Key('custom_snooze_save_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.teal,
                    foregroundColor: c.onTeal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: submit,
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      await _service.setCustomSnoozeDurationMinutes(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final currentMinutes = _service.snoozeDurationMinutes;
        final isCustom = _service.isCustomSelected;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(CupertinoIcons.timer, size: 20, color: c.ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Default Snooze Duration',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Text(
                    SnoozeSettingsService.formatDetailLabel(currentMinutes),
                    key: const ValueKey('snooze_active_label'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SnoozePresetSelector(
                selectedMinutes: currentMinutes,
                isCustomSelected: isCustom,
                onSelectPreset: _selectPreset,
                onTapCustom: () => _openCustomDialog(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SnoozePresetSelector extends StatelessWidget {
  const SnoozePresetSelector({
    super.key,
    required this.selectedMinutes,
    required this.isCustomSelected,
    required this.onSelectPreset,
    required this.onTapCustom,
  });

  final int selectedMinutes;
  final bool isCustomSelected;
  final ValueChanged<int> onSelectPreset;
  final VoidCallback onTapCustom;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const presets = SnoozeSettingsService.presetOptions;
    final totalSegments = presets.length + 1; // 4 presets + Custom
    final selectedIndex = isCustomSelected
        ? presets.length
        : presets.indexOf(selectedMinutes).clamp(0, presets.length - 1);
    final instant = MediaQuery.of(context).disableAnimations;

    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.segmentTrack,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final segmentWidth = box.maxWidth / totalSegments;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: instant
                    ? Duration.zero
                    : const Duration(milliseconds: 250),
                curve: Curves.fastOutSlowIn,
                left: selectedIndex * segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.segmentThumb,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: c.liftShadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final preset in presets)
                        Expanded(
                          child: Semantics(
                            selected:
                                !isCustomSelected && selectedMinutes == preset,
                            button: true,
                            child: InkWell(
                              key: ValueKey('snooze_preset_${preset}m'),
                              borderRadius: BorderRadius.circular(8),
                              splashColor: c.tealRipple,
                              highlightColor: Colors.transparent,
                              onTap: (!isCustomSelected &&
                                      selectedMinutes == preset)
                                  ? null
                                  : () => onSelectPreset(preset),
                              child: Center(
                                child: Text(
                                  SnoozeSettingsService.formatPresetLabel(
                                      preset),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: (!isCustomSelected &&
                                            selectedMinutes == preset)
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: (!isCustomSelected &&
                                            selectedMinutes == preset)
                                        ? c.ink
                                        : c.inkMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Semantics(
                          selected: isCustomSelected,
                          button: true,
                          child: InkWell(
                            key: const ValueKey('snooze_preset_custom'),
                            borderRadius: BorderRadius.circular(8),
                            splashColor: c.tealRipple,
                            highlightColor: Colors.transparent,
                            onTap: onTapCustom,
                            child: Center(
                              child: Text(
                                'Custom',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isCustomSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: isCustomSelected ? c.ink : c.inkMuted,
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
            ],
          );
        },
      ),
    );
  }
}
