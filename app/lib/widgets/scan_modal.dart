import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../data/models/profile.dart';

class ScanModal extends StatefulWidget {
  final List<Profile> profiles;
  final ValueChanged<Map<String, dynamic>> onSave;

  const ScanModal({
    super.key,
    required this.profiles,
    required this.onSave,
  });

  @override
  State<ScanModal> createState() => _ScanModalState();
}

class _ScanModalState extends State<ScanModal> {
  final _nameController = TextEditingController(text: 'Amoxicillin');
  final _dosageController = TextEditingController(text: '500mg');
  final _countController = TextEditingController(text: '30');
  final String _selectedTime = '8:00 AM';
  late String _selectedProfileId;

  @override
  void initState() {
    super.initState();
    _selectedProfileId = widget.profiles.isNotEmpty ? widget.profiles.first.id : '1';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Scanned Prescription',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Medication Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dosageController,
            decoration: const InputDecoration(labelText: 'Dosage / Strength'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _countController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Pill Count'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: AppTheme.interactiveTeal,
              borderRadius: BorderRadius.circular(16),
              onPressed: () {
                widget.onSave({
                  'name': _nameController.text,
                  'dosage': _dosageController.text,
                  'remaining': int.tryParse(_countController.text) ?? 30,
                  'time': _selectedTime,
                  'profileId': _selectedProfileId,
                });
                Navigator.pop(context);
              },
              child: const Text(
                'Save Prescription',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}