import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import '../../data/services/extractor.dart';
import '../../presentation/widgets/platform_controls.dart';
import '../../presentation/widgets/pressable.dart';
import '../../ui/widgets/medication_type_selector.dart';
import '../account/widgets/bedtime_schedule_editor.dart' show kAppleSnappySpring;

enum MedicationScheduleMode { scheduled, asNeeded }

enum FoodRequirement {
  withFood('with_food', 'With food', CupertinoIcons.circle_grid_hex_fill),
  withoutFood('without_food', 'Without food', CupertinoIcons.clear_circled_solid),
  anytime('anytime', 'Anytime', CupertinoIcons.clock_fill);

  const FoodRequirement(this.storageValue, this.label, this.icon);

  final String storageValue;
  final String label;
  final IconData icon;

  static FoodRequirement fromStorage(String? raw) {
    return switch (raw) {
      'with_food' => FoodRequirement.withFood,
      'without_food' => FoodRequirement.withoutFood,
      _ => FoodRequirement.anytime,
    };
  }
}

/// Shared state controller powering [MedicationForm] across Onboarding
/// (`Step7Verification`), In-App Add (`ConfirmScreen`), and Edit
/// (`MedicationDetailSheet`).
class MedicationFormController extends ChangeNotifier {
  MedicationFormController._({
    required this.nameController,
    required this.strengthController,
    required this.doseController,
    required this.quantityController,
    required this.daysSupplyController,
    required this.refillsController,
    required int doseQuantity,
    required String? formType,
    required FoodRequirement foodRequirement,
    required MedicationScheduleMode scheduleMode,
    required String frequency,
    required List<String> reminderTimes,
    required String profileId,
    required bool allowAfterBedtime,
    required int? cooldownMinutes,
    this.extraction,
    this.isManual = false,
    this.isEdit = false,
    this.initialPrescription,
  })  : _doseQuantity = doseQuantity.clamp(1, 99),
        _formType = formType,
        _foodRequirement = foodRequirement,
        _scheduleMode = scheduleMode,
        _frequency = frequency,
        _reminderTimes = List<String>.from(reminderTimes),
        _profileId = profileId,
        _allowAfterBedtime = allowAfterBedtime,
        _cooldownMinutes = cooldownMinutes {
    _captureInitialSnapshot();
    nameController.addListener(_onNameChanged);
    strengthController.addListener(_onStrengthChanged);
    doseController.addListener(_onDoseChanged);
    quantityController.addListener(_onQuantityChanged);
    daysSupplyController.addListener(_onDaysSupplyChanged);
    refillsController.addListener(_onRefillsChanged);
  }

  /// Creates a controller pre-filled from an OCR/NER [Extraction] or blank
  /// manual entry.
  factory MedicationFormController.fromExtraction({
    Extraction? extraction,
    required String defaultProfileId,
    bool isManual = false,
    bool useOnboardingFallbackDefaults = false,
  }) {
    final e = isManual ? null : extraction;
    final hasScan = e != null && e.rawText.trim().isNotEmpty;

    final initialName = e?.drug?.trim().isNotEmpty == true
        ? e!.drug!.trim()
        : (useOnboardingFallbackDefaults && !hasScan ? '' : '');
    final initialStrength = e?.strength?.trim() ?? '';
    final initialDose = e?.dose?.trim() ?? '';
    final initialDoseQty = Prescription.parseDoseQuantity(initialDose);

    final rawFreq = (e?.frequency ?? '').toLowerCase();
    final MedicationScheduleMode mode;
    final String freq;
    final List<String> times;
    if (rawFreq.contains('as needed') || rawFreq.contains('prn')) {
      mode = MedicationScheduleMode.asNeeded;
      freq = 'Once daily';
      times = ['8:00 AM'];
    } else if (rawFreq.contains('four') ||
        rawFreq.contains('qid') ||
        rawFreq.contains('4')) {
      mode = MedicationScheduleMode.scheduled;
      freq = '4x daily';
      times = ['8:00 AM', '12:00 PM', '4:00 PM', '8:00 PM'];
    } else if (rawFreq.contains('three') ||
        rawFreq.contains('tid') ||
        rawFreq.contains('3')) {
      mode = MedicationScheduleMode.scheduled;
      freq = '3x daily';
      times = ['8:00 AM', '2:00 PM', '8:00 PM'];
    } else if (rawFreq.contains('twice') ||
        rawFreq.contains('2 times') ||
        rawFreq.contains('bid')) {
      mode = MedicationScheduleMode.scheduled;
      freq = 'Twice daily';
      times = ['8:00 AM', '8:00 PM'];
    } else {
      mode = MedicationScheduleMode.scheduled;
      freq = 'Once daily';
      times = ['8:00 AM'];
    }

    final rawText = (e?.rawText ?? '').toLowerCase();
    final FoodRequirement food;
    if (rawText.contains('with food') || rawText.contains('with meals')) {
      food = FoodRequirement.withFood;
    } else if (rawText.contains('empty stomach') ||
        rawText.contains('without food')) {
      food = FoodRequirement.withoutFood;
    } else {
      food = FoodRequirement.anytime;
    }

    final initialDaysSupply = e?.daysSupply;
    final initialQuantity = e?.quantity ??
        (initialDaysSupply != null
            ? initialDaysSupply * initialDoseQty * times.length
            : null);
    final initialRefills = e?.refills;

    final formVal = e?.form?.trim().isNotEmpty == true
        ? e!.form!.trim()
        : (useOnboardingFallbackDefaults ? 'Pill / Oral' : null);

    return MedicationFormController._(
      nameController: TextEditingController(text: initialName),
      strengthController: TextEditingController(text: initialStrength),
      doseController: TextEditingController(text: initialDose),
      quantityController: TextEditingController(
        text: initialQuantity != null ? '$initialQuantity' : '',
      ),
      daysSupplyController: TextEditingController(
        text: initialDaysSupply != null ? '$initialDaysSupply' : '',
      ),
      refillsController: TextEditingController(
        text: initialRefills != null ? '$initialRefills' : '',
      ),
      doseQuantity: initialDoseQty,
      formType: formVal,
      foodRequirement: food,
      scheduleMode: mode,
      frequency: freq,
      reminderTimes: times,
      profileId: defaultProfileId,
      allowAfterBedtime: false,
      cooldownMinutes: mode == MedicationScheduleMode.asNeeded ? 240 : null,
      extraction: e,
      isManual: isManual,
      isEdit: false,
    );
  }

  /// Creates a controller initialized for editing an existing [Prescription].
  factory MedicationFormController.fromPrescription(Prescription rx) {
    // Gracefully split legacy combined `dosage` strings (e.g. "500 mg, 2 tablets")
    // when structured `strength`/`doseAmount` aren't populated yet.
    var strength = rx.strength?.trim() ?? '';
    var doseAmount = rx.doseAmount?.trim() ?? '';
    if (strength.isEmpty && doseAmount.isEmpty && rx.dosage.trim().isNotEmpty) {
      final parts = rx.dosage.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (parts.isNotEmpty) strength = parts.first;
      if (parts.length > 1) doseAmount = parts[1];
    }

    final times = rx.reminderTimes.isNotEmpty
        ? List<String>.from(rx.reminderTimes)
        : <String>['8:00 AM'];

    final String freq;
    if (times.length >= 4) {
      freq = '4x daily';
    } else if (times.length == 3) {
      freq = '3x daily';
    } else if (times.length == 2) {
      freq = 'Twice daily';
    } else {
      freq = 'Once daily';
    }

    return MedicationFormController._(
      nameController: TextEditingController(text: rx.name),
      strengthController: TextEditingController(text: strength),
      doseController: TextEditingController(text: doseAmount),
      quantityController: TextEditingController(
        text: rx.remaining > 0 ? '${rx.remaining}' : '0',
      ),
      daysSupplyController: TextEditingController(
        text: rx.daysSupply > 0 ? '${rx.daysSupply}' : '0',
      ),
      refillsController: TextEditingController(
        text: '${rx.refillsRemaining}',
      ),
      doseQuantity: rx.effectiveDoseQuantity,
      formType: rx.form,
      foodRequirement: FoodRequirement.fromStorage(rx.foodInstruction),
      scheduleMode: rx.isAsNeeded
          ? MedicationScheduleMode.asNeeded
          : MedicationScheduleMode.scheduled,
      frequency: freq,
      reminderTimes: times,
      profileId: rx.profileId,
      allowAfterBedtime: rx.allowAfterBedtime,
      cooldownMinutes: rx.cooldownMinutes,
      isManual: true,
      isEdit: true,
      initialPrescription: rx,
    );
  }

  final TextEditingController nameController;
  final TextEditingController strengthController;
  final TextEditingController doseController;
  final TextEditingController quantityController;
  final TextEditingController daysSupplyController;
  final TextEditingController refillsController;

  final Extraction? extraction;
  final bool isManual;
  final bool isEdit;
  final Prescription? initialPrescription;

  int _doseQuantity;
  String? _formType;
  FoodRequirement _foodRequirement;
  MedicationScheduleMode _scheduleMode;
  String _frequency;
  List<String> _reminderTimes;
  String _profileId;
  bool _allowAfterBedtime;
  int? _cooldownMinutes;

  bool _manualDaysSupplyEdited = false;
  bool _updatingProgrammatically = false;
  final Set<String> _confirmedOcrFields = <String>{};

  late final _FormSnapshot _initialSnapshot;

  void _captureInitialSnapshot() {
    _initialSnapshot = _snapshot();
  }

  _FormSnapshot _snapshot() => _FormSnapshot(
        name: nameController.text.trim(),
        strength: strengthController.text.trim(),
        dose: doseController.text.trim(),
        doseQuantity: _doseQuantity,
        formType: _formType ?? '',
        foodRequirement: _foodRequirement,
        scheduleMode: _scheduleMode,
        reminderTimes: List<String>.from(_reminderTimes),
        quantity: quantityController.text.trim(),
        daysSupply: daysSupplyController.text.trim(),
        refills: refillsController.text.trim(),
        profileId: _profileId,
        allowAfterBedtime: _allowAfterBedtime,
        cooldownMinutes: _cooldownMinutes,
      );

  bool get hasUnsavedChanges => _snapshot() != _initialSnapshot;

  bool get canSave => nameController.text.trim().isNotEmpty;

  int get doseQuantity => _doseQuantity;
  String? get formType => _formType;
  FoodRequirement get foodRequirement => _foodRequirement;
  MedicationScheduleMode get scheduleMode => _scheduleMode;
  String get frequency => _frequency;
  List<String> get reminderTimes => List.unmodifiable(_reminderTimes);
  String get profileId => _profileId;
  bool get allowAfterBedtime => _allowAfterBedtime;
  int? get cooldownMinutes => _cooldownMinutes;

  int get parsedQuantity =>
      (int.tryParse(quantityController.text.trim()) ?? 0).clamp(0, 9999);
  int get parsedDaysSupply =>
      (int.tryParse(daysSupplyController.text.trim()) ?? 0).clamp(0, 9999);
  int get parsedRefills =>
      (int.tryParse(refillsController.text.trim()) ?? 0).clamp(0, 99);

  int get dailyDoseUnits {
    if (_scheduleMode == MedicationScheduleMode.asNeeded) {
      return _doseQuantity;
    }
    return _doseQuantity * (_reminderTimes.isEmpty ? 1 : _reminderTimes.length);
  }

  /// True when an OCR scan ran (not manual entry or edit).
  bool get hasOcrScan =>
      !isManual &&
      !isEdit &&
      extraction != null &&
      extraction!.rawText.trim().isNotEmpty;

  /// Returns an amber verification hint strictly when the NER/OCR extraction
  /// either had low confidence (`fieldRecognized[field] == false`) or missed
  /// a core/relevant field on the scanned bottle — and clears immediately once
  /// the user edits or confirms that field.
  String? ocrFlagMessage(String field) {
    if (!hasOcrScan) return null;
    if (_confirmedOcrFields.contains(field)) return null;
    final e = extraction!;

    final explicitlyUnrecognized = e.fieldRecognized[field] == false;
    if (explicitlyUnrecognized) {
      final matched = switch (field) {
        'drug' => e.drug,
        'strength' => e.strength,
        'dose' => e.dose,
        'form' => e.form,
        'frequency' => e.frequency,
        'quantity' => e.quantity?.toString(),
        'daysSupply' => e.daysSupply?.toString(),
        'refills' => e.refills?.toString(),
        _ => null,
      };
      if (matched != null && matched.trim().isNotEmpty) {
        return 'Verify — OCR read "$matched"';
      }
      return 'Low OCR confidence — please verify';
    }

    // Completely missed fields on the scanned label:
    return switch (field) {
      'drug' => (e.drug == null || e.drug!.trim().isEmpty)
          ? 'Not detected on label'
          : null,
      'strength' => (e.strength == null || e.strength!.trim().isEmpty)
          ? 'Not detected on label'
          : null,
      'dose' => (e.dose == null || e.dose!.trim().isEmpty)
          ? 'Not detected on label'
          : null,
      'form' => (e.form == null || e.form!.trim().isEmpty)
          ? 'Not detected on label'
          : null,
      'frequency' => (e.frequency == null || e.frequency!.trim().isEmpty)
          ? 'Not detected on label'
          : null,
      'quantity' =>
        e.quantity == null ? 'Not detected — optional' : null,
      'daysSupply' =>
        e.daysSupply == null ? 'Not detected — optional' : null,
      // Refills are intentionally optional (vitamins/OTC often have none);
      // only flag when OCR explicitly reported an unrecognized refill span.
      'refills' => null,
      _ => null,
    };
  }

  void _onNameChanged() {
    _confirmedOcrFields.add('drug');
    notifyListeners();
  }

  void _onStrengthChanged() {
    _confirmedOcrFields.add('strength');
    notifyListeners();
  }

  void _onDoseChanged() {
    _confirmedOcrFields.add('dose');
    if (!_updatingProgrammatically) {
      final parsed = Prescription.parseDoseQuantity(doseController.text);
      if (parsed != _doseQuantity) {
        _doseQuantity = parsed;
        _recalculateDaysSupplyIfAuto();
      }
    }
    notifyListeners();
  }

  void _onQuantityChanged() {
    _confirmedOcrFields.add('quantity');
    if (!_updatingProgrammatically) {
      _recalculateDaysSupplyIfAuto();
    }
    notifyListeners();
  }

  void _onDaysSupplyChanged() {
    if (!_updatingProgrammatically) {
      _confirmedOcrFields.add('daysSupply');
      _manualDaysSupplyEdited = true;
    }
    notifyListeners();
  }

  void _onRefillsChanged() {
    _confirmedOcrFields.add('refills');
    notifyListeners();
  }

  void _recalculateDaysSupplyIfAuto() {
    if (_manualDaysSupplyEdited ||
        _scheduleMode == MedicationScheduleMode.asNeeded) {
      return;
    }
    final rawQty = quantityController.text.trim();
    if (rawQty.isEmpty) return;
    final qty = int.tryParse(rawQty);
    if (qty == null || qty < 0) return;
    final daily = dailyDoseUnits;
    final computedDays = qty == 0 ? 0 : (qty / daily).ceil();
    _updatingProgrammatically = true;
    daysSupplyController.text = '$computedDays';
    _updatingProgrammatically = false;
  }

  void setDoseQuantity(int value) {
    final clamped = value.clamp(1, 99);
    if (clamped == _doseQuantity) return;
    _doseQuantity = clamped;
    _confirmedOcrFields.add('dose');
    _recalculateDaysSupplyIfAuto();
    notifyListeners();
  }

  void setFormType(String? value) {
    if (_formType == value) return;
    _formType = value;
    _confirmedOcrFields.add('form');
    notifyListeners();
  }

  void setFoodRequirement(FoodRequirement value) {
    if (_foodRequirement == value) return;
    _foodRequirement = value;
    notifyListeners();
  }

  void setScheduleMode(MedicationScheduleMode mode) {
    if (_scheduleMode == mode) return;
    _scheduleMode = mode;
    if (mode == MedicationScheduleMode.asNeeded && _cooldownMinutes == null) {
      _cooldownMinutes = 240;
    }
    notifyListeners();
  }

  void setFrequency(String freq) {
    _frequency = freq;
    _confirmedOcrFields.add('frequency');
    if (freq == 'Twice daily' && _reminderTimes.length != 2) {
      _reminderTimes = ['8:00 AM', '8:00 PM'];
    } else if (freq == '3x daily' && _reminderTimes.length != 3) {
      _reminderTimes = ['8:00 AM', '2:00 PM', '8:00 PM'];
    } else if (freq == '4x daily' && _reminderTimes.length != 4) {
      _reminderTimes = ['8:00 AM', '12:00 PM', '4:00 PM', '8:00 PM'];
    } else if (freq == 'Once daily') {
      _reminderTimes = [_reminderTimes.isNotEmpty ? _reminderTimes.first : '8:00 AM'];
    }
    _recalculateDaysSupplyIfAuto();
    notifyListeners();
  }

  void updateReminderTime(int index, String label) {
    if (index < 0 || index >= _reminderTimes.length) return;
    _reminderTimes[index] = label;
    notifyListeners();
  }

  void addReminderTime([String defaultLabel = '12:00 PM']) {
    _reminderTimes.add(defaultLabel);
    _syncFrequencyLabel();
    _recalculateDaysSupplyIfAuto();
    notifyListeners();
  }

  void removeReminderTime(int index) {
    if (_reminderTimes.length <= 1 || index < 0 || index >= _reminderTimes.length) {
      return;
    }
    _reminderTimes.removeAt(index);
    _syncFrequencyLabel();
    _recalculateDaysSupplyIfAuto();
    notifyListeners();
  }

  void _syncFrequencyLabel() {
    _frequency = switch (_reminderTimes.length) {
      1 => 'Once daily',
      2 => 'Twice daily',
      3 => '3x daily',
      _ => '4x daily',
    };
  }

  void setProfileId(String id) {
    if (_profileId == id) return;
    _profileId = id;
    notifyListeners();
  }

  void setAllowAfterBedtime(bool value) {
    if (_allowAfterBedtime == value) return;
    _allowAfterBedtime = value;
    notifyListeners();
  }

  void setCooldownMinutes(int? minutes) {
    if (_cooldownMinutes == minutes) return;
    _cooldownMinutes = minutes;
    notifyListeners();
  }

  void stepQuantity(int delta) {
    final nextQty = (parsedQuantity + delta).clamp(0, 9999);
    _updatingProgrammatically = true;
    quantityController.text = '$nextQty';
    if (_scheduleMode == MedicationScheduleMode.scheduled) {
      final daily = dailyDoseUnits;
      final nextDays = nextQty == 0 ? 0 : (nextQty / daily).ceil();
      daysSupplyController.text = '$nextDays';
    }
    _updatingProgrammatically = false;
    _confirmedOcrFields.add('quantity');
    notifyListeners();
  }

  void stepRefills(int delta) {
    final nextRefills = (parsedRefills + delta).clamp(0, 99);
    _updatingProgrammatically = true;
    refillsController.text = '$nextRefills';
    _updatingProgrammatically = false;
    _confirmedOcrFields.add('refills');
    notifyListeners();
  }

  /// Adds [amount] pills/units to bottle count and increases days supply
  /// proportionally based on daily intake rate.
  void applyQuickRefill(int amount) {
    stepQuantity(amount);
  }

  /// Builds a persisted [Prescription] from the current form values.
  Prescription buildPrescription({
    String? idOverride,
    String? profileIdOverride,
  }) {
    final name = nameController.text.trim().isNotEmpty
        ? nameController.text.trim()
        : (initialPrescription?.name ?? 'Medication');
    final strength = strengthController.text.trim();
    final dose = doseController.text.trim();
    final form = _formType?.trim() ?? '';

    final composedDosage = Prescription.composeDosage(
      strength: strength.isNotEmpty ? strength : null,
      doseAmount: dose.isNotEmpty ? dose : null,
      form: form.isNotEmpty ? form : null,
    );
    final effectiveDosage = composedDosage.isNotEmpty
        ? composedDosage
        : (initialPrescription?.dosage ?? '');

    final isPrn = _scheduleMode == MedicationScheduleMode.asNeeded;
    final effectiveTimes = isPrn
        ? const <String>[]
        : (_reminderTimes.isNotEmpty ? List<String>.from(_reminderTimes) : ['8:00 AM']);

    final rawQty = quantityController.text.trim();
    final rawDays = daysSupplyController.text.trim();
    final qty = rawQty.isEmpty
        ? 0
        : (int.tryParse(rawQty) ?? 0).clamp(0, 9999);
    final int days;
    if (isPrn) {
      days = rawDays.isEmpty ? 0 : (int.tryParse(rawDays) ?? 0).clamp(0, 9999);
    } else if (rawDays.isNotEmpty) {
      days = (int.tryParse(rawDays) ?? 0).clamp(0, 9999);
    } else if (qty > 0) {
      days = (qty / dailyDoseUnits).ceil().clamp(1, 9999);
    } else {
      days = 0;
    }

    final refills = (int.tryParse(refillsController.text.trim()) ?? 0).clamp(0, 99);

    // Keep any already-taken times that still match the updated reminder times.
    final preservedTaken = initialPrescription != null
        ? initialPrescription!.takenTimes
            .where((t) => effectiveTimes.contains(t))
            .toSet()
        : const <String>{};

    return Prescription(
      id: idOverride ??
          initialPrescription?.id ??
          'rx_${DateTime.now().millisecondsSinceEpoch}',
      profileId: profileIdOverride ?? _profileId,
      name: name,
      dosage: effectiveDosage,
      strength: strength.isNotEmpty ? strength : null,
      doseAmount: dose.isNotEmpty ? dose : null,
      doseQuantity: _doseQuantity,
      form: form.isNotEmpty ? form : null,
      foodInstruction: _foodRequirement.storageValue,
      reminderTimes: effectiveTimes,
      takenTimes: preservedTaken,
      remaining: qty,
      daysSupply: days,
      refillsRemaining: refills,
      allowAfterBedtime: _allowAfterBedtime,
      isAsNeeded: isPrn,
      cooldownMinutes: isPrn ? _cooldownMinutes : null,
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    strengthController.dispose();
    doseController.dispose();
    quantityController.dispose();
    daysSupplyController.dispose();
    refillsController.dispose();
    super.dispose();
  }
}

class _FormSnapshot {
  const _FormSnapshot({
    required this.name,
    required this.strength,
    required this.dose,
    required this.doseQuantity,
    required this.formType,
    required this.foodRequirement,
    required this.scheduleMode,
    required this.reminderTimes,
    required this.quantity,
    required this.daysSupply,
    required this.refills,
    required this.profileId,
    required this.allowAfterBedtime,
    required this.cooldownMinutes,
  });

  final String name;
  final String strength;
  final String dose;
  final int doseQuantity;
  final String formType;
  final FoodRequirement foodRequirement;
  final MedicationScheduleMode scheduleMode;
  final List<String> reminderTimes;
  final String quantity;
  final String daysSupply;
  final String refills;
  final String profileId;
  final bool allowAfterBedtime;
  final int? cooldownMinutes;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _FormSnapshot &&
        other.name == name &&
        other.strength == strength &&
        other.dose == dose &&
        other.doseQuantity == doseQuantity &&
        other.formType == formType &&
        other.foodRequirement == foodRequirement &&
        other.scheduleMode == scheduleMode &&
        listEquals(other.reminderTimes, reminderTimes) &&
        other.quantity == quantity &&
        other.daysSupply == daysSupply &&
        other.refills == refills &&
        other.profileId == profileId &&
        other.allowAfterBedtime == allowAfterBedtime &&
        other.cooldownMinutes == cooldownMinutes;
  }

  @override
  int get hashCode => Object.hash(
        name,
        strength,
        dose,
        doseQuantity,
        formType,
        foodRequirement,
        scheduleMode,
        Object.hashAll(reminderTimes),
        quantity,
        daysSupply,
        refills,
        profileId,
        allowAfterBedtime,
        cooldownMinutes,
      );
}

/// Shared Medication Form widget used by Onboarding (`Step7Verification`),
/// In-App Add (`ConfirmScreen`), and Edit (`MedicationDetailSheet`).
class MedicationForm extends StatefulWidget {
  const MedicationForm({
    super.key,
    required this.controller,
    this.profiles = const [],
    this.showProfilePicker = true,
    this.showQuickRefillButtons = false,
    this.autofocusName = false,
    this.scrollController,
    this.extraBottomChildren = const [],
  });

  final MedicationFormController controller;
  final List<Profile> profiles;
  final bool showProfilePicker;
  final bool showQuickRefillButtons;
  final bool autofocusName;
  final ScrollController? scrollController;
  final List<Widget> extraBottomChildren;

  @override
  State<MedicationForm> createState() => _MedicationFormState();
}

class _MedicationFormState extends State<MedicationForm> {
  int _modeTransitionSeq = 0;
  late MedicationScheduleMode _lastMode;

  static const Color _amberWarning = Color(0xFFF59E0B);
  static const Color _amberText = Color(0xFFB45309);

  static const List<({int? minutes, String label})> _cooldownPresets = [
    (minutes: null, label: 'None'),
    (minutes: 120, label: '2 hrs'),
    (minutes: 240, label: '4 hrs'),
    (minutes: 360, label: '6 hrs'),
    (minutes: 480, label: '8 hrs'),
    (minutes: 720, label: '12 hrs'),
  ];

  @override
  void initState() {
    super.initState();
    _lastMode = widget.controller.scheduleMode;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant MedicationForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _lastMode = widget.controller.scheduleMode;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (widget.controller.scheduleMode != _lastMode) {
      _lastMode = widget.controller.scheduleMode;
      _modeTransitionSeq++;
    }
    setState(() {});
  }

  Profile? get _selectedProfile {
    if (widget.profiles.isEmpty) return null;
    return widget.profiles.firstWhere(
      (p) => p.id == widget.controller.profileId,
      orElse: () => widget.profiles.first,
    );
  }

  void _showNativeTimePicker(int index) {
    final times = widget.controller.reminderTimes;
    if (index < 0 || index >= times.length) return;
    final now = DateTime.now();
    final parsed = parseTimeOfDayLabel(times[index]);
    final initialDate = parsed != null
        ? DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute)
        : DateTime(now.year, now.month, now.day, 8, 0);

    var selected = initialDate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerTextColor =
        isDark ? Colors.white : CupertinoColors.label.resolveFrom(context);

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Material(
        type: MaterialType.transparency,
        child: Container(
          height: 300,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: CupertinoColors.separator.resolveFrom(context),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                      Text(
                        'Reminder Time',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: headerTextColor,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text(
                          'Done',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          final hour = selected.hour;
                          final minute = selected.minute;
                          final period = hour >= 12 ? 'PM' : 'AM';
                          final displayHour =
                              hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                          final displayMin = minute.toString().padLeft(2, '0');
                          widget.controller.updateReminderTime(
                            index,
                            '$displayHour:$displayMin $period',
                          );
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: initialDate,
                    use24hFormat: false,
                    onDateTimeChanged: (dt) => selected = dt,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addReminderTime() {
    widget.controller.addReminderTime('12:00 PM');
    _showNativeTimePicker(widget.controller.reminderTimes.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = widget.controller;
    final profile = _selectedProfile;
    final modeKey = ValueKey<String>(
      '${ctrl.scheduleMode.name}_$_modeTransitionSeq',
    );

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // 1. Top Schedule Mode Segmented Control (Scheduled | As Needed)
        _ScheduleModeSegmentedControl(
          mode: ctrl.scheduleMode,
          onChanged: (next) {
            if (next == ctrl.scheduleMode) return;
            HapticFeedback.selectionClick();
            ctrl.setScheduleMode(next);
          },
        ),
        const SizedBox(height: 18),

        // 2. Medication Details Card
        _buildSectionHeader('MEDICATION DETAILS', c),
        const SizedBox(height: 8),
        _buildCard(
          c: c,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (profile?.color ?? c.teal).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.capsule_fill,
                      color: profile?.color ?? c.teal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildTextField(
                      key: const Key('field_drug'),
                      controller: ctrl.nameController,
                      label: 'Medication Name',
                      hint: 'e.g. Metformin, Vitamin D',
                      autofocus: widget.autofocusName,
                      flagMessage: ctrl.ocrFlagMessage('drug'),
                      c: c,
                    ),
                  ),
                ],
              ),
              if (widget.showProfilePicker && widget.profiles.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: c.borderLight),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'For',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.inkMuted,
                      ),
                    ),
                    DropdownButton<String>(
                      key: const Key('field_profile'),
                      value: widget.profiles.any((p) => p.id == ctrl.profileId)
                          ? ctrl.profileId
                          : widget.profiles.first.id,
                      isDense: true,
                      underline: const SizedBox(),
                      icon: Icon(
                        CupertinoIcons.chevron_down,
                        size: 13,
                        color: c.inkMuted,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                      items: widget.profiles
                          .map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name),
                              ))
                          .toList(),
                      onChanged: (id) {
                        if (id != null) ctrl.setProfileId(id);
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTextField(
                      key: const Key('field_strength'),
                      controller: ctrl.strengthController,
                      label: 'Strength',
                      hint: 'e.g. 500 mg',
                      flagMessage: ctrl.ocrFlagMessage('strength'),
                      c: c,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      key: const Key('field_dose'),
                      controller: ctrl.doseController,
                      label: 'Dose Amount',
                      hint: 'e.g. 2 tablets',
                      flagMessage: ctrl.ocrFlagMessage('dose'),
                      c: c,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.borderLight),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Units Taken Per Dose',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Deducts ${ctrl.doseQuantity} from bottle each time logged',
                            style: TextStyle(
                              fontSize: 11,
                              color: c.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MiniStepperButton(
                          key: const Key('med_form_dose_qty_minus'),
                          icon: CupertinoIcons.minus,
                          enabled: ctrl.doseQuantity > 1,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ctrl.setDoseQuantity(ctrl.doseQuantity - 1);
                          },
                        ),
                        Container(
                          constraints: const BoxConstraints(minWidth: 28),
                          alignment: Alignment.center,
                          child: Text(
                            '${ctrl.doseQuantity}',
                            key: const Key('med_form_dose_qty_value'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: c.ink,
                            ),
                          ),
                        ),
                        _MiniStepperButton(
                          key: const Key('med_form_dose_qty_plus'),
                          icon: CupertinoIcons.plus,
                          enabled: ctrl.doseQuantity < 99,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ctrl.setDoseQuantity(ctrl.doseQuantity + 1);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // 3. Intake Instructions Card
        _buildSectionHeader('INTAKE INSTRUCTIONS', c),
        const SizedBox(height: 8),
        _buildCard(
          c: c,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Medication Type',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.inkMuted,
                ),
              ),
              const SizedBox(height: 8),
              MedicationTypeSelector(
                key: const Key('field_form'),
                selectedType: ctrl.formType,
                onSelected: ctrl.setFormType,
              ),
              if (ctrl.ocrFlagMessage('form') != null)
                _buildAmberBadge(ctrl.ocrFlagMessage('form')!),
              const SizedBox(height: 16),
              Text(
                'Food Requirement',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.inkMuted,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < FoodRequirement.values.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _buildFoodOption(FoodRequirement.values[i], c),
                  ],
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // 4. Mode-specific Schedule / As-Needed + Supply sections
        _ModeContentSwitcher(
          activeKey: modeKey,
          child: KeyedSubtree(
            key: modeKey,
            child: ctrl.scheduleMode == MedicationScheduleMode.scheduled
                ? _buildScheduledSections(context, c, ctrl)
                : _buildAsNeededSections(context, c, ctrl),
          ),
        ),

        if (widget.extraBottomChildren.isNotEmpty) ...[
          const SizedBox(height: 22),
          ...widget.extraBottomChildren,
        ],
      ],
    );
  }

  Widget _buildScheduledSections(
    BuildContext context,
    PillPalColors c,
    MedicationFormController ctrl,
  ) {
    final freqFlag = ctrl.ocrFlagMessage('frequency');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('SCHEDULE & REMINDERS', c),
        const SizedBox(height: 8),
        _buildCard(
          c: c,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Frequency',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.inkMuted,
                ),
              ),
              const SizedBox(height: 8),
              HorizontalChevronScrollRow(
                children: [
                  'Once daily',
                  'Twice daily',
                  '3x daily',
                  '4x daily',
                ].map((freq) {
                  final isSelected = ctrl.frequency == freq;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FormChoiceChip(
                      label: freq,
                      selected: isSelected,
                      onTap: () => ctrl.setFrequency(freq),
                    ),
                  );
                }).toList(),
              ),
              if (freqFlag != null) _buildAmberBadge(freqFlag),
              const SizedBox(height: 16),
              Text(
                'Reminder Times',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.inkMuted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < ctrl.reminderTimes.length; i++)
                    _buildTimePill(
                      time: ctrl.reminderTimes[i],
                      index: i,
                      c: c,
                    ),
                  Pressable(
                    key: const Key('med_form_add_time_button'),
                    scale: 0.95,
                    onTap: _addReminderTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: c.tint,
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: c.teal.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.plus, size: 14, color: c.teal),
                          const SizedBox(width: 5),
                          Text(
                            'Add Time',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: c.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: c.borderLight),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send reminders after bedtime',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Override bedtime quiet hours for this medication',
                          style: TextStyle(
                            fontSize: 11,
                            color: c.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  PlatformSwitch(
                    key: const Key('med_form_allow_after_bedtime'),
                    value: ctrl.allowAfterBedtime,
                    activeThumbColor: c.onTeal,
                    activeTrackColor: c.teal,
                    onChanged: ctrl.setAllowAfterBedtime,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        _buildSectionHeader('SUPPLY & REFILLS', c),
        const SizedBox(height: 8),
        _buildCard(
          c: c,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Optional — add bottle count so PillPal can remind you before running low.',
                style: TextStyle(fontSize: 12, color: c.inkMuted),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTextField(
                      key: const Key('field_quantity'),
                      controller: ctrl.quantityController,
                      label: 'Quantity in Bottle',
                      hint: 'e.g. 60',
                      keyboardType: TextInputType.number,
                      flagMessage: ctrl.ocrFlagMessage('quantity'),
                      c: c,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      key: const Key('field_days_supply'),
                      controller: ctrl.daysSupplyController,
                      label: 'Days Supply',
                      hint: 'e.g. 30',
                      keyboardType: TextInputType.number,
                      flagMessage: ctrl.ocrFlagMessage('daysSupply'),
                      c: c,
                    ),
                  ),
                ],
              ),
              if (widget.showQuickRefillButtons) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final amt in [30, 60, 90]) ...[
                      if (amt != 30) const SizedBox(width: 10),
                      Expanded(
                        child: CupertinoButton(
                          color: c.tint,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            ctrl.applyQuickRefill(amt);
                          },
                          child: Text(
                            '+$amt Refill',
                            style: TextStyle(
                              color: c.tealDeep,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _buildTextField(
                      key: const Key('field_refills'),
                      controller: ctrl.refillsController,
                      label: 'Refills Remaining (Optional)',
                      hint: 'Leave blank if none',
                      keyboardType: TextInputType.number,
                      flagMessage: ctrl.ocrFlagMessage('refills'),
                      c: c,
                    ),
                  ),
                  if (widget.showQuickRefillButtons) ...[
                    const SizedBox(width: 12),
                    _MiniStepperButton(
                      key: const Key('detail_refills_minus'),
                      icon: CupertinoIcons.minus,
                      enabled: ctrl.parsedRefills > 0,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ctrl.stepRefills(-1);
                      },
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 28),
                      alignment: Alignment.center,
                      child: Text(
                        '${ctrl.parsedRefills}',
                        key: const Key('detail_refills_value'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                    ),
                    _MiniStepperButton(
                      key: const Key('detail_refills_plus'),
                      icon: CupertinoIcons.plus,
                      enabled: ctrl.parsedRefills < 99,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ctrl.stepRefills(1);
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAsNeededSections(
    BuildContext context,
    PillPalColors c,
    MedicationFormController ctrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('AS-NEEDED SETTINGS', c),
        const SizedBox(height: 8),
        _buildCard(
          c: c,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Minimum Cooldown Between Doses',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.inkMuted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _cooldownPresets.map((preset) {
                  final selected = ctrl.cooldownMinutes == preset.minutes;
                  return _FormChoiceChip(
                    key: Key('med_form_cooldown_${preset.minutes ?? "none"}'),
                    label: preset.label,
                    selected: selected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ctrl.setCooldownMinutes(preset.minutes);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Text(
                'Take on demand without fixed daily alarms. Cooldown helps prevent taking doses too close together.',
                style: TextStyle(fontSize: 12, color: c.inkMuted),
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: c.borderLight),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Allow after bedtime',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Allow cooldown alerts during bedtime quiet hours',
                          style: TextStyle(fontSize: 11, color: c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  PlatformSwitch(
                    key: const Key('med_form_allow_after_bedtime'),
                    value: ctrl.allowAfterBedtime,
                    activeThumbColor: c.onTeal,
                    activeTrackColor: c.teal,
                    onChanged: ctrl.setAllowAfterBedtime,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        _buildSectionHeader('SUPPLY & REFILLS', c),
        const SizedBox(height: 8),
        _buildCard(
          c: c,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Optional — track bottle quantity for low-stock alerts.',
                style: TextStyle(fontSize: 12, color: c.inkMuted),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTextField(
                      key: const Key('field_quantity'),
                      controller: ctrl.quantityController,
                      label: 'Quantity in Bottle',
                      hint: 'e.g. 30',
                      keyboardType: TextInputType.number,
                      flagMessage: ctrl.ocrFlagMessage('quantity'),
                      c: c,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      key: const Key('field_refills'),
                      controller: ctrl.refillsController,
                      label: 'Refills Remaining',
                      hint: 'Optional',
                      keyboardType: TextInputType.number,
                      flagMessage: ctrl.ocrFlagMessage('refills'),
                      c: c,
                    ),
                  ),
                ],
              ),
              if (widget.showQuickRefillButtons) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final amt in [30, 60, 90]) ...[
                      if (amt != 30) const SizedBox(width: 10),
                      Expanded(
                        child: CupertinoButton(
                          color: c.tint,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            ctrl.applyQuickRefill(amt);
                          },
                          child: Text(
                            '+$amt Refill',
                            style: TextStyle(
                              color: c.tealDeep,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFoodOption(FoodRequirement req, PillPalColors c) {
    final isSelected = widget.controller.foodRequirement == req;
    return Expanded(
      child: Pressable(
        key: Key('med_form_food_${req.storageValue}'),
        scale: 0.96,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.controller.setFoodRequirement(req);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? c.teal.withValues(alpha: 0.14) : c.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? c.teal : c.borderLight,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                req.icon,
                size: 16,
                color: isSelected ? c.teal : c.inkMuted,
              ),
              const SizedBox(height: 4),
              Text(
                req.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? c.teal : c.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePill({
    required String time,
    required int index,
    required PillPalColors c,
  }) {
    final canRemove = widget.controller.reminderTimes.length > 1;
    return Pressable(
      key: index == 0 ? const Key('field_start_time') : null,
      scale: 0.95,
      onTap: () => _showNativeTimePicker(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.clock_fill, size: 14, color: c.teal),
            const SizedBox(width: 6),
            Text(
              time,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
            if (canRemove) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => widget.controller.removeReminderTime(index),
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 16,
                  color: c.inkMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, PillPalColors c) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: c.inkMuted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildCard({required PillPalColors c, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.borderLight),
        boxShadow: [
          BoxShadow(
            color: c.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    Key? key,
    required TextEditingController controller,
    required String label,
    required String hint,
    required PillPalColors c,
    TextInputType? keyboardType,
    bool autofocus = false,
    String? flagMessage,
  }) {
    final isFlagged = flagMessage != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isFlagged ? _amberText : c.inkMuted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          key: key,
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: c.ink,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: TextStyle(
              color: c.inkMuted.withValues(alpha: 0.6),
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            filled: true,
            fillColor: isFlagged
                ? _amberWarning.withValues(alpha: 0.08)
                : c.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isFlagged ? _amberWarning : c.borderLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isFlagged ? _amberWarning : c.borderLight,
                width: isFlagged ? 1.4 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isFlagged ? _amberWarning : c.teal,
                width: 1.8,
              ),
            ),
          ),
        ),
        if (isFlagged) _buildAmberBadge(flagMessage),
      ],
    );
  }

  Widget _buildAmberBadge(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _amberWarning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _amberWarning.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            size: 11,
            color: _amberWarning,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _amberText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared glass circular action button matching PillPal's iOS modal header bar.
class MedicationFormGlassButton extends StatelessWidget {
  const MedicationFormGlassButton({
    super.key,
    this.tapKey,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.enabled = true,
  });

  final Key? tapKey;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      key: tapKey,
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: !enabled
                  ? c.glass.withValues(alpha: c.glass.a * 0.65)
                  : isPrimary
                      ? c.teal.withValues(alpha: 0.90)
                      : c.glass,
              shape: BoxShape.circle,
              border: Border.all(
                color: !enabled
                    ? c.glassRim.withValues(alpha: c.glassRim.a * 0.6)
                    : isPrimary
                        ? c.teal
                        : c.glassRim,
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
                color: !enabled
                    ? c.inkMuted.withValues(alpha: 0.5)
                    : isPrimary
                        ? c.onTeal
                        : c.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStepperButton extends StatelessWidget {
  const _MiniStepperButton({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled ? c.tint : c.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? c.teal.withValues(alpha: 0.35) : c.borderLight,
          ),
        ),
        child: Icon(
          icon,
          size: 14,
          color: enabled ? c.tealDeep : c.inkMuted.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _FormChoiceChip extends StatelessWidget {
  const _FormChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      scale: 0.95,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.teal.withValues(alpha: 0.16) : c.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? c.teal : c.borderLight,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? c.teal : c.ink,
          ),
        ),
      ),
    );
  }
}

/// Spring-driven 2-segment `UISegmentedControl` matching Chunk 1's Bedtime
/// editor style (`Scheduled` | `As Needed`).
class _ScheduleModeSegmentedControl extends StatefulWidget {
  const _ScheduleModeSegmentedControl({
    required this.mode,
    required this.onChanged,
  });

  final MedicationScheduleMode mode;
  final ValueChanged<MedicationScheduleMode> onChanged;

  @override
  State<_ScheduleModeSegmentedControl> createState() =>
      _ScheduleModeSegmentedControlState();
}

class _ScheduleModeSegmentedControlState
    extends State<_ScheduleModeSegmentedControl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _thumbController;

  double _targetFor(MedicationScheduleMode m) =>
      m == MedicationScheduleMode.scheduled ? 0.0 : 1.0;

  @override
  void initState() {
    super.initState();
    _thumbController = AnimationController.unbounded(
      vsync: this,
      value: _targetFor(widget.mode),
    );
  }

  @override
  void didUpdateWidget(covariant _ScheduleModeSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      final target = _targetFor(widget.mode);
      final instant = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (instant) {
        _thumbController.value = target;
      } else {
        final sim = SpringSimulation(
          kAppleSnappySpring,
          _thumbController.value,
          target,
          _thumbController.velocity,
        );
        _thumbController.animateWith(sim);
      }
    }
  }

  @override
  void dispose() {
    _thumbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? c.surface.withValues(alpha: 0.9)
            : c.ink.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.borderLight.withValues(alpha: 0.7)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedBuilder(
                animation: _thumbController,
                builder: (context, _) {
                  final pos = _thumbController.value.clamp(0.0, 1.0);
                  return Positioned(
                    left: pos * segWidth,
                    top: 0,
                    bottom: 0,
                    width: segWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? c.teal.withValues(alpha: 0.25) : c.surface,
                        borderRadius: BorderRadius.circular(9.5),
                        border: isDark
                            ? Border.all(color: c.teal.withValues(alpha: 0.5))
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.2 : 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      key: const Key('med_form_mode_scheduled'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          widget.onChanged(MedicationScheduleMode.scheduled),
                      child: Center(
                        child: Text(
                          'Scheduled',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                widget.mode == MedicationScheduleMode.scheduled
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                            color:
                                widget.mode == MedicationScheduleMode.scheduled
                                    ? (isDark ? c.teal : c.ink)
                                    : c.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      key: const Key('med_form_mode_as_needed'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          widget.onChanged(MedicationScheduleMode.asNeeded),
                      child: Center(
                        child: Text(
                          'As Needed',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                widget.mode == MedicationScheduleMode.asNeeded
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                            color:
                                widget.mode == MedicationScheduleMode.asNeeded
                                    ? (isDark ? c.teal : c.ink)
                                    : c.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Non-overlapping sequential dissolve matching Chunk 1's Bedtime mode switcher.
class _ModeContentSwitcher extends StatelessWidget {
  const _ModeContentSwitcher({
    required this.activeKey,
    required this.child,
  });

  final Object activeKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final instant = MediaQuery.of(context).disableAnimations;
    return AnimatedSize(
      duration: instant ? Duration.zero : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: instant ? Duration.zero : const Duration(milliseconds: 220),
        reverseDuration:
            instant ? Duration.zero : const Duration(milliseconds: 220),
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        transitionBuilder: (child, animation) {
          if (instant) return child;
          final isIncoming = child.key == activeKey;
          final curved = CurvedAnimation(
            parent: animation,
            curve: isIncoming
                ? const Interval(0.35, 1.0, curve: Curves.easeOut)
                : const Interval(0.65, 1.0, curve: Curves.easeIn),
          );
          return FadeTransition(opacity: curved, child: child);
        },
        child: child,
      ),
    );
  }
}
