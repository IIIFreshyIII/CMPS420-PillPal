import 'package:flutter/material.dart';

import '../models/medication.dart';
import '../services/extractor.dart';
import '../services/med_store.dart';
import '../util/format.dart';

/// The spec's core rule lives here: a human confirms EVERY field before anything
/// is saved. No confidence shortcuts, no "looks good, skip it". This is the only
/// place a [Medication] is created.
class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key, required this.extraction});

  final Extraction extraction;

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  late final Map<String, TextEditingController> _c;
  DateTime? _fillDate;

  @override
  void initState() {
    super.initState();
    final e = widget.extraction;
    _c = {
      'drug': TextEditingController(text: e.drug ?? ''),
      'strength': TextEditingController(text: e.strength ?? ''),
      'dose': TextEditingController(text: e.dose ?? ''),
      'form': TextEditingController(text: e.form ?? ''),
      'route': TextEditingController(text: e.route ?? ''),
      'frequency': TextEditingController(text: e.frequency ?? ''),
      'duration': TextEditingController(text: e.duration ?? ''),
      'daysSupply': TextEditingController(text: e.daysSupply?.toString() ?? ''),
    };
    _fillDate = e.fillDate;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime? get _refillDate {
    final n = int.tryParse(_c['daysSupply']!.text);
    if (_fillDate == null || n == null) return null;
    return _fillDate!.add(Duration(days: n));
  }

  String? _val(String key) {
    final t = _c[key]!.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _pickFillDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fillDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _fillDate = picked);
  }

  void _save() {
    MedStore.instance.add(
      Medication(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        drug: _val('drug'),
        strength: _val('strength'),
        dose: _val('dose'),
        form: _val('form'),
        route: _val('route'),
        frequency: _val('frequency'),
        duration: _val('duration'),
        fillDate: _fillDate,
        daysSupply: int.tryParse(_c['daysSupply']!.text),
      ),
    );
    // Spec: the source photo is deleted here, immediately after confirmation.
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final refill = _refillDate;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Check the details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: scheme.secondaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Check every field against the label. Nothing is saved until you '
                'confirm — the app won’t guess for you.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _field('drug', 'Drug name'),
          _field('strength', 'Strength (e.g. 500 mg)'),
          _field('dose', 'Dose (e.g. 1 tablet)'),
          _field('form', 'Form'),
          _field('route', 'Route'),
          _field('frequency', 'Frequency'),
          _field('duration', 'Duration (if any)'),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: const Text('Fill date'),
            subtitle: Text(_fillDate == null ? 'Not set' : fmtDate(_fillDate!)),
            onTap: _pickFillDate,
          ),
          _field('daysSupply', 'Days supply',
              number: true, onChanged: (_) => setState(() {})),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_available),
            title: const Text('Refill date'),
            subtitle: Text(
              refill == null
                  ? 'Needs a fill date and days supply'
                  : '${fmtDate(refill)}  (calculated, not saved separately)',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Confirm & save'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _field(String key, String label,
      {bool number = false, ValueChanged<String>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: _c[key],
        keyboardType: number ? TextInputType.number : null,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
