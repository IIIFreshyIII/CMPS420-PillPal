import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/ner/postprocess.dart' show formOptions;
import '../../core/theme/pillpal_colors.dart';
import '../../presentation/widgets/pressable.dart';

/// Default quick-pick medication types shown as top-level chips.
const List<String> kDefaultMedicationTypes = [
  'Pill / Oral',
  'Liquid',
  'Inhaler',
  'Injection',
  'Topical',
];

String _titleCase(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Builds the full alphabetized list of secondary medication types shown in the
/// "Other" searchable bottom sheet, combining canonical OCR forms with common
/// clinical routes/forms and excluding [primaryOptions].
List<String> buildOtherMedicationTypes({
  List<String> primaryOptions = kDefaultMedicationTypes,
}) {
  final primaryLower = primaryOptions.map((e) => e.toLowerCase()).toSet();
  final combined = <String>{
    ...formOptions.map(_titleCase),
    'Sublingual',
    'Transdermal Patch',
    'Eye Drops',
    'Ear Drops',
    'Nasal Spray',
    'Suppository',
    'Lozenge',
  }..removeWhere((e) => primaryLower.contains(e.toLowerCase()));

  final sorted = combined.toList()..sort();
  return sorted;
}

/// Horizontal swipeable row with left/right chevron scroll buttons when content
/// overflows horizontally.
class HorizontalChevronScrollRow extends StatefulWidget {
  const HorizontalChevronScrollRow({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  State<HorizontalChevronScrollRow> createState() =>
      _HorizontalChevronScrollRowState();
}

class _HorizontalChevronScrollRowState
    extends State<HorizontalChevronScrollRow> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final canLeft = pos.pixels > 4.0;
    final canRight = pos.pixels < (pos.maxScrollExtent - 4.0);
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scroll(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Stack(
      alignment: Alignment.center,
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(children: widget.children),
        ),
        if (_canScrollLeft)
          Positioned(
            left: 0,
            child: Pressable(
              scale: 0.85,
              onTap: () => _scroll(-130),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: c.surface.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
                child: Icon(
                  CupertinoIcons.chevron_left,
                  size: 14,
                  color: c.ink,
                ),
              ),
            ),
          ),
        if (_canScrollRight)
          Positioned(
            right: 0,
            child: Pressable(
              scale: 0.85,
              onTap: () => _scroll(130),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: c.surface.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(-1, 1),
                    ),
                  ],
                ),
                child: Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: c.ink,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

IconData _iconForMedicationType(String type) {
  return switch (type.toLowerCase()) {
    'pill / oral' => CupertinoIcons.capsule_fill,
    'liquid' => CupertinoIcons.drop_fill,
    'inhaler' => CupertinoIcons.wind,
    'injection' => Icons.vaccines_rounded,
    'topical' => CupertinoIcons.bandage_fill,
    _ => CupertinoIcons.ellipsis_circle,
  };
}

/// Horizontal chip selector for medication type/form with a quick-pick row
/// (including `Topical`) and an `Other` chip that opens a searchable modal
/// sheet with all additional types and custom text entry.
class MedicationTypeSelector extends StatelessWidget {
  const MedicationTypeSelector({
    super.key,
    required this.selectedType,
    required this.onSelected,
    this.primaryOptions = kDefaultMedicationTypes,
  });

  final String? selectedType;
  final ValueChanged<String> onSelected;
  final List<String> primaryOptions;

  bool get _hasCustomOrOtherSelected {
    final current = selectedType?.trim();
    if (current == null || current.isEmpty) return false;
    return !primaryOptions.any(
      (opt) => opt.toLowerCase() == current.toLowerCase(),
    );
  }

  Future<void> _openOtherSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OtherMedicationTypeSheet(
        initialSelection: selectedType,
        options: buildOtherMedicationTypes(primaryOptions: primaryOptions),
      ),
    );
    if (picked != null && picked.trim().isNotEmpty) {
      onSelected(picked.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final otherSelected = _hasCustomOrOtherSelected;
    final otherLabel =
        otherSelected ? 'Other: ${_titleCase(selectedType!)}' : 'Other';

    return HorizontalChevronScrollRow(
      children: [
        ...primaryOptions.map((opt) {
          final isSelected =
              selectedType?.toLowerCase() == opt.toLowerCase();
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _TypeChip(
              key: Key('med_type_chip_${opt.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}'),
              label: opt,
              leadingIcon: _iconForMedicationType(opt),
              selected: isSelected,
              onTap: () => onSelected(opt),
            ),
          );
        }),
        _TypeChip(
          key: const Key('med_type_chip_other'),
          label: otherLabel,
          leadingIcon: CupertinoIcons.ellipsis_circle,
          selected: otherSelected,
          trailingIcon: CupertinoIcons.chevron_down,
          onTap: () => _openOtherSheet(context),
          selectedBg: c.teal.withValues(alpha: 0.16),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leadingIcon,
    this.trailingIcon,
    this.selectedBg,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final Color? selectedBg;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final activeBg = selectedBg ?? c.teal.withValues(alpha: 0.16);
    final borderCol = selected ? c.teal : c.borderLight;

    return Pressable(
      scale: 0.95,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? activeBg : c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderCol,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              Icon(
                leadingIcon,
                size: 14,
                color: selected ? c.teal : c.inkMuted,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? c.teal : c.ink,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 4),
              Icon(
                trailingIcon,
                size: 12,
                color: selected ? c.teal : c.inkMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OtherMedicationTypeSheet extends StatefulWidget {
  const _OtherMedicationTypeSheet({
    required this.initialSelection,
    required this.options,
  });

  final String? initialSelection;
  final List<String> options;

  @override
  State<_OtherMedicationTypeSheet> createState() =>
      _OtherMedicationTypeSheetState();
}

class _OtherMedicationTypeSheetState extends State<_OtherMedicationTypeSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final trimmed = _query.trim();
    final lowerQuery = trimmed.toLowerCase();

    final filtered = trimmed.isEmpty
        ? widget.options
        : widget.options
            .where((o) => o.toLowerCase().contains(lowerQuery))
            .toList();

    final hasExactMatch = widget.options.any(
      (o) => o.toLowerCase() == lowerQuery,
    );
    final showCustomRow = trimmed.isNotEmpty && !hasExactMatch;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: c.borderLight)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.grabber,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Other Medication Type',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: c.inkMuted,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  key: const Key('medication_type_search_field'),
                  controller: _searchController,
                  autofocus: false,
                  textInputAction: TextInputAction.done,
                  onChanged: (val) => setState(() => _query = val),
                  onSubmitted: (val) {
                    final custom = val.trim();
                    if (custom.isNotEmpty) {
                      Navigator.of(context).pop(custom);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Search types or enter your own...',
                    hintStyle: TextStyle(color: c.inkMuted, fontSize: 14),
                    prefixIcon: Icon(
                      CupertinoIcons.search,
                      color: c.inkMuted,
                      size: 18,
                    ),
                    suffixIcon: trimmed.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: Icon(
                              CupertinoIcons.clear_circled_solid,
                              color: c.inkMuted,
                              size: 18,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: c.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: c.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: c.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: c.teal, width: 1.5),
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: c.borderLight),
              Flexible(
                child: Material(
                  type: MaterialType.transparency,
                  child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    if (showCustomRow)
                      ListTile(
                        key: const Key('medication_type_custom_option'),
                        leading: Icon(
                          CupertinoIcons.add_circled_solid,
                          color: c.teal,
                        ),
                        title: Text(
                          'Use "$trimmed"',
                          style: TextStyle(
                            color: c.teal,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Custom medication type',
                          style: TextStyle(color: c.inkMuted, fontSize: 12),
                        ),
                        onTap: () => Navigator.of(context).pop(trimmed),
                      ),
                    ...filtered.map((opt) {
                      final isSelected =
                          widget.initialSelection?.toLowerCase() ==
                              opt.toLowerCase();
                      return ListTile(
                        title: Text(
                          opt,
                          style: TextStyle(
                            color: isSelected ? c.teal : c.ink,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                CupertinoIcons.checkmark_alt,
                                color: c.teal,
                                size: 18,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(opt),
                      );
                    }),
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
