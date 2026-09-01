import 'package:flutter/material.dart';

import '../models/medication.dart';
import '../services/med_store.dart';
import '../util/format.dart';

class MedDetailScreen extends StatelessWidget {
  const MedDetailScreen({super.key, required this.med});

  final Medication med;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String?)>[
      ('Strength', med.strength),
      ('Dose', med.dose),
      ('Form', med.form),
      ('Route', med.route),
      ('Frequency', med.frequency),
      ('Duration', med.duration),
      ('Fill date', med.fillDate == null ? null : fmtDate(med.fillDate!)),
      ('Days supply', med.daysSupply?.toString()),
      ('Refill date', med.refillDate == null ? null : fmtDate(med.refillDate!)),
      ('Refill reminder',
          med.refillWarnDate == null ? null : fmtDate(med.refillWarnDate!)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(med.displayName),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              MedStore.instance.remove(med.id);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          for (final (label, value) in rows)
            if (value != null)
              ListTile(
                dense: true,
                title: Text(label),
                subtitle: Text(value),
              ),
        ],
      ),
    );
  }
}
