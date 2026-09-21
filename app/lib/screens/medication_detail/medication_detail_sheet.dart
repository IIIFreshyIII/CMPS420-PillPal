import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
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
  late String _selectedTime;
  late String _selectedProfileId;
  late bool _takenToday;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.prescription.name);
    _dosageController = TextEditingController(text: widget.prescription.dosage);
    _remaining = widget.prescription.remaining;
    _daysSupply = widget.prescription.daysSupply;
    _selectedTime = widget.prescription.time;
    _selectedProfileId = widget.prescription.profileId;
    _takenToday = widget.prescription.takenToday;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    HapticFeedback.lightImpact();
    final updated = widget.prescription.copyWith(
      name: _nameController.text.trim().isEmpty ? widget.prescription.name : _nameController.text.trim(),
      dosage: _dosageController.text.trim().isEmpty ? widget.prescription.dosage : _dosageController.text.trim(),
      remaining: _remaining,
      daysSupply: _daysSupply,
      time: _selectedTime,
      profileId: _selectedProfileId,
      takenToday: _takenToday,
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

  void _toggleTakenToday() {
    HapticFeedback.mediumImpact();
    setState(() {
      _takenToday = !_takenToday;
      if (_takenToday) {
        _remaining = (_remaining - 1).clamp(0, 9999);
        _daysSupply = (_daysSupply - 1).clamp(0, 9999);
      } else {
        _remaining = (_remaining + 1).clamp(0, 9999);
        _daysSupply = (_daysSupply + 1).clamp(0, 9999);
      }
    });
  }

  void _confirmDelete() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Delete "${widget.prescription.name}"?'),
        message: const Text('This will remove the medication and its tracking history.'),
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
              color: isPrimary
                  ? AppTheme.interactiveTeal.withValues(alpha: 0.90)
                  : Colors.white.withValues(alpha: 0.70),
              shape: BoxShape.circle,
              border: Border.all(
                color: isPrimary
                    ? AppTheme.interactiveTeal
                    : Colors.white.withValues(alpha: 0.9),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.textPrimary.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                size: 18,
                color: isPrimary ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profiles.firstWhere(
      (p) => p.id == _selectedProfileId,
      orElse: () => const Profile(id: '0', name: 'General', color: Colors.grey),
    );
    final isLow = _remaining <= 5;

    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFA),
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
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Top Bar with Liquid Glass Circular Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildGlassCircleButton(
                    icon: CupertinoIcons.xmark,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Prescription Details',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
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
            const Divider(height: 1, color: AppTheme.borderLight),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  // Hero Header Card with "Taken Today" Toggle
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.textPrimary.withValues(alpha: 0.03),
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
                              child: Icon(CupertinoIcons.capsule_fill, color: profile.color, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.prescription.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Prescribed to ${profile.name} • ${_selectedTime}',
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            if (isLow)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.lowStockAlert.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Low Stock',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.lowStockAlert,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: AppTheme.borderLight),
                        const SizedBox(height: 14),
                        // Quick Action: Taken Today Toggle
                        GestureDetector(
                          onTap: _toggleTakenToday,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                            decoration: BoxDecoration(
                              color: _takenToday ? AppTheme.lightPillTint : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _takenToday ? AppTheme.headerTeal : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _takenToday
                                          ? CupertinoIcons.checkmark_circle_fill
                                          : CupertinoIcons.circle,
                                      color: _takenToday ? AppTheme.interactiveTeal : const Color(0xFF94A3B8),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _takenToday ? 'Taken Today' : 'Mark as Taken Today',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _takenToday ? AppTheme.interactiveTeal : AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  _takenToday ? 'Dose Logged' : 'Tap to log',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _takenToday ? AppTheme.interactiveTeal : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Inventory & Supply Section
                  const Text(
                    'INVENTORY & SUPPLY',
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
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Remaining Doses', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text('$_daysSupply days remaining', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(CupertinoIcons.minus_circle, color: AppTheme.interactiveTeal, size: 26),
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
                                  constraints: const BoxConstraints(minWidth: 36),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$_remaining',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(CupertinoIcons.plus_circle, color: AppTheme.interactiveTeal, size: 26),
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
                        const Divider(height: 20, color: AppTheme.borderLight),
                        Row(
                          children: [
                            Expanded(
                              child: CupertinoButton(
                                color: AppTheme.lightPillTint,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                borderRadius: BorderRadius.circular(12),
                                onPressed: () => _handleQuickRefill(30),
                                child: const Text(
                                  '+30 Refill',
                                  style: TextStyle(
                                    color: AppTheme.interactiveTeal,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CupertinoButton(
                                color: AppTheme.lightPillTint,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                borderRadius: BorderRadius.circular(12),
                                onPressed: () => _handleQuickRefill(60),
                                child: const Text(
                                  '+60 Refill',
                                  style: TextStyle(
                                    color: AppTheme.interactiveTeal,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CupertinoButton(
                                color: AppTheme.lightPillTint,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                borderRadius: BorderRadius.circular(12),
                                onPressed: () => _handleQuickRefill(90),
                                child: const Text(
                                  '+90 Refill',
                                  style: TextStyle(
                                    color: AppTheme.interactiveTeal,
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
                  const Text(
                    'MEDICATION INFORMATION',
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Scheduled Time', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            DropdownButton<String>(
                              value: _selectedTime,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: '8:00 AM', child: Text('8:00 AM (Morning)')),
                                DropdownMenuItem(value: '12:00 PM', child: Text('12:00 PM (Noon)')),
                                DropdownMenuItem(value: '6:00 PM', child: Text('6:00 PM (Evening)')),
                                DropdownMenuItem(value: '9:00 PM', child: Text('9:00 PM (Bedtime)')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedTime = val);
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 16, color: AppTheme.borderLight),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Assignee', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            DropdownButton<String>(
                              value: _selectedProfileId,
                              underline: const SizedBox(),
                              items: widget.profiles.map((p) {
                                return DropdownMenuItem(value: p.id, child: Text(p.name));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedProfileId = val);
                              },
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
                      color: Colors.white,
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
    );
  }
}