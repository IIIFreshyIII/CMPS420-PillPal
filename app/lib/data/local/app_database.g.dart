// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ProfilesTable extends Profiles
    with TableInfo<$ProfilesTable, ProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _colorValueMeta =
      const VerificationMeta('colorValue');
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
      'color_value', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _isPrimaryMeta =
      const VerificationMeta('isPrimary');
  @override
  late final GeneratedColumn<bool> isPrimary = GeneratedColumn<bool>(
      'is_primary', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_primary" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _bedtimeMeta =
      const VerificationMeta('bedtime');
  @override
  late final GeneratedColumn<String> bedtime = GeneratedColumn<String>(
      'bedtime', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, colorValue, isPrimary, bedtime];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(Insertable<ProfileRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
          _colorValueMeta,
          colorValue.isAcceptableOrUnknown(
              data['color_value']!, _colorValueMeta));
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('is_primary')) {
      context.handle(_isPrimaryMeta,
          isPrimary.isAcceptableOrUnknown(data['is_primary']!, _isPrimaryMeta));
    }
    if (data.containsKey('bedtime')) {
      context.handle(_bedtimeMeta,
          bedtime.isAcceptableOrUnknown(data['bedtime']!, _bedtimeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      colorValue: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color_value'])!,
      isPrimary: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_primary'])!,
      bedtime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bedtime']),
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  final String id;
  final String name;
  final int colorValue;
  final bool isPrimary;
  final String? bedtime;
  const ProfileRow(
      {required this.id,
      required this.name,
      required this.colorValue,
      required this.isPrimary,
      this.bedtime});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color_value'] = Variable<int>(colorValue);
    map['is_primary'] = Variable<bool>(isPrimary);
    if (!nullToAbsent || bedtime != null) {
      map['bedtime'] = Variable<String>(bedtime);
    }
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      name: Value(name),
      colorValue: Value(colorValue),
      isPrimary: Value(isPrimary),
      bedtime: bedtime == null && nullToAbsent
          ? const Value.absent()
          : Value(bedtime),
    );
  }

  factory ProfileRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      isPrimary: serializer.fromJson<bool>(json['isPrimary']),
      bedtime: serializer.fromJson<String?>(json['bedtime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'colorValue': serializer.toJson<int>(colorValue),
      'isPrimary': serializer.toJson<bool>(isPrimary),
      'bedtime': serializer.toJson<String?>(bedtime),
    };
  }

  ProfileRow copyWith(
          {String? id,
          String? name,
          int? colorValue,
          bool? isPrimary,
          Value<String?> bedtime = const Value.absent()}) =>
      ProfileRow(
        id: id ?? this.id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
        isPrimary: isPrimary ?? this.isPrimary,
        bedtime: bedtime.present ? bedtime.value : this.bedtime,
      );
  ProfileRow copyWithCompanion(ProfilesCompanion data) {
    return ProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorValue:
          data.colorValue.present ? data.colorValue.value : this.colorValue,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
      bedtime: data.bedtime.present ? data.bedtime.value : this.bedtime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('bedtime: $bedtime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorValue, isPrimary, bedtime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorValue == this.colorValue &&
          other.isPrimary == this.isPrimary &&
          other.bedtime == this.bedtime);
}

class ProfilesCompanion extends UpdateCompanion<ProfileRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> colorValue;
  final Value<bool> isPrimary;
  final Value<String?> bedtime;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.bedtime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    required String name,
    required int colorValue,
    this.isPrimary = const Value.absent(),
    this.bedtime = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        colorValue = Value(colorValue);
  static Insertable<ProfileRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? colorValue,
    Expression<bool>? isPrimary,
    Expression<String>? bedtime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorValue != null) 'color_value': colorValue,
      if (isPrimary != null) 'is_primary': isPrimary,
      if (bedtime != null) 'bedtime': bedtime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<int>? colorValue,
      Value<bool>? isPrimary,
      Value<String?>? bedtime,
      Value<int>? rowid}) {
    return ProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      isPrimary: isPrimary ?? this.isPrimary,
      bedtime: bedtime ?? this.bedtime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<bool>(isPrimary.value);
    }
    if (bedtime.present) {
      map['bedtime'] = Variable<String>(bedtime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('bedtime: $bedtime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PrescriptionsTable extends Prescriptions
    with TableInfo<$PrescriptionsTable, PrescriptionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrescriptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _profileIdMeta =
      const VerificationMeta('profileId');
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
      'profile_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES profiles (id)'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dosageMeta = const VerificationMeta('dosage');
  @override
  late final GeneratedColumn<String> dosage = GeneratedColumn<String>(
      'dosage', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _strengthMeta =
      const VerificationMeta('strength');
  @override
  late final GeneratedColumn<String> strength = GeneratedColumn<String>(
      'strength', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _doseAmountMeta =
      const VerificationMeta('doseAmount');
  @override
  late final GeneratedColumn<String> doseAmount = GeneratedColumn<String>(
      'dose_amount', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _doseQuantityMeta =
      const VerificationMeta('doseQuantity');
  @override
  late final GeneratedColumn<int> doseQuantity = GeneratedColumn<int>(
      'dose_quantity', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _formMeta = const VerificationMeta('form');
  @override
  late final GeneratedColumn<String> form = GeneratedColumn<String>(
      'form', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _foodInstructionMeta =
      const VerificationMeta('foodInstruction');
  @override
  late final GeneratedColumn<String> foodInstruction = GeneratedColumn<String>(
      'food_instruction', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
      reminderTimes = GeneratedColumn<String>(
              'reminder_times', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<String>>(
              $PrescriptionsTable.$converterreminderTimes);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> takenTimes =
      GeneratedColumn<String>('taken_times', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<String>>(
              $PrescriptionsTable.$convertertakenTimes);
  static const VerificationMeta _remainingMeta =
      const VerificationMeta('remaining');
  @override
  late final GeneratedColumn<int> remaining = GeneratedColumn<int>(
      'remaining', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _daysSupplyMeta =
      const VerificationMeta('daysSupply');
  @override
  late final GeneratedColumn<int> daysSupply = GeneratedColumn<int>(
      'days_supply', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _refillsRemainingMeta =
      const VerificationMeta('refillsRemaining');
  @override
  late final GeneratedColumn<int> refillsRemaining = GeneratedColumn<int>(
      'refills_remaining', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _allowAfterBedtimeMeta =
      const VerificationMeta('allowAfterBedtime');
  @override
  late final GeneratedColumn<bool> allowAfterBedtime = GeneratedColumn<bool>(
      'allow_after_bedtime', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("allow_after_bedtime" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isAsNeededMeta =
      const VerificationMeta('isAsNeeded');
  @override
  late final GeneratedColumn<bool> isAsNeeded = GeneratedColumn<bool>(
      'is_as_needed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_as_needed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _cooldownMinutesMeta =
      const VerificationMeta('cooldownMinutes');
  @override
  late final GeneratedColumn<int> cooldownMinutes = GeneratedColumn<int>(
      'cooldown_minutes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        profileId,
        name,
        dosage,
        strength,
        doseAmount,
        doseQuantity,
        form,
        foodInstruction,
        reminderTimes,
        takenTimes,
        remaining,
        daysSupply,
        refillsRemaining,
        allowAfterBedtime,
        isAsNeeded,
        cooldownMinutes
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prescriptions';
  @override
  VerificationContext validateIntegrity(Insertable<PrescriptionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(_profileIdMeta,
          profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta));
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('dosage')) {
      context.handle(_dosageMeta,
          dosage.isAcceptableOrUnknown(data['dosage']!, _dosageMeta));
    } else if (isInserting) {
      context.missing(_dosageMeta);
    }
    if (data.containsKey('strength')) {
      context.handle(_strengthMeta,
          strength.isAcceptableOrUnknown(data['strength']!, _strengthMeta));
    }
    if (data.containsKey('dose_amount')) {
      context.handle(
          _doseAmountMeta,
          doseAmount.isAcceptableOrUnknown(
              data['dose_amount']!, _doseAmountMeta));
    }
    if (data.containsKey('dose_quantity')) {
      context.handle(
          _doseQuantityMeta,
          doseQuantity.isAcceptableOrUnknown(
              data['dose_quantity']!, _doseQuantityMeta));
    }
    if (data.containsKey('form')) {
      context.handle(
          _formMeta, form.isAcceptableOrUnknown(data['form']!, _formMeta));
    }
    if (data.containsKey('food_instruction')) {
      context.handle(
          _foodInstructionMeta,
          foodInstruction.isAcceptableOrUnknown(
              data['food_instruction']!, _foodInstructionMeta));
    }
    if (data.containsKey('remaining')) {
      context.handle(_remainingMeta,
          remaining.isAcceptableOrUnknown(data['remaining']!, _remainingMeta));
    } else if (isInserting) {
      context.missing(_remainingMeta);
    }
    if (data.containsKey('days_supply')) {
      context.handle(
          _daysSupplyMeta,
          daysSupply.isAcceptableOrUnknown(
              data['days_supply']!, _daysSupplyMeta));
    } else if (isInserting) {
      context.missing(_daysSupplyMeta);
    }
    if (data.containsKey('refills_remaining')) {
      context.handle(
          _refillsRemainingMeta,
          refillsRemaining.isAcceptableOrUnknown(
              data['refills_remaining']!, _refillsRemainingMeta));
    }
    if (data.containsKey('allow_after_bedtime')) {
      context.handle(
          _allowAfterBedtimeMeta,
          allowAfterBedtime.isAcceptableOrUnknown(
              data['allow_after_bedtime']!, _allowAfterBedtimeMeta));
    }
    if (data.containsKey('is_as_needed')) {
      context.handle(
          _isAsNeededMeta,
          isAsNeeded.isAcceptableOrUnknown(
              data['is_as_needed']!, _isAsNeededMeta));
    }
    if (data.containsKey('cooldown_minutes')) {
      context.handle(
          _cooldownMinutesMeta,
          cooldownMinutes.isAcceptableOrUnknown(
              data['cooldown_minutes']!, _cooldownMinutesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrescriptionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrescriptionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      profileId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}profile_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      dosage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dosage'])!,
      strength: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}strength']),
      doseAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dose_amount']),
      doseQuantity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}dose_quantity'])!,
      form: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}form']),
      foodInstruction: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}food_instruction']),
      reminderTimes: $PrescriptionsTable.$converterreminderTimes.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}reminder_times'])!),
      takenTimes: $PrescriptionsTable.$convertertakenTimes.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}taken_times'])!),
      remaining: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}remaining'])!,
      daysSupply: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}days_supply'])!,
      refillsRemaining: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}refills_remaining'])!,
      allowAfterBedtime: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}allow_after_bedtime'])!,
      isAsNeeded: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_as_needed'])!,
      cooldownMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cooldown_minutes']),
    );
  }

  @override
  $PrescriptionsTable createAlias(String alias) {
    return $PrescriptionsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterreminderTimes =
      const StringListConverter();
  static TypeConverter<List<String>, String> $convertertakenTimes =
      const StringListConverter();
}

class PrescriptionRow extends DataClass implements Insertable<PrescriptionRow> {
  final String id;
  final String profileId;
  final String name;
  final String dosage;
  final String? strength;
  final String? doseAmount;
  final int doseQuantity;
  final String? form;
  final String? foodInstruction;
  final List<String> reminderTimes;
  final List<String> takenTimes;
  final int remaining;
  final int daysSupply;
  final int refillsRemaining;
  final bool allowAfterBedtime;
  final bool isAsNeeded;
  final int? cooldownMinutes;
  const PrescriptionRow(
      {required this.id,
      required this.profileId,
      required this.name,
      required this.dosage,
      this.strength,
      this.doseAmount,
      required this.doseQuantity,
      this.form,
      this.foodInstruction,
      required this.reminderTimes,
      required this.takenTimes,
      required this.remaining,
      required this.daysSupply,
      required this.refillsRemaining,
      required this.allowAfterBedtime,
      required this.isAsNeeded,
      this.cooldownMinutes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['name'] = Variable<String>(name);
    map['dosage'] = Variable<String>(dosage);
    if (!nullToAbsent || strength != null) {
      map['strength'] = Variable<String>(strength);
    }
    if (!nullToAbsent || doseAmount != null) {
      map['dose_amount'] = Variable<String>(doseAmount);
    }
    map['dose_quantity'] = Variable<int>(doseQuantity);
    if (!nullToAbsent || form != null) {
      map['form'] = Variable<String>(form);
    }
    if (!nullToAbsent || foodInstruction != null) {
      map['food_instruction'] = Variable<String>(foodInstruction);
    }
    {
      map['reminder_times'] = Variable<String>(
          $PrescriptionsTable.$converterreminderTimes.toSql(reminderTimes));
    }
    {
      map['taken_times'] = Variable<String>(
          $PrescriptionsTable.$convertertakenTimes.toSql(takenTimes));
    }
    map['remaining'] = Variable<int>(remaining);
    map['days_supply'] = Variable<int>(daysSupply);
    map['refills_remaining'] = Variable<int>(refillsRemaining);
    map['allow_after_bedtime'] = Variable<bool>(allowAfterBedtime);
    map['is_as_needed'] = Variable<bool>(isAsNeeded);
    if (!nullToAbsent || cooldownMinutes != null) {
      map['cooldown_minutes'] = Variable<int>(cooldownMinutes);
    }
    return map;
  }

  PrescriptionsCompanion toCompanion(bool nullToAbsent) {
    return PrescriptionsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      name: Value(name),
      dosage: Value(dosage),
      strength: strength == null && nullToAbsent
          ? const Value.absent()
          : Value(strength),
      doseAmount: doseAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(doseAmount),
      doseQuantity: Value(doseQuantity),
      form: form == null && nullToAbsent ? const Value.absent() : Value(form),
      foodInstruction: foodInstruction == null && nullToAbsent
          ? const Value.absent()
          : Value(foodInstruction),
      reminderTimes: Value(reminderTimes),
      takenTimes: Value(takenTimes),
      remaining: Value(remaining),
      daysSupply: Value(daysSupply),
      refillsRemaining: Value(refillsRemaining),
      allowAfterBedtime: Value(allowAfterBedtime),
      isAsNeeded: Value(isAsNeeded),
      cooldownMinutes: cooldownMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(cooldownMinutes),
    );
  }

  factory PrescriptionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrescriptionRow(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      name: serializer.fromJson<String>(json['name']),
      dosage: serializer.fromJson<String>(json['dosage']),
      strength: serializer.fromJson<String?>(json['strength']),
      doseAmount: serializer.fromJson<String?>(json['doseAmount']),
      doseQuantity: serializer.fromJson<int>(json['doseQuantity']),
      form: serializer.fromJson<String?>(json['form']),
      foodInstruction: serializer.fromJson<String?>(json['foodInstruction']),
      reminderTimes: serializer.fromJson<List<String>>(json['reminderTimes']),
      takenTimes: serializer.fromJson<List<String>>(json['takenTimes']),
      remaining: serializer.fromJson<int>(json['remaining']),
      daysSupply: serializer.fromJson<int>(json['daysSupply']),
      refillsRemaining: serializer.fromJson<int>(json['refillsRemaining']),
      allowAfterBedtime: serializer.fromJson<bool>(json['allowAfterBedtime']),
      isAsNeeded: serializer.fromJson<bool>(json['isAsNeeded']),
      cooldownMinutes: serializer.fromJson<int?>(json['cooldownMinutes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'name': serializer.toJson<String>(name),
      'dosage': serializer.toJson<String>(dosage),
      'strength': serializer.toJson<String?>(strength),
      'doseAmount': serializer.toJson<String?>(doseAmount),
      'doseQuantity': serializer.toJson<int>(doseQuantity),
      'form': serializer.toJson<String?>(form),
      'foodInstruction': serializer.toJson<String?>(foodInstruction),
      'reminderTimes': serializer.toJson<List<String>>(reminderTimes),
      'takenTimes': serializer.toJson<List<String>>(takenTimes),
      'remaining': serializer.toJson<int>(remaining),
      'daysSupply': serializer.toJson<int>(daysSupply),
      'refillsRemaining': serializer.toJson<int>(refillsRemaining),
      'allowAfterBedtime': serializer.toJson<bool>(allowAfterBedtime),
      'isAsNeeded': serializer.toJson<bool>(isAsNeeded),
      'cooldownMinutes': serializer.toJson<int?>(cooldownMinutes),
    };
  }

  PrescriptionRow copyWith(
          {String? id,
          String? profileId,
          String? name,
          String? dosage,
          Value<String?> strength = const Value.absent(),
          Value<String?> doseAmount = const Value.absent(),
          int? doseQuantity,
          Value<String?> form = const Value.absent(),
          Value<String?> foodInstruction = const Value.absent(),
          List<String>? reminderTimes,
          List<String>? takenTimes,
          int? remaining,
          int? daysSupply,
          int? refillsRemaining,
          bool? allowAfterBedtime,
          bool? isAsNeeded,
          Value<int?> cooldownMinutes = const Value.absent()}) =>
      PrescriptionRow(
        id: id ?? this.id,
        profileId: profileId ?? this.profileId,
        name: name ?? this.name,
        dosage: dosage ?? this.dosage,
        strength: strength.present ? strength.value : this.strength,
        doseAmount: doseAmount.present ? doseAmount.value : this.doseAmount,
        doseQuantity: doseQuantity ?? this.doseQuantity,
        form: form.present ? form.value : this.form,
        foodInstruction: foodInstruction.present
            ? foodInstruction.value
            : this.foodInstruction,
        reminderTimes: reminderTimes ?? this.reminderTimes,
        takenTimes: takenTimes ?? this.takenTimes,
        remaining: remaining ?? this.remaining,
        daysSupply: daysSupply ?? this.daysSupply,
        refillsRemaining: refillsRemaining ?? this.refillsRemaining,
        allowAfterBedtime: allowAfterBedtime ?? this.allowAfterBedtime,
        isAsNeeded: isAsNeeded ?? this.isAsNeeded,
        cooldownMinutes: cooldownMinutes.present
            ? cooldownMinutes.value
            : this.cooldownMinutes,
      );
  PrescriptionRow copyWithCompanion(PrescriptionsCompanion data) {
    return PrescriptionRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      name: data.name.present ? data.name.value : this.name,
      dosage: data.dosage.present ? data.dosage.value : this.dosage,
      strength: data.strength.present ? data.strength.value : this.strength,
      doseAmount:
          data.doseAmount.present ? data.doseAmount.value : this.doseAmount,
      doseQuantity: data.doseQuantity.present
          ? data.doseQuantity.value
          : this.doseQuantity,
      form: data.form.present ? data.form.value : this.form,
      foodInstruction: data.foodInstruction.present
          ? data.foodInstruction.value
          : this.foodInstruction,
      reminderTimes: data.reminderTimes.present
          ? data.reminderTimes.value
          : this.reminderTimes,
      takenTimes:
          data.takenTimes.present ? data.takenTimes.value : this.takenTimes,
      remaining: data.remaining.present ? data.remaining.value : this.remaining,
      daysSupply:
          data.daysSupply.present ? data.daysSupply.value : this.daysSupply,
      refillsRemaining: data.refillsRemaining.present
          ? data.refillsRemaining.value
          : this.refillsRemaining,
      allowAfterBedtime: data.allowAfterBedtime.present
          ? data.allowAfterBedtime.value
          : this.allowAfterBedtime,
      isAsNeeded:
          data.isAsNeeded.present ? data.isAsNeeded.value : this.isAsNeeded,
      cooldownMinutes: data.cooldownMinutes.present
          ? data.cooldownMinutes.value
          : this.cooldownMinutes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrescriptionRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('name: $name, ')
          ..write('dosage: $dosage, ')
          ..write('strength: $strength, ')
          ..write('doseAmount: $doseAmount, ')
          ..write('doseQuantity: $doseQuantity, ')
          ..write('form: $form, ')
          ..write('foodInstruction: $foodInstruction, ')
          ..write('reminderTimes: $reminderTimes, ')
          ..write('takenTimes: $takenTimes, ')
          ..write('remaining: $remaining, ')
          ..write('daysSupply: $daysSupply, ')
          ..write('refillsRemaining: $refillsRemaining, ')
          ..write('allowAfterBedtime: $allowAfterBedtime, ')
          ..write('isAsNeeded: $isAsNeeded, ')
          ..write('cooldownMinutes: $cooldownMinutes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      profileId,
      name,
      dosage,
      strength,
      doseAmount,
      doseQuantity,
      form,
      foodInstruction,
      reminderTimes,
      takenTimes,
      remaining,
      daysSupply,
      refillsRemaining,
      allowAfterBedtime,
      isAsNeeded,
      cooldownMinutes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrescriptionRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.name == this.name &&
          other.dosage == this.dosage &&
          other.strength == this.strength &&
          other.doseAmount == this.doseAmount &&
          other.doseQuantity == this.doseQuantity &&
          other.form == this.form &&
          other.foodInstruction == this.foodInstruction &&
          other.reminderTimes == this.reminderTimes &&
          other.takenTimes == this.takenTimes &&
          other.remaining == this.remaining &&
          other.daysSupply == this.daysSupply &&
          other.refillsRemaining == this.refillsRemaining &&
          other.allowAfterBedtime == this.allowAfterBedtime &&
          other.isAsNeeded == this.isAsNeeded &&
          other.cooldownMinutes == this.cooldownMinutes);
}

class PrescriptionsCompanion extends UpdateCompanion<PrescriptionRow> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> name;
  final Value<String> dosage;
  final Value<String?> strength;
  final Value<String?> doseAmount;
  final Value<int> doseQuantity;
  final Value<String?> form;
  final Value<String?> foodInstruction;
  final Value<List<String>> reminderTimes;
  final Value<List<String>> takenTimes;
  final Value<int> remaining;
  final Value<int> daysSupply;
  final Value<int> refillsRemaining;
  final Value<bool> allowAfterBedtime;
  final Value<bool> isAsNeeded;
  final Value<int?> cooldownMinutes;
  final Value<int> rowid;
  const PrescriptionsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.name = const Value.absent(),
    this.dosage = const Value.absent(),
    this.strength = const Value.absent(),
    this.doseAmount = const Value.absent(),
    this.doseQuantity = const Value.absent(),
    this.form = const Value.absent(),
    this.foodInstruction = const Value.absent(),
    this.reminderTimes = const Value.absent(),
    this.takenTimes = const Value.absent(),
    this.remaining = const Value.absent(),
    this.daysSupply = const Value.absent(),
    this.refillsRemaining = const Value.absent(),
    this.allowAfterBedtime = const Value.absent(),
    this.isAsNeeded = const Value.absent(),
    this.cooldownMinutes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PrescriptionsCompanion.insert({
    required String id,
    required String profileId,
    required String name,
    required String dosage,
    this.strength = const Value.absent(),
    this.doseAmount = const Value.absent(),
    this.doseQuantity = const Value.absent(),
    this.form = const Value.absent(),
    this.foodInstruction = const Value.absent(),
    required List<String> reminderTimes,
    required List<String> takenTimes,
    required int remaining,
    required int daysSupply,
    this.refillsRemaining = const Value.absent(),
    this.allowAfterBedtime = const Value.absent(),
    this.isAsNeeded = const Value.absent(),
    this.cooldownMinutes = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        profileId = Value(profileId),
        name = Value(name),
        dosage = Value(dosage),
        reminderTimes = Value(reminderTimes),
        takenTimes = Value(takenTimes),
        remaining = Value(remaining),
        daysSupply = Value(daysSupply);
  static Insertable<PrescriptionRow> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? name,
    Expression<String>? dosage,
    Expression<String>? strength,
    Expression<String>? doseAmount,
    Expression<int>? doseQuantity,
    Expression<String>? form,
    Expression<String>? foodInstruction,
    Expression<String>? reminderTimes,
    Expression<String>? takenTimes,
    Expression<int>? remaining,
    Expression<int>? daysSupply,
    Expression<int>? refillsRemaining,
    Expression<bool>? allowAfterBedtime,
    Expression<bool>? isAsNeeded,
    Expression<int>? cooldownMinutes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (name != null) 'name': name,
      if (dosage != null) 'dosage': dosage,
      if (strength != null) 'strength': strength,
      if (doseAmount != null) 'dose_amount': doseAmount,
      if (doseQuantity != null) 'dose_quantity': doseQuantity,
      if (form != null) 'form': form,
      if (foodInstruction != null) 'food_instruction': foodInstruction,
      if (reminderTimes != null) 'reminder_times': reminderTimes,
      if (takenTimes != null) 'taken_times': takenTimes,
      if (remaining != null) 'remaining': remaining,
      if (daysSupply != null) 'days_supply': daysSupply,
      if (refillsRemaining != null) 'refills_remaining': refillsRemaining,
      if (allowAfterBedtime != null) 'allow_after_bedtime': allowAfterBedtime,
      if (isAsNeeded != null) 'is_as_needed': isAsNeeded,
      if (cooldownMinutes != null) 'cooldown_minutes': cooldownMinutes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PrescriptionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? profileId,
      Value<String>? name,
      Value<String>? dosage,
      Value<String?>? strength,
      Value<String?>? doseAmount,
      Value<int>? doseQuantity,
      Value<String?>? form,
      Value<String?>? foodInstruction,
      Value<List<String>>? reminderTimes,
      Value<List<String>>? takenTimes,
      Value<int>? remaining,
      Value<int>? daysSupply,
      Value<int>? refillsRemaining,
      Value<bool>? allowAfterBedtime,
      Value<bool>? isAsNeeded,
      Value<int?>? cooldownMinutes,
      Value<int>? rowid}) {
    return PrescriptionsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      strength: strength ?? this.strength,
      doseAmount: doseAmount ?? this.doseAmount,
      doseQuantity: doseQuantity ?? this.doseQuantity,
      form: form ?? this.form,
      foodInstruction: foodInstruction ?? this.foodInstruction,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      takenTimes: takenTimes ?? this.takenTimes,
      remaining: remaining ?? this.remaining,
      daysSupply: daysSupply ?? this.daysSupply,
      refillsRemaining: refillsRemaining ?? this.refillsRemaining,
      allowAfterBedtime: allowAfterBedtime ?? this.allowAfterBedtime,
      isAsNeeded: isAsNeeded ?? this.isAsNeeded,
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (dosage.present) {
      map['dosage'] = Variable<String>(dosage.value);
    }
    if (strength.present) {
      map['strength'] = Variable<String>(strength.value);
    }
    if (doseAmount.present) {
      map['dose_amount'] = Variable<String>(doseAmount.value);
    }
    if (doseQuantity.present) {
      map['dose_quantity'] = Variable<int>(doseQuantity.value);
    }
    if (form.present) {
      map['form'] = Variable<String>(form.value);
    }
    if (foodInstruction.present) {
      map['food_instruction'] = Variable<String>(foodInstruction.value);
    }
    if (reminderTimes.present) {
      map['reminder_times'] = Variable<String>($PrescriptionsTable
          .$converterreminderTimes
          .toSql(reminderTimes.value));
    }
    if (takenTimes.present) {
      map['taken_times'] = Variable<String>(
          $PrescriptionsTable.$convertertakenTimes.toSql(takenTimes.value));
    }
    if (remaining.present) {
      map['remaining'] = Variable<int>(remaining.value);
    }
    if (daysSupply.present) {
      map['days_supply'] = Variable<int>(daysSupply.value);
    }
    if (refillsRemaining.present) {
      map['refills_remaining'] = Variable<int>(refillsRemaining.value);
    }
    if (allowAfterBedtime.present) {
      map['allow_after_bedtime'] = Variable<bool>(allowAfterBedtime.value);
    }
    if (isAsNeeded.present) {
      map['is_as_needed'] = Variable<bool>(isAsNeeded.value);
    }
    if (cooldownMinutes.present) {
      map['cooldown_minutes'] = Variable<int>(cooldownMinutes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrescriptionsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('name: $name, ')
          ..write('dosage: $dosage, ')
          ..write('strength: $strength, ')
          ..write('doseAmount: $doseAmount, ')
          ..write('doseQuantity: $doseQuantity, ')
          ..write('form: $form, ')
          ..write('foodInstruction: $foodInstruction, ')
          ..write('reminderTimes: $reminderTimes, ')
          ..write('takenTimes: $takenTimes, ')
          ..write('remaining: $remaining, ')
          ..write('daysSupply: $daysSupply, ')
          ..write('refillsRemaining: $refillsRemaining, ')
          ..write('allowAfterBedtime: $allowAfterBedtime, ')
          ..write('isAsNeeded: $isAsNeeded, ')
          ..write('cooldownMinutes: $cooldownMinutes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DoseEventsTable extends DoseEvents
    with TableInfo<$DoseEventsTable, DoseEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DoseEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _prescriptionIdMeta =
      const VerificationMeta('prescriptionId');
  @override
  late final GeneratedColumn<String> prescriptionId = GeneratedColumn<String>(
      'prescription_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES prescriptions (id)'));
  static const VerificationMeta _profileIdMeta =
      const VerificationMeta('profileId');
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
      'profile_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES profiles (id)'));
  static const VerificationMeta _occurredAtMeta =
      const VerificationMeta('occurredAt');
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
      'occurred_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
      'action', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, prescriptionId, profileId, occurredAt, action];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dose_events';
  @override
  VerificationContext validateIntegrity(Insertable<DoseEventRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('prescription_id')) {
      context.handle(
          _prescriptionIdMeta,
          prescriptionId.isAcceptableOrUnknown(
              data['prescription_id']!, _prescriptionIdMeta));
    } else if (isInserting) {
      context.missing(_prescriptionIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(_profileIdMeta,
          profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta));
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
          _occurredAtMeta,
          occurredAt.isAcceptableOrUnknown(
              data['occurred_at']!, _occurredAtMeta));
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('action')) {
      context.handle(_actionMeta,
          action.isAcceptableOrUnknown(data['action']!, _actionMeta));
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DoseEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DoseEventRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      prescriptionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}prescription_id'])!,
      profileId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}profile_id'])!,
      occurredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}occurred_at'])!,
      action: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action'])!,
    );
  }

  @override
  $DoseEventsTable createAlias(String alias) {
    return $DoseEventsTable(attachedDatabase, alias);
  }
}

class DoseEventRow extends DataClass implements Insertable<DoseEventRow> {
  final String id;
  final String prescriptionId;
  final String profileId;
  final DateTime occurredAt;
  final String action;
  const DoseEventRow(
      {required this.id,
      required this.prescriptionId,
      required this.profileId,
      required this.occurredAt,
      required this.action});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['prescription_id'] = Variable<String>(prescriptionId);
    map['profile_id'] = Variable<String>(profileId);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['action'] = Variable<String>(action);
    return map;
  }

  DoseEventsCompanion toCompanion(bool nullToAbsent) {
    return DoseEventsCompanion(
      id: Value(id),
      prescriptionId: Value(prescriptionId),
      profileId: Value(profileId),
      occurredAt: Value(occurredAt),
      action: Value(action),
    );
  }

  factory DoseEventRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DoseEventRow(
      id: serializer.fromJson<String>(json['id']),
      prescriptionId: serializer.fromJson<String>(json['prescriptionId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      action: serializer.fromJson<String>(json['action']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'prescriptionId': serializer.toJson<String>(prescriptionId),
      'profileId': serializer.toJson<String>(profileId),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'action': serializer.toJson<String>(action),
    };
  }

  DoseEventRow copyWith(
          {String? id,
          String? prescriptionId,
          String? profileId,
          DateTime? occurredAt,
          String? action}) =>
      DoseEventRow(
        id: id ?? this.id,
        prescriptionId: prescriptionId ?? this.prescriptionId,
        profileId: profileId ?? this.profileId,
        occurredAt: occurredAt ?? this.occurredAt,
        action: action ?? this.action,
      );
  DoseEventRow copyWithCompanion(DoseEventsCompanion data) {
    return DoseEventRow(
      id: data.id.present ? data.id.value : this.id,
      prescriptionId: data.prescriptionId.present
          ? data.prescriptionId.value
          : this.prescriptionId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
      action: data.action.present ? data.action.value : this.action,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DoseEventRow(')
          ..write('id: $id, ')
          ..write('prescriptionId: $prescriptionId, ')
          ..write('profileId: $profileId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('action: $action')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, prescriptionId, profileId, occurredAt, action);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DoseEventRow &&
          other.id == this.id &&
          other.prescriptionId == this.prescriptionId &&
          other.profileId == this.profileId &&
          other.occurredAt == this.occurredAt &&
          other.action == this.action);
}

class DoseEventsCompanion extends UpdateCompanion<DoseEventRow> {
  final Value<String> id;
  final Value<String> prescriptionId;
  final Value<String> profileId;
  final Value<DateTime> occurredAt;
  final Value<String> action;
  final Value<int> rowid;
  const DoseEventsCompanion({
    this.id = const Value.absent(),
    this.prescriptionId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.action = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DoseEventsCompanion.insert({
    required String id,
    required String prescriptionId,
    required String profileId,
    required DateTime occurredAt,
    required String action,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        prescriptionId = Value(prescriptionId),
        profileId = Value(profileId),
        occurredAt = Value(occurredAt),
        action = Value(action);
  static Insertable<DoseEventRow> custom({
    Expression<String>? id,
    Expression<String>? prescriptionId,
    Expression<String>? profileId,
    Expression<DateTime>? occurredAt,
    Expression<String>? action,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (prescriptionId != null) 'prescription_id': prescriptionId,
      if (profileId != null) 'profile_id': profileId,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (action != null) 'action': action,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DoseEventsCompanion copyWith(
      {Value<String>? id,
      Value<String>? prescriptionId,
      Value<String>? profileId,
      Value<DateTime>? occurredAt,
      Value<String>? action,
      Value<int>? rowid}) {
    return DoseEventsCompanion(
      id: id ?? this.id,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      profileId: profileId ?? this.profileId,
      occurredAt: occurredAt ?? this.occurredAt,
      action: action ?? this.action,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (prescriptionId.present) {
      map['prescription_id'] = Variable<String>(prescriptionId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DoseEventsCompanion(')
          ..write('id: $id, ')
          ..write('prescriptionId: $prescriptionId, ')
          ..write('profileId: $profileId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('action: $action, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $PrescriptionsTable prescriptions = $PrescriptionsTable(this);
  late final $DoseEventsTable doseEvents = $DoseEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [profiles, prescriptions, doseEvents];
}

typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  required String id,
  required String name,
  required int colorValue,
  Value<bool> isPrimary,
  Value<String?> bedtime,
  Value<int> rowid,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> colorValue,
  Value<bool> isPrimary,
  Value<String?> bedtime,
  Value<int> rowid,
});

final class $$ProfilesTableReferences
    extends BaseReferences<_$AppDatabase, $ProfilesTable, ProfileRow> {
  $$ProfilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PrescriptionsTable, List<PrescriptionRow>>
      _prescriptionsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.prescriptions,
              aliasName: 'profiles__id__prescriptions__profile_id');

  $$PrescriptionsTableProcessedTableManager get prescriptionsRefs {
    final manager = $$PrescriptionsTableTableManager($_db, $_db.prescriptions)
        .filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_prescriptionsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$DoseEventsTable, List<DoseEventRow>>
      _doseEventsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.doseEvents,
              aliasName: 'profiles__id__dose_events__profile_id');

  $$DoseEventsTableProcessedTableManager get doseEventsRefs {
    final manager = $$DoseEventsTableTableManager($_db, $_db.doseEvents)
        .filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_doseEventsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get colorValue => $composableBuilder(
      column: $table.colorValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPrimary => $composableBuilder(
      column: $table.isPrimary, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bedtime => $composableBuilder(
      column: $table.bedtime, builder: (column) => ColumnFilters(column));

  Expression<bool> prescriptionsRefs(
      Expression<bool> Function($$PrescriptionsTableFilterComposer f) f) {
    final $$PrescriptionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.prescriptions,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PrescriptionsTableFilterComposer(
              $db: $db,
              $table: $db.prescriptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> doseEventsRefs(
      Expression<bool> Function($$DoseEventsTableFilterComposer f) f) {
    final $$DoseEventsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.doseEvents,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DoseEventsTableFilterComposer(
              $db: $db,
              $table: $db.doseEvents,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get colorValue => $composableBuilder(
      column: $table.colorValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPrimary => $composableBuilder(
      column: $table.isPrimary, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bedtime => $composableBuilder(
      column: $table.bedtime, builder: (column) => ColumnOrderings(column));
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
      column: $table.colorValue, builder: (column) => column);

  GeneratedColumn<bool> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => column);

  GeneratedColumn<String> get bedtime =>
      $composableBuilder(column: $table.bedtime, builder: (column) => column);

  Expression<T> prescriptionsRefs<T extends Object>(
      Expression<T> Function($$PrescriptionsTableAnnotationComposer a) f) {
    final $$PrescriptionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.prescriptions,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PrescriptionsTableAnnotationComposer(
              $db: $db,
              $table: $db.prescriptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> doseEventsRefs<T extends Object>(
      Expression<T> Function($$DoseEventsTableAnnotationComposer a) f) {
    final $$DoseEventsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.doseEvents,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DoseEventsTableAnnotationComposer(
              $db: $db,
              $table: $db.doseEvents,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProfilesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProfilesTable,
    ProfileRow,
    $$ProfilesTableFilterComposer,
    $$ProfilesTableOrderingComposer,
    $$ProfilesTableAnnotationComposer,
    $$ProfilesTableCreateCompanionBuilder,
    $$ProfilesTableUpdateCompanionBuilder,
    (ProfileRow, $$ProfilesTableReferences),
    ProfileRow,
    PrefetchHooks Function({bool prescriptionsRefs, bool doseEventsRefs})> {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> colorValue = const Value.absent(),
            Value<bool> isPrimary = const Value.absent(),
            Value<String?> bedtime = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProfilesCompanion(
            id: id,
            name: name,
            colorValue: colorValue,
            isPrimary: isPrimary,
            bedtime: bedtime,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required int colorValue,
            Value<bool> isPrimary = const Value.absent(),
            Value<String?> bedtime = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProfilesCompanion.insert(
            id: id,
            name: name,
            colorValue: colorValue,
            isPrimary: isPrimary,
            bedtime: bedtime,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ProfilesTable, ProfileRow>(table),
                    $$ProfilesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {prescriptionsRefs = false, doseEventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (prescriptionsRefs) db.prescriptions,
                if (doseEventsRefs) db.doseEvents
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (prescriptionsRefs)
                    await $_getPrefetchedData<ProfileRow, $ProfilesTable,
                            PrescriptionRow>(
                        currentTable: table,
                        referencedTable: $$ProfilesTableReferences
                            ._prescriptionsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProfilesTableReferences(db, table, p0)
                                .prescriptionsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.profileId == item.id),
                        typedResults: items),
                  if (doseEventsRefs)
                    await $_getPrefetchedData<ProfileRow, $ProfilesTable,
                            DoseEventRow>(
                        currentTable: table,
                        referencedTable:
                            $$ProfilesTableReferences._doseEventsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProfilesTableReferences(db, table, p0)
                                .doseEventsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.profileId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ProfilesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProfilesTable,
    ProfileRow,
    $$ProfilesTableFilterComposer,
    $$ProfilesTableOrderingComposer,
    $$ProfilesTableAnnotationComposer,
    $$ProfilesTableCreateCompanionBuilder,
    $$ProfilesTableUpdateCompanionBuilder,
    (ProfileRow, $$ProfilesTableReferences),
    ProfileRow,
    PrefetchHooks Function({bool prescriptionsRefs, bool doseEventsRefs})>;
typedef $$PrescriptionsTableCreateCompanionBuilder = PrescriptionsCompanion
    Function({
  required String id,
  required String profileId,
  required String name,
  required String dosage,
  Value<String?> strength,
  Value<String?> doseAmount,
  Value<int> doseQuantity,
  Value<String?> form,
  Value<String?> foodInstruction,
  required List<String> reminderTimes,
  required List<String> takenTimes,
  required int remaining,
  required int daysSupply,
  Value<int> refillsRemaining,
  Value<bool> allowAfterBedtime,
  Value<bool> isAsNeeded,
  Value<int?> cooldownMinutes,
  Value<int> rowid,
});
typedef $$PrescriptionsTableUpdateCompanionBuilder = PrescriptionsCompanion
    Function({
  Value<String> id,
  Value<String> profileId,
  Value<String> name,
  Value<String> dosage,
  Value<String?> strength,
  Value<String?> doseAmount,
  Value<int> doseQuantity,
  Value<String?> form,
  Value<String?> foodInstruction,
  Value<List<String>> reminderTimes,
  Value<List<String>> takenTimes,
  Value<int> remaining,
  Value<int> daysSupply,
  Value<int> refillsRemaining,
  Value<bool> allowAfterBedtime,
  Value<bool> isAsNeeded,
  Value<int?> cooldownMinutes,
  Value<int> rowid,
});

final class $$PrescriptionsTableReferences extends BaseReferences<_$AppDatabase,
    $PrescriptionsTable, PrescriptionRow> {
  $$PrescriptionsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$AppDatabase db) =>
      db.profiles.createAlias('prescriptions__profile_id__profiles__id');

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<String>('profile_id')!;

    final manager = $$ProfilesTableTableManager($_db, $_db.profiles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$DoseEventsTable, List<DoseEventRow>>
      _doseEventsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.doseEvents,
              aliasName: 'prescriptions__id__dose_events__prescription_id');

  $$DoseEventsTableProcessedTableManager get doseEventsRefs {
    final manager = $$DoseEventsTableTableManager($_db, $_db.doseEvents).filter(
        (f) => f.prescriptionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_doseEventsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PrescriptionsTableFilterComposer
    extends Composer<_$AppDatabase, $PrescriptionsTable> {
  $$PrescriptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dosage => $composableBuilder(
      column: $table.dosage, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get strength => $composableBuilder(
      column: $table.strength, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get doseAmount => $composableBuilder(
      column: $table.doseAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get doseQuantity => $composableBuilder(
      column: $table.doseQuantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get form => $composableBuilder(
      column: $table.form, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get foodInstruction => $composableBuilder(
      column: $table.foodInstruction,
      builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
      get reminderTimes => $composableBuilder(
          column: $table.reminderTimes,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
      get takenTimes => $composableBuilder(
          column: $table.takenTimes,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get remaining => $composableBuilder(
      column: $table.remaining, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get daysSupply => $composableBuilder(
      column: $table.daysSupply, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get refillsRemaining => $composableBuilder(
      column: $table.refillsRemaining,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get allowAfterBedtime => $composableBuilder(
      column: $table.allowAfterBedtime,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isAsNeeded => $composableBuilder(
      column: $table.isAsNeeded, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cooldownMinutes => $composableBuilder(
      column: $table.cooldownMinutes,
      builder: (column) => ColumnFilters(column));

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableFilterComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> doseEventsRefs(
      Expression<bool> Function($$DoseEventsTableFilterComposer f) f) {
    final $$DoseEventsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.doseEvents,
        getReferencedColumn: (t) => t.prescriptionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DoseEventsTableFilterComposer(
              $db: $db,
              $table: $db.doseEvents,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PrescriptionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PrescriptionsTable> {
  $$PrescriptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dosage => $composableBuilder(
      column: $table.dosage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get strength => $composableBuilder(
      column: $table.strength, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get doseAmount => $composableBuilder(
      column: $table.doseAmount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get doseQuantity => $composableBuilder(
      column: $table.doseQuantity,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get form => $composableBuilder(
      column: $table.form, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get foodInstruction => $composableBuilder(
      column: $table.foodInstruction,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reminderTimes => $composableBuilder(
      column: $table.reminderTimes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get takenTimes => $composableBuilder(
      column: $table.takenTimes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get remaining => $composableBuilder(
      column: $table.remaining, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get daysSupply => $composableBuilder(
      column: $table.daysSupply, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get refillsRemaining => $composableBuilder(
      column: $table.refillsRemaining,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get allowAfterBedtime => $composableBuilder(
      column: $table.allowAfterBedtime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isAsNeeded => $composableBuilder(
      column: $table.isAsNeeded, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cooldownMinutes => $composableBuilder(
      column: $table.cooldownMinutes,
      builder: (column) => ColumnOrderings(column));

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableOrderingComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PrescriptionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PrescriptionsTable> {
  $$PrescriptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get dosage =>
      $composableBuilder(column: $table.dosage, builder: (column) => column);

  GeneratedColumn<String> get strength =>
      $composableBuilder(column: $table.strength, builder: (column) => column);

  GeneratedColumn<String> get doseAmount => $composableBuilder(
      column: $table.doseAmount, builder: (column) => column);

  GeneratedColumn<int> get doseQuantity => $composableBuilder(
      column: $table.doseQuantity, builder: (column) => column);

  GeneratedColumn<String> get form =>
      $composableBuilder(column: $table.form, builder: (column) => column);

  GeneratedColumn<String> get foodInstruction => $composableBuilder(
      column: $table.foodInstruction, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get reminderTimes =>
      $composableBuilder(
          column: $table.reminderTimes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get takenTimes =>
      $composableBuilder(
          column: $table.takenTimes, builder: (column) => column);

  GeneratedColumn<int> get remaining =>
      $composableBuilder(column: $table.remaining, builder: (column) => column);

  GeneratedColumn<int> get daysSupply => $composableBuilder(
      column: $table.daysSupply, builder: (column) => column);

  GeneratedColumn<int> get refillsRemaining => $composableBuilder(
      column: $table.refillsRemaining, builder: (column) => column);

  GeneratedColumn<bool> get allowAfterBedtime => $composableBuilder(
      column: $table.allowAfterBedtime, builder: (column) => column);

  GeneratedColumn<bool> get isAsNeeded => $composableBuilder(
      column: $table.isAsNeeded, builder: (column) => column);

  GeneratedColumn<int> get cooldownMinutes => $composableBuilder(
      column: $table.cooldownMinutes, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> doseEventsRefs<T extends Object>(
      Expression<T> Function($$DoseEventsTableAnnotationComposer a) f) {
    final $$DoseEventsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.doseEvents,
        getReferencedColumn: (t) => t.prescriptionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DoseEventsTableAnnotationComposer(
              $db: $db,
              $table: $db.doseEvents,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PrescriptionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PrescriptionsTable,
    PrescriptionRow,
    $$PrescriptionsTableFilterComposer,
    $$PrescriptionsTableOrderingComposer,
    $$PrescriptionsTableAnnotationComposer,
    $$PrescriptionsTableCreateCompanionBuilder,
    $$PrescriptionsTableUpdateCompanionBuilder,
    (PrescriptionRow, $$PrescriptionsTableReferences),
    PrescriptionRow,
    PrefetchHooks Function({bool profileId, bool doseEventsRefs})> {
  $$PrescriptionsTableTableManager(_$AppDatabase db, $PrescriptionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrescriptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrescriptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrescriptionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> profileId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> dosage = const Value.absent(),
            Value<String?> strength = const Value.absent(),
            Value<String?> doseAmount = const Value.absent(),
            Value<int> doseQuantity = const Value.absent(),
            Value<String?> form = const Value.absent(),
            Value<String?> foodInstruction = const Value.absent(),
            Value<List<String>> reminderTimes = const Value.absent(),
            Value<List<String>> takenTimes = const Value.absent(),
            Value<int> remaining = const Value.absent(),
            Value<int> daysSupply = const Value.absent(),
            Value<int> refillsRemaining = const Value.absent(),
            Value<bool> allowAfterBedtime = const Value.absent(),
            Value<bool> isAsNeeded = const Value.absent(),
            Value<int?> cooldownMinutes = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PrescriptionsCompanion(
            id: id,
            profileId: profileId,
            name: name,
            dosage: dosage,
            strength: strength,
            doseAmount: doseAmount,
            doseQuantity: doseQuantity,
            form: form,
            foodInstruction: foodInstruction,
            reminderTimes: reminderTimes,
            takenTimes: takenTimes,
            remaining: remaining,
            daysSupply: daysSupply,
            refillsRemaining: refillsRemaining,
            allowAfterBedtime: allowAfterBedtime,
            isAsNeeded: isAsNeeded,
            cooldownMinutes: cooldownMinutes,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String profileId,
            required String name,
            required String dosage,
            Value<String?> strength = const Value.absent(),
            Value<String?> doseAmount = const Value.absent(),
            Value<int> doseQuantity = const Value.absent(),
            Value<String?> form = const Value.absent(),
            Value<String?> foodInstruction = const Value.absent(),
            required List<String> reminderTimes,
            required List<String> takenTimes,
            required int remaining,
            required int daysSupply,
            Value<int> refillsRemaining = const Value.absent(),
            Value<bool> allowAfterBedtime = const Value.absent(),
            Value<bool> isAsNeeded = const Value.absent(),
            Value<int?> cooldownMinutes = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PrescriptionsCompanion.insert(
            id: id,
            profileId: profileId,
            name: name,
            dosage: dosage,
            strength: strength,
            doseAmount: doseAmount,
            doseQuantity: doseQuantity,
            form: form,
            foodInstruction: foodInstruction,
            reminderTimes: reminderTimes,
            takenTimes: takenTimes,
            remaining: remaining,
            daysSupply: daysSupply,
            refillsRemaining: refillsRemaining,
            allowAfterBedtime: allowAfterBedtime,
            isAsNeeded: isAsNeeded,
            cooldownMinutes: cooldownMinutes,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PrescriptionsTable, PrescriptionRow>(table),
                    $$PrescriptionsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({profileId = false, doseEventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (doseEventsRefs) db.doseEvents],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (profileId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.profileId,
                    referencedTable:
                        $$PrescriptionsTableReferences._profileIdTable(db),
                    referencedColumn:
                        $$PrescriptionsTableReferences._profileIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (doseEventsRefs)
                    await $_getPrefetchedData<PrescriptionRow,
                            $PrescriptionsTable, DoseEventRow>(
                        currentTable: table,
                        referencedTable: $$PrescriptionsTableReferences
                            ._doseEventsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PrescriptionsTableReferences(db, table, p0)
                                .doseEventsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.prescriptionId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PrescriptionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PrescriptionsTable,
    PrescriptionRow,
    $$PrescriptionsTableFilterComposer,
    $$PrescriptionsTableOrderingComposer,
    $$PrescriptionsTableAnnotationComposer,
    $$PrescriptionsTableCreateCompanionBuilder,
    $$PrescriptionsTableUpdateCompanionBuilder,
    (PrescriptionRow, $$PrescriptionsTableReferences),
    PrescriptionRow,
    PrefetchHooks Function({bool profileId, bool doseEventsRefs})>;
typedef $$DoseEventsTableCreateCompanionBuilder = DoseEventsCompanion Function({
  required String id,
  required String prescriptionId,
  required String profileId,
  required DateTime occurredAt,
  required String action,
  Value<int> rowid,
});
typedef $$DoseEventsTableUpdateCompanionBuilder = DoseEventsCompanion Function({
  Value<String> id,
  Value<String> prescriptionId,
  Value<String> profileId,
  Value<DateTime> occurredAt,
  Value<String> action,
  Value<int> rowid,
});

final class $$DoseEventsTableReferences
    extends BaseReferences<_$AppDatabase, $DoseEventsTable, DoseEventRow> {
  $$DoseEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PrescriptionsTable _prescriptionIdTable(_$AppDatabase db) =>
      db.prescriptions
          .createAlias('dose_events__prescription_id__prescriptions__id');

  $$PrescriptionsTableProcessedTableManager get prescriptionId {
    final $_column = $_itemColumn<String>('prescription_id')!;

    final manager = $$PrescriptionsTableTableManager($_db, $_db.prescriptions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_prescriptionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ProfilesTable _profileIdTable(_$AppDatabase db) =>
      db.profiles.createAlias('dose_events__profile_id__profiles__id');

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<String>('profile_id')!;

    final manager = $$ProfilesTableTableManager($_db, $_db.profiles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$DoseEventsTableFilterComposer
    extends Composer<_$AppDatabase, $DoseEventsTable> {
  $$DoseEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnFilters(column));

  $$PrescriptionsTableFilterComposer get prescriptionId {
    final $$PrescriptionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.prescriptionId,
        referencedTable: $db.prescriptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PrescriptionsTableFilterComposer(
              $db: $db,
              $table: $db.prescriptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableFilterComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DoseEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $DoseEventsTable> {
  $$DoseEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnOrderings(column));

  $$PrescriptionsTableOrderingComposer get prescriptionId {
    final $$PrescriptionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.prescriptionId,
        referencedTable: $db.prescriptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PrescriptionsTableOrderingComposer(
              $db: $db,
              $table: $db.prescriptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableOrderingComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DoseEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DoseEventsTable> {
  $$DoseEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  $$PrescriptionsTableAnnotationComposer get prescriptionId {
    final $$PrescriptionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.prescriptionId,
        referencedTable: $db.prescriptions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PrescriptionsTableAnnotationComposer(
              $db: $db,
              $table: $db.prescriptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DoseEventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DoseEventsTable,
    DoseEventRow,
    $$DoseEventsTableFilterComposer,
    $$DoseEventsTableOrderingComposer,
    $$DoseEventsTableAnnotationComposer,
    $$DoseEventsTableCreateCompanionBuilder,
    $$DoseEventsTableUpdateCompanionBuilder,
    (DoseEventRow, $$DoseEventsTableReferences),
    DoseEventRow,
    PrefetchHooks Function({bool prescriptionId, bool profileId})> {
  $$DoseEventsTableTableManager(_$AppDatabase db, $DoseEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DoseEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DoseEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DoseEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> prescriptionId = const Value.absent(),
            Value<String> profileId = const Value.absent(),
            Value<DateTime> occurredAt = const Value.absent(),
            Value<String> action = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DoseEventsCompanion(
            id: id,
            prescriptionId: prescriptionId,
            profileId: profileId,
            occurredAt: occurredAt,
            action: action,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String prescriptionId,
            required String profileId,
            required DateTime occurredAt,
            required String action,
            Value<int> rowid = const Value.absent(),
          }) =>
              DoseEventsCompanion.insert(
            id: id,
            prescriptionId: prescriptionId,
            profileId: profileId,
            occurredAt: occurredAt,
            action: action,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$DoseEventsTable, DoseEventRow>(table),
                    $$DoseEventsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({prescriptionId = false, profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (prescriptionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.prescriptionId,
                    referencedTable:
                        $$DoseEventsTableReferences._prescriptionIdTable(db),
                    referencedColumn:
                        $$DoseEventsTableReferences._prescriptionIdTable(db).id,
                  ) as T;
                }
                if (profileId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.profileId,
                    referencedTable:
                        $$DoseEventsTableReferences._profileIdTable(db),
                    referencedColumn:
                        $$DoseEventsTableReferences._profileIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$DoseEventsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DoseEventsTable,
    DoseEventRow,
    $$DoseEventsTableFilterComposer,
    $$DoseEventsTableOrderingComposer,
    $$DoseEventsTableAnnotationComposer,
    $$DoseEventsTableCreateCompanionBuilder,
    $$DoseEventsTableUpdateCompanionBuilder,
    (DoseEventRow, $$DoseEventsTableReferences),
    DoseEventRow,
    PrefetchHooks Function({bool prescriptionId, bool profileId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$PrescriptionsTableTableManager get prescriptions =>
      $$PrescriptionsTableTableManager(_db, _db.prescriptions);
  $$DoseEventsTableTableManager get doseEvents =>
      $$DoseEventsTableTableManager(_db, _db.doseEvents);
}
