import 'package:flutter/material.dart';
import 'package:quran/quran.dart';
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/screens/create_journey_screen.dart';
import 'package:tahfeex/service/repositories/journey_repository.dart';
import 'package:tahfeex/shared/constants/constants.dart';
import 'package:tahfeex/shared/models/models.dart';
import 'package:tahfeex/shared/progression/user_progression.dart';
import 'package:tahfeex/widgets/app_route.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Template definitions
// ─────────────────────────────────────────────────────────────────────────────

class _Template {
  final String name;
  final String description;
  final String commitment;
  final List<String> dimensions;
  final int ayahsPerDay;

  const _Template({
    required this.name,
    required this.description,
    required this.commitment,
    required this.dimensions,
    required this.ayahsPerDay,
  });

  DateTime deadline(DateTime start, int totalAyahs) {
    final days = (totalAyahs / ayahsPerDay).ceil().clamp(1, 3650);
    return start.add(Duration(days: days));
  }
}

const _templates = [
  _Template(
    name: 'Daily Reading',
    description: 'A steady reading habit — work through your chosen range one ayah at a time.',
    commitment: '5 ayahs/day',
    dimensions: ['read'],
    ayahsPerDay: 5,
  ),
  _Template(
    name: 'Memorization Path',
    description: 'Focused memorization with audio. Slower pace, deeper retention.',
    commitment: '3 ayahs/day',
    dimensions: ['memorize'],
    ayahsPerDay: 3,
  ),
  _Template(
    name: 'Deep Study',
    description: 'Read with commentary. Understand the meaning alongside the words.',
    commitment: '2 ayahs/day',
    dimensions: ['read', 'commentary'],
    ayahsPerDay: 2,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Template selection screen
// ─────────────────────────────────────────────────────────────────────────────

class JourneyTemplateScreen extends StatelessWidget {
  /// Pass the user's journey list so we can check if they have a completed
  /// journey (which unlocks the "Customize instead" link).
  final List<Journey> existingJourneys;

  const JourneyTemplateScreen({
    super.key,
    required this.existingJourneys,
  });

  bool get _hasCompletedJourney =>
      existingJourneys.any((j) => j.status == 'completed');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start a Journey')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding, 24,
            AppSizes.pagePadding, 40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a path',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pick one to get started. You can always adjust later.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // ── Template cards ─────────────────────────────────────────────
              for (int i = 0; i < _templates.length; i++) ...[
                _TemplateCard(
                  template: _templates[i],
                  onTap: () => _openRangePicker(context, _templates[i]),
                ),
                if (i < _templates.length - 1)
                  const SizedBox(height: 12),
              ],

              // ── Customize link (locked for new users) ──────────────────────
              if (_hasCompletedJourney) ...[
                const SizedBox(height: 32),
                Center(
                  child: TextButton(
                    onPressed: () async {
                      final created = await Navigator.push<bool>(
                        context,
                        AppRoute(
                            builder: (_) => const CreateJourneyScreen()),
                      );
                      if (created == true && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text(
                      'Customize instead',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openRangePicker(BuildContext context, _Template template) {
    Navigator.push<bool>(
      context,
      AppRoute(
        builder: (_) => _RangePickerScreen(template: template),
      ),
    ).then((created) {
      if (created == true && context.mounted) {
        Navigator.pop(context, true);
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template card
// ─────────────────────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final _Template template;
  final VoidCallback onTap;

  const _TemplateCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          border: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    template.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      template.commitment,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Minimal range picker
// ─────────────────────────────────────────────────────────────────────────────

class _RangePickerScreen extends StatefulWidget {
  final _Template template;
  const _RangePickerScreen({required this.template});

  @override
  State<_RangePickerScreen> createState() => _RangePickerScreenState();
}

class _RangePickerScreenState extends State<_RangePickerScreen> {
  final _repo = JourneyRepository();

  int _startSurah = 1;
  int _startAyah  = 1;
  int _endSurah   = 1;
  int _endAyah    = 7;

  bool _submitting    = false;
  bool _showPace      = false;
  DateTime? _customDeadline;
  String? _error;

  bool get _rangeValid =>
      journeyLinearIndex(_endSurah, _endAyah) >
      journeyLinearIndex(_startSurah, _startAyah);

  int get _totalAyahs {
    if (!_rangeValid) return 0;
    return journeyLinearIndex(_endSurah, _endAyah) -
        journeyLinearIndex(_startSurah, _startAyah) +
        1;
  }

  DateTime get _autoDeadline =>
      widget.template.deadline(DateTime.now(), _totalAyahs);

  DateTime get _effectiveDeadline => _customDeadline ?? _autoDeadline;

  /// Human-readable duration label shown in the summary card.
  String get _durationLabel {
    if (!_rangeValid) return '—';
    final days = _effectiveDeadline.difference(DateTime.now()).inDays;
    if (_customDeadline != null) return _fmtDate(_effectiveDeadline);
    if (days < 7) return '$days days';
    final weeks = (days / 7).ceil();
    if (weeks < 5) return '$weeks weeks';
    return '${(days / 30).ceil()} months';
  }

  String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveDeadline,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _customDeadline = picked);
    }
  }

  Future<void> _submit() async {
    if (!_rangeValid) {
      setState(() => _error = 'End position must come after the start.');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    final start = DateTime.now();
    final end   = _effectiveDeadline;
    final title = '${widget.template.name}: ${getSurahName(_startSurah)} → ${getSurahName(_endSurah)}';

    try {
      await _repo.createJourney(
        title: title,
        dimensions: widget.template.dimensions,
        startSurah: _startSurah,
        startAyah: _startAyah,
        endSurah: _endSurah,
        endAyah: _endAyah,
        startDate: start,
        endDate: end,
        allowJoining: false,
      );
      UserProgression().setJourneyStarted();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isMaxActiveJourneys) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Journey limit reached'),
            content: const Text(
              "You've reached the maximum of 5 active journeys. "
              'Complete or abandon one before starting a new one.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK')),
            ],
          ),
        );
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.template.name)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.pagePadding, 24,
                  AppSizes.pagePadding, 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Start ────────────────────────────────────────────────
                    _SectionLabel('Starting from'),
                    const SizedBox(height: 10),
                    _SurahAyahRow(
                      surah: _startSurah,
                      ayah: _startAyah,
                      onSurahChanged: (s) => setState(() {
                        _startSurah = s;
                        _startAyah  = 1;
                      }),
                      onAyahChanged: (a) => setState(() => _startAyah = a),
                    ),

                    const SizedBox(height: 24),

                    // ── End ──────────────────────────────────────────────────
                    _SectionLabel('Ending at'),
                    const SizedBox(height: 10),
                    _SurahAyahRow(
                      surah: _endSurah,
                      ayah: _endAyah,
                      onSurahChanged: (s) => setState(() {
                        _endSurah = s;
                        _endAyah  = getVerseCount(s);
                      }),
                      onAyahChanged: (a) => setState(() => _endAyah = a),
                    ),

                    const SizedBox(height: 28),

                    // ── Summary card ─────────────────────────────────────────
                    if (_rangeValid) ...[
                      _SummaryCard(
                        template: widget.template,
                        totalAyahs: _totalAyahs,
                        durationLabel: _durationLabel,
                        isCustomDeadline: _customDeadline != null,
                      ),
                      const SizedBox(height: 12),

                      // ── Collapsible pace adjuster ──────────────────────────
                      _PaceAdjustHeader(
                        expanded: _showPace,
                        customDeadline: _customDeadline,
                        autoDeadline: _autoDeadline,
                        onToggle: () => setState(() => _showPace = !_showPace),
                        onClear: () => setState(() => _customDeadline = null),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        child: _showPace
                            ? _PaceAdjustBody(
                                deadline: _effectiveDeadline,
                                autoDeadline: _autoDeadline,
                                isCustom: _customDeadline != null,
                                onPickDate: _pickDeadline,
                                onClear: () => setState(() => _customDeadline = null),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),

            // ── CTA ──────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding, 12,
                AppSizes.pagePadding, 24,
              ),
              child: SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.buttonRadius),
                    ),
                    elevation: 0,
                  ),
                  onPressed: (_submitting || !_rangeValid) ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Begin Journey',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Range picker sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      );
}

class _SurahAyahRow extends StatelessWidget {
  final int surah;
  final int ayah;
  final ValueChanged<int> onSurahChanged;
  final ValueChanged<int> onAyahChanged;

  const _SurahAyahRow({
    required this.surah,
    required this.ayah,
    required this.onSurahChanged,
    required this.onAyahChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ayahCount = getVerseCount(surah);
    return Row(
      children: [
        // Surah dropdown
        Expanded(
          flex: 3,
          child: _PickerDropdown<int>(
            label: 'Surah',
            value: surah,
            items: List.generate(
              114,
              (i) => DropdownMenuItem(
                value: i + 1,
                child: Text(
                  '${i + 1}. ${getSurahName(i + 1)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            onChanged: (v) { if (v != null) onSurahChanged(v); },
          ),
        ),
        const SizedBox(width: 10),
        // Ayah dropdown
        Expanded(
          flex: 2,
          child: _PickerDropdown<int>(
            label: 'Ayah',
            value: ayah.clamp(1, ayahCount),
            items: List.generate(
              ayahCount,
              (i) => DropdownMenuItem(
                value: i + 1,
                child: Text('${i + 1}'),
              ),
            ),
            onChanged: (v) { if (v != null) onAyahChanged(v); },
          ),
        ),
      ],
    );
  }
}

class _PickerDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _PickerDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(10),
            border: const Border.fromBorderSide(
                BorderSide(color: AppColors.border)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final _Template template;
  final int totalAyahs;
  final String durationLabel;
  final bool isCustomDeadline;

  const _SummaryCard({
    required this.template,
    required this.totalAyahs,
    required this.durationLabel,
    required this.isCustomDeadline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryRow(label: 'Total ayahs', value: '$totalAyahs'),
          const SizedBox(height: 6),
          _SummaryRow(label: 'Daily pace', value: template.commitment),
          const SizedBox(height: 6),
          _SummaryRow(
            label: isCustomDeadline ? 'Deadline' : 'Estimated duration',
            value: durationLabel,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pace adjuster — collapsed header + expandable body
// ─────────────────────────────────────────────────────────────────────────────

class _PaceAdjustHeader extends StatelessWidget {
  final bool expanded;
  final DateTime? customDeadline;
  final DateTime autoDeadline;
  final VoidCallback onToggle;
  final VoidCallback onClear;

  const _PaceAdjustHeader({
    required this.expanded,
    required this.customDeadline,
    required this.autoDeadline,
    required this.onToggle,
    required this.onClear,
  });

  String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = customDeadline != null;
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.tune_outlined,
              size: 16,
              color: isCustom ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isCustom
                    ? 'Timeline: ${_fmtDate(customDeadline!)}'
                    : 'Adjust timeline',
                style: TextStyle(
                  fontSize: 13,
                  color: isCustom ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isCustom ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            if (isCustom)
              GestureDetector(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Text(
                    'Reset',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: const Icon(Icons.keyboard_arrow_down,
                  size: 18, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaceAdjustBody extends StatelessWidget {
  final DateTime deadline;
  final DateTime autoDeadline;
  final bool isCustom;
  final VoidCallback onPickDate;
  final VoidCallback onClear;

  const _PaceAdjustBody({
    required this.deadline,
    required this.autoDeadline,
    required this.isCustom,
    required this.onPickDate,
    required this.onClear,
  });

  String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: const Border.fromBorderSide(
            BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Target end date',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onPickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCustom
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: isCustom
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _fmtDate(deadline),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isCustom
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    isCustom ? 'custom' : 'auto',
                    style: TextStyle(
                      fontSize: 11,
                      color: isCustom
                          ? AppColors.primaryMuted
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCustom) ...[
            const SizedBox(height: 8),
            Text(
              'Default would be ${_fmtDate(autoDeadline)}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ],
    );
  }
}
