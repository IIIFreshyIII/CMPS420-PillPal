import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/pillpal_colors.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';

class MedicationDetailSheet extends StatefulWidget {
  final Prescription prescription;
  final List<Profile> profiles;
  final ValueChanged<Prescription> onUpdate;
  final VoidCallback onDelete;

  const MedicationDetailSheet({
    super.key,
    required this.prescription,
    required this.profiles,
    required this.onUpdate,
    required this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required Prescription prescription,
    required List<Profile> profiles,
    required ValueChanged<Prescription> onUpdate,
    required VoidCallback onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // Dismissal only through the X button or Save -- both already run the
      // discard-changes check (_handleClose) / persist first. A barrier tap
      // or swipe-down would otherwise silently drop any unsaved edit.
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => MedicationDetailSheet(
        prescription: prescription,
        profiles: profiles,
        onUpdate: onUpdate,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<MedicationDetailSheet> createState() => _MedicationDetailSheetState();
}

class _MedicationDetailSheetState extends State<MedicationDetailSheet> {
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late int _remaining;
  late int _daysSupply;
  late String _selectedProfileId;
  late bool _allowAfterBedtime;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.prescription.name);
    _dosageController = TextEditingController(text: widget.prescription.dosage);
    _remaining = widget.prescription.remaining;
    _daysSupply = widget.prescription.daysSupply;
    _selectedProfileId = widget.prescription.profileId;
    _allowAfterBedtime = widget.prescription.allowAfterBedtime;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges =>
      _nameController.text.trim() != widget.prescription.name ||
      _dosageController.text.trim() != widget.prescription.dosage ||
      _remaining != widget.prescription.remaining ||
      _daysSupply != widget.prescription.daysSupply ||
      _selectedProfileId != widget.prescription.profileId ||
      _allowAfterBedtime != widget.prescription.allowAfterBedtime;

  void _handleClose() {
    if (!_hasUnsavedChanges) {
      Navigator.pop(context);
      return;
    }
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Discard changes?'),
        message:
            const Text('Your edits to this medication have not been saved.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Discard Changes'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Keep Editing'),
        ),
      ),
    );
  }

  void _saveChanges() {
    HapticFeedback.lightImpact();
    final updated = widget.prescription.copyWith(
      name: _nameController.text.trim().isEmpty
          ? widget.prescription.name
          : _nameController.text.trim(),
      dosage: _dosageController.text.trim().isEmpty
          ? widget.prescription.dosage
          : _dosageController.text.trim(),
      remaining: _remaining,
      daysSupply: _daysSupply,
      profileId: _selectedProfileId,
      allowAfterBedtime: _allowAfterBedtime,
    );
    widget.onUpdate(updated);
    Navigator.pop(context);
  }

  void _handleQuickRefill(int amount) {
    HapticFeedback.mediumImpact();
    setState(() {
      _remaining += amount;
      _daysSupply += amount;
    });
  }

  void _confirmDelete() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Delete "${widget.prescription.name}"?'),
        message: const Text(
            'This will remove the medication and its tracking history.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              widget.onDelete();
            },
            child: const Text('Delete Prescription'),
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

  Widget _buildGlassCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isPrimary ? c.teal.withValues(alpha: 0.90) : c.glass,
              shape: BoxShape.circle,
              border: Border.all(
                color: isPrimary ? c.teal : c.glassRim,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: c.liftShadow,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                size: 18,
                color: isPrimary ? c.onTeal : c.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final profile = widget.profiles.firstWhere(
      (p) => p.id == _selectedProfileId,
      orElse: () => const Profile(id: '0', name: 'General', color: Colors.grey),
    );
    final isLow = _remaining <= 5;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleClose();
      },
      child: Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // iOS Pull/Grab Handle
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

              // Top Bar with Liquid Glass Circular Action Buttons
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildGlassCircleButton(
                      icon: CupertinoIcons.xmark,
                      onTap: _handleClose,
                    ),
                    Text(
                      'Prescription Details',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    _buildGlassCircleButton(
                      icon: CupertinoIcons.checkmark,
                      isPrimary: true,
                      onTap: _saveChanges,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.borderLight),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: [
                    // Hero Header Card with "Taken Today" Toggle
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: c.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: c.cardShadow,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: profile.color.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(CupertinoIcons.capsule_fill,
                                    color: profile.color, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.prescription.name,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: c.ink,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Prescribed to ${profile.name}',
                                      style: TextStyle(
                                          fontSize: 13, color: c.inkMuted),
                                    ),
                                  ],
                                ),
                              ),
                              if (isLow)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: c.alertTint,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Low Stock',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: c.alert,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Inventory & Supply Section
                    Text(
                      'INVENTORY & SUPPLY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.inkMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.borderLight),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Remaining Doses',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text('$_daysSupply days remaining',
                                      style: TextStyle(
                                          fontSize: 12, color: c.inkMuted)),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(CupertinoIcons.minus_circle,
                                        color: c.teal, size: 26),
                                    onPressed: () {
                                      if (_remaining > 0) {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _remaining--;
                                          if (_daysSupply > 0) _daysSupply--;
                                        });
                                      }
                                    },
                                  ),
                                  Container(
                                    constraints:
                                        const BoxConstraints(minWidth: 36),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$_remaining',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(CupertinoIcons.plus_circle,
                                        color: c.teal, size: 26),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _remaining++;
                                        _daysSupply++;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Divider(height: 20, color: c.borderLight),
                          Row(
                            children: [
                              Expanded(
                                child: CupertinoButton(
                                  color: c.tint,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  borderRadius: BorderRadius.circular(12),
                                  onPressed: () => _handleQuickRefill(30),
                                  child: Text(
                                    '+30 Refill',
                                    style: TextStyle(
                                      color: c.tealDeep,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: CupertinoButton(
                                  color: c.tint,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  borderRadius: BorderRadius.circular(12),
                                  onPressed: () => _handleQuickRefill(60),
                                  child: Text(
                                    '+60 Refill',
                                    style: TextStyle(
                                      color: c.tealDeep,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: CupertinoButton(
                                  color: c.tint,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  borderRadius: BorderRadius.circular(12),
                                  onPressed: () => _handleQuickRefill(90),
                                  child: Text(
                                    '+90 Refill',
                                    style: TextStyle(
                                      color: c.tealDeep,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Medication Info Section
                    Text(
                      'MEDICATION INFORMATION',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.inkMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.borderLight),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Medication Name',
                              border: UnderlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _dosageController,
                            decoration: const InputDecoration(
                              labelText: 'Dosage / Strength',
                              border: UnderlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Read-only -- regenerating the reminder schedule
                          // (changing start time/frequency after the fact)
                          // isn't supported yet; only the bedtime override
                          // below is editable here.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Scheduled Time',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              Expanded(
                                child: Text(
                                  widget.prescription.reminderTimes.join(', '),
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: c.inkMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Divider(height: 16, color: c.borderLight),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Assignee',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              DropdownButton<String>(
                                value: _selectedProfileId,
                                underline: const SizedBox(),
                                items: widget.profiles.map((p) {
                                  return DropdownMenuItem(
                                      value: p.id, child: Text(p.name));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedProfileId = val);
                                  }
                                },
                              ),
                            ],
                          ),
                          Divider(height: 16, color: c.borderLight),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Send reminders after bedtime',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              Switch(
                                value: _allowAfterBedtime,
                                activeThumbColor: c.teal,
                                onChanged: (val) =>
                                    setState(() => _allowAfterBedtime = val),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Destructive Delete Button
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(16),
                        onPressed: _confirmDelete,
                        child: const Text(
                          'Delete Prescription',
                          style: TextStyle(
                            color: CupertinoColors.destructiveRed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
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
