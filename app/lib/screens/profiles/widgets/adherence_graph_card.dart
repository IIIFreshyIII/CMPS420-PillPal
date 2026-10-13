import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/pillpal_colors.dart';
import '../../../core/utils/adherence_calculator.dart';
import '../../../data/models/dose_event.dart';

class AdherenceGraphCard extends StatefulWidget {
  final List<DoseEvent> doseEvents;
  final String? selectedProfileId;
  final DateTime? now;

  const AdherenceGraphCard({
    super.key,
    required this.doseEvents,
    this.selectedProfileId,
    this.now,
  });

  @override
  State<AdherenceGraphCard> createState() => _AdherenceGraphCardState();
}

class _AdherenceGraphCardState extends State<AdherenceGraphCard> {
  AdherenceTimeRange _selectedRange = AdherenceTimeRange.sevenDays;
  int? _selectedBucketIndex;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final summary = AdherenceCalculator.calculate(
      events: widget.doseEvents,
      range: _selectedRange,
      selectedProfileId: widget.selectedProfileId,
      now: widget.now,
    );

    // If active bucket index is out of bounds due to range switch, clamp or reset
    final selectedBucket = (_selectedBucketIndex != null &&
            _selectedBucketIndex! < summary.buckets.length)
        ? summary.buckets[_selectedBucketIndex!]
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.borderLight),
        boxShadow: [
          BoxShadow(
            color: c.cardShadow,
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Section label + Range segmented buttons
          Row(
            children: [
              Expanded(
                child: Text(
                  'CONSISTENCY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: c.inkMuted,
                  ),
                ),
              ),
              _buildRangeSelector(context),
            ],
          ),
          const SizedBox(height: 16),

          // Percentage Stat & Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                summary.totalLogged == 0 ? '—' : '${summary.adherencePercentage}%',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: summary.totalLogged == 0
                      ? c.neutralChip
                      : summary.adherencePercentage >= 85
                          ? c.tint
                          : summary.adherencePercentage >= 70
                              ? c.profileAmber.withValues(alpha: 0.15)
                              : c.alertTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      summary.totalLogged == 0
                          ? CupertinoIcons.clock
                          : summary.adherencePercentage >= 85
                              ? CupertinoIcons.checkmark_seal_fill
                              : summary.adherencePercentage >= 70
                                  ? CupertinoIcons.chart_bar_fill
                                  : CupertinoIcons.exclamationmark_triangle_fill,
                      size: 13,
                      color: summary.totalLogged == 0
                          ? c.inkMuted
                          : summary.adherencePercentage >= 85
                              ? c.tealDeep
                              : summary.adherencePercentage >= 70
                                  ? c.profileAmber
                                  : c.alert,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      summary.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: summary.totalLogged == 0
                            ? c.inkMuted
                            : summary.adherencePercentage >= 85
                                ? c.tealDeep
                                : summary.adherencePercentage >= 70
                                    ? c.profileAmber
                                    : c.alert,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            summary.statusMessage,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: c.inkMuted,
            ),
          ),
          const SizedBox(height: 16),

          // Legend chips
          _buildLegend(context, summary),
          const SizedBox(height: 20),

          // Bar Chart Visualization
          _buildChart(context, summary),

          // Inspector detail pill on bar tap
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: selectedBucket != null
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: selectedBucket != null
                ? Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.tint.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.mint.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedBucket.fullLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.tealDeep,
                          ),
                        ),
                        Text(
                          selectedBucket.totalCount == 0
                              ? 'No logs'
                              : '${selectedBucket.onTimeCount} On Time • ${selectedBucket.lateCount} Late • ${selectedBucket.skippedCount} Skipped',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.segmentTrack,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: AdherenceTimeRange.values.map((range) {
          final isSelected = range == _selectedRange;
          return GestureDetector(
            onTap: () {
              if (range != _selectedRange) {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedRange = range;
                  _selectedBucketIndex = null;
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? c.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: c.cardShadow,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                range.shortLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? c.ink : c.inkMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLegend(BuildContext context, AdherenceSummary summary) {
    final c = context.colors;
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _LegendItem(
          color: c.teal,
          label: 'On Time (${summary.onTimeCount})',
        ),
        _LegendItem(
          color: c.profileAmber,
          label: 'Late (${summary.lateCount})',
        ),
        _LegendItem(
          color: c.alert,
          label: 'Skipped (${summary.skippedCount})',
        ),
      ],
    );
  }

  Widget _buildChart(BuildContext context, AdherenceSummary summary) {
    final c = context.colors;
    final buckets = summary.buckets;
    if (buckets.isEmpty) return const SizedBox.shrink();

    // Determine max count in any single bucket for proportional height
    int maxInBucket = 1;
    for (final b in buckets) {
      if (b.totalCount > maxInBucket) {
        maxInBucket = b.totalCount;
      }
    }

    const double chartHeight = 110.0;

    return SizedBox(
      height: chartHeight + 28, // height for bars + labels
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(buckets.length, (index) {
          final bucket = buckets[index];
          final isSelected = _selectedBucketIndex == index;
          final total = bucket.totalCount;

          // Height of this bar relative to maxInBucket
          final double barHeight = total == 0
              ? 18.0
              : ((total / maxInBucket) * (chartHeight - 20) + 20).clamp(24.0, chartHeight);

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedBucketIndex = isSelected ? null : index;
                });
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // The rounded bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    height: barHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: c.tealDeep, width: 2.0)
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: total == 0
                        ? Container(
                            decoration: BoxDecoration(
                              color: c.neutralChip.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          )
                        : Column(
                            verticalDirection: VerticalDirection.up,
                            children: [
                              // On Time segment (bottom)
                              if (bucket.onTimeCount > 0)
                                Expanded(
                                  flex: bucket.onTimeCount,
                                  child: Container(color: c.teal),
                                ),
                              // Late segment (middle)
                              if (bucket.lateCount > 0)
                                Expanded(
                                  flex: bucket.lateCount,
                                  child: Container(color: c.profileAmber),
                                ),
                              // Skipped segment (top)
                              if (bucket.skippedCount > 0)
                                Expanded(
                                  flex: bucket.skippedCount,
                                  child: Container(color: c.alert),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 8),

                  // Bottom label
                  Text(
                    bucket.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: bucket.isCurrent || isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: bucket.isCurrent
                          ? c.tealDeep
                          : isSelected
                              ? c.ink
                              : c.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c.inkMuted,
          ),
        ),
      ],
    );
  }
}
