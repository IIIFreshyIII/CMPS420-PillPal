import 'package:flutter/foundation.dart';

import '../models/medication.dart';

/// In-memory medication list.
///
/// TEMPORARY. The spec calls for an encrypted local database (SQLCipher via
/// `drift`, keys in the platform keystore). Replace the guts of this class
/// later; keep the method signatures so the screens don't change.
class MedStore extends ChangeNotifier {
  MedStore._();
  static final MedStore instance = MedStore._();

  final List<Medication> _meds = [];

  List<Medication> get meds => List.unmodifiable(_meds);

  void add(Medication m) {
    _meds.add(m);
    notifyListeners();
  }

  void remove(String id) {
    _meds.removeWhere((m) => m.id == id);
    notifyListeners();
  }
}
