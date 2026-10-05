import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/profile.dart';
import '../confirm/widgets/rotary_time_picker.dart';

/// Editing for an *existing* profile -- name, color, and Bedtime (the cutoff
/// `core/scheduling/reminder_scheduler.dart` uses so a medication's computed
/// reminders never land overnight) -- plus deleting the profile outright.
/// [hasPrescriptions] and the primary-profile check together decide whether
/// a delete action is even offered (see [_canDelete]).
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({
    super.key,
    required this.profile,
    required this.onUpdate,
    required this.onDelete,
    required this.hasPrescriptions,
  });

  final Profile profile;
  final ValueChanged<Profile> onUpdate;
  final VoidCallback onDelete;
  final bool hasPrescriptions;

  static Future<void> show(
    BuildContext context, {
    required Profile profile,
    required ValueChanged<Profile> onUpdate,
    required VoidCallback onDelete,
    required bool hasPrescriptions,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditProfileSheet(
        profile: profile,
        onUpdate: onUpdate,
        onDelete: onDelete,
        hasPrescriptions: hasPrescriptions,
      ),
    );
  }

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

/// A handful of preset swatches, matching the colors already used for seed
/// profiles elsewhere (`home_scaffold.dart`) -- not a full color picker.
const presetColors = [
  Color(0xFF3B82F6),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFFEF4444),
];

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _name;
  late Color _color;
  TimeOfDay? _bedtime;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
    _color = widget.profile.color;
    _bedtime = parseTimeOfDayLabel(widget.profile.bedtime);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickBedtime() async {
    final picked = await showRotaryTimePicker(context, initialTime: _bedtime);
    if (picked != null) setState(() => _bedtime = picked);
  }

  void _save() {
    final updated = widget.profile.copyWith(
      name: _name.text.trim().isEmpty ? widget.profile.name : _name.text.trim(),
      color: _color,
      bedtime: _bedtime != null ? formatTimeOfDayLabel(_bedtime!) : null,
    );
    widget.onUpdate(updated);
    Navigator.of(context).pop();
  }

  void _confirmDelete() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Delete "${widget.profile.name}"?'),
        message: const Text('This cannot be undone.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              widget.onDelete();
            },
            child: const Text('Delete Profile'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This sheet is deliberately content-sized (mainAxisSize.min), not
    // full-height like the other sheets -- so there's no internal
    // Scrollable for a focused TextField's built-in "scroll into view"
    // behavior to act on, and it needs to react to the keyboard itself.
    // MediaQuery.viewInsets.bottom (the keyboard) is intentionally separate
    // from .padding/.viewPadding (the system nav bar, stripped app-wide in
    // main.dart) -- only the keyboard should move this sheet.
    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary),
                    ),
                    TextButton(
                      key: const Key('edit_profile_save_button'),
                      onPressed: _save,
                      child: const Text('Save',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.borderLight),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            key: const Key('field_profile_name'),
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              border: UnderlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 10,
                              children: presetColors.map((c) {
                                final selected =
                                    c.toARGB32() == _color.toARGB32();
                                return GestureDetector(
                                  onTap: () => setState(() => _color = c),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border: selected
                                          ? Border.all(
                                              color: AppTheme.textPrimary,
                                              width: 2.5)
                                          : null,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'BEDTIME',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: InkWell(
                        key: const Key('field_bedtime'),
                        onTap: _pickBedtime,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('No reminders after',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                            Row(
                              children: [
                                Text(
                                  _bedtime != null
                                      ? formatTimeOfDayLabel(_bedtime!)
                                      : 'Not set',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.interactiveTeal,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(CupertinoIcons.chevron_right,
                                    size: 14, color: AppTheme.textSecondary),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Medications computed from a label's frequency (e.g. \"every 4 hours\") "
                      "stop generating reminders at this time.",
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    if (!widget.profile.isPrimary) ...[
                      const SizedBox(height: 22),
                      if (widget.hasPrescriptions)
                        const Text(
                          'Reassign or delete their medications first to delete this profile.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        )
                      else
                        Center(
                          child: TextButton(
                            onPressed: _confirmDelete,
                            child: const Text(
                              'Delete Profile',
                              style: TextStyle(
                                color: CupertinoColors.destructiveRed,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
