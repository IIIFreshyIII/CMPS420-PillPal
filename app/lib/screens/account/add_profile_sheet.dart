import 'package:flutter/material.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../data/models/profile.dart';
import 'edit_profile_sheet.dart' show presetColors;

/// Adding a new family member -- just a name and a color, matching the
/// minimal fields `EditProfileSheet` offers for an existing one (bedtime is
/// set later, once the profile exists). Always created with
/// `isPrimary: false` -- there's exactly one "this is me" profile, seeded on
/// first run, and it's never created through this flow.
class AddProfileSheet extends StatefulWidget {
  const AddProfileSheet({super.key, required this.onAdd});

  final ValueChanged<Profile> onAdd;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<Profile> onAdd,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddProfileSheet(onAdd: onAdd),
    );
  }

  @override
  State<AddProfileSheet> createState() => _AddProfileSheetState();
}

class _AddProfileSheetState extends State<AddProfileSheet> {
  final _name = TextEditingController();
  Color _color = presetColors.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty;

  void _save() {
    if (!_canSave) return;
    widget.onAdd(Profile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      color: _color,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Same keyboard-reactive, content-sized pattern as EditProfileSheet --
    // see its build() comment for why.
    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.background,
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
                    color: c.grabber,
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
                    Text(
                      'Add Family Member',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: c.ink),
                    ),
                    TextButton(
                      key: const Key('add_profile_save_button'),
                      onPressed: _canSave ? _save : null,
                      child: const Text('Add',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.borderLight),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.borderLight),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        key: const Key('field_new_profile_name'),
                        controller: _name,
                        autofocus: true,
                        decoration: const InputDecoration(
                            labelText: 'Name', border: UnderlineInputBorder()),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 10,
                          children: presetColors.map((swatch) {
                            final selected =
                                swatch.toARGB32() == _color.toARGB32();
                            return GestureDetector(
                              onTap: () => setState(() => _color = swatch),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: swatch,
                                  shape: BoxShape.circle,
                                  border: selected
                                      ? Border.all(color: c.ink, width: 2.5)
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
