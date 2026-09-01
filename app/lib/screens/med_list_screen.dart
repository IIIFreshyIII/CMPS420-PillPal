import 'package:flutter/material.dart';

import '../models/medication.dart';
import '../services/med_store.dart';
import '../util/format.dart';
import 'capture_screen.dart';
import 'med_detail_screen.dart';

class MedListScreen extends StatelessWidget {
  const MedListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PillPal')),
      body: ListenableBuilder(
        listenable: MedStore.instance,
        builder: (context, _) {
          final meds = MedStore.instance.meds;
          if (meds.isEmpty) return const _EmptyState();
          return ListView.separated(
            itemCount: meds.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _MedTile(med: meds[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CaptureScreen()),
        ),
        icon: const Icon(Icons.photo_camera_outlined),
        label: const Text('Add from label'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medication_outlined, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Text('No medications yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Tap “Add from label” to photograph a prescription label. '
              'You’ll check every field before it’s saved.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MedTile extends StatelessWidget {
  const _MedTile({required this.med});

  final Medication med;

  @override
  Widget build(BuildContext context) {
    final refill = med.refillDate;
    final subtitle = [
      med.strength,
      med.frequency,
    ].whereType<String>().join('  ·  ');

    return ListTile(
      title: Text(med.displayName),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: refill == null
          ? null
          : Text(
              'refill\n${fmtDate(refill)}',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => MedDetailScreen(med: med)),
      ),
    );
  }
}
