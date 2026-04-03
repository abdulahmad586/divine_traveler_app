import 'package:flutter/material.dart';
import 'package:quran/quran.dart';
import 'package:tahfeex/widgets/app_dialog.dart';
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/service/repositories/journey_repository.dart';
import 'package:tahfeex/shared/models/models.dart';

class CreateJourneyScreen extends StatefulWidget {
  const CreateJourneyScreen({super.key});

  @override
  State<CreateJourneyScreen> createState() => _CreateJourneyScreenState();
}

class _CreateJourneyScreenState extends State<CreateJourneyScreen> {
  final _repo = JourneyRepository();
  final _titleController = TextEditingController();

  // Dimensions
  final _dims = <String>{};

  // Range
  int _startSurah = 1;
  int _startAyah = 1;
  int _endSurah = 1;
  int _endAyah = 7;

  // Dates
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  // UI state
  bool _isSubmitting = false;
  String? _formError;
  bool _allowJoining = false;

  static const _dimensionOptions = [
    ('read', 'Read'),
    ('memorize', 'Memorize'),
    ('translate', 'Translate'),
    ('commentary', 'Commentary'),
  ];

  // ── Derived ──────────────────────────────────────────────────────────────

  String get _autoTitle {
    if (_dims.isEmpty) return '';
    final label = _dims.map((d) {
      return switch (d) {
        'read' => 'Read',
        'memorize' => 'Memorize',
        'translate' => 'Translate',
        'commentary' => 'Commentary',
        _ => d,
      };
    }).join(', ');
    return '$label: Surah $_startSurah:$_startAyah → Surah $_endSurah:$_endAyah';
  }

  bool get _rangeValid =>
      journeyLinearIndex(_endSurah, _endAyah) >
      journeyLinearIndex(_startSurah, _startAyah);

  int get _coverageAyahs {
    if (!_rangeValid) return 0;
    return journeyLinearIndex(_endSurah, _endAyah) -
        journeyLinearIndex(_startSurah, _startAyah) +
        1;
  }

  int get _coverageSurahs => _endSurah - _startSurah + 1;

  // ── Validation ────────────────────────────────────────────────────────────

  String? _validate() {
    if (_dims.isEmpty) return 'Please select at least one dimension.';
    if (!_rangeValid) return 'End position must come after the start.';
    if (!_endDate.isAfter(_startDate)) {
      return 'End date must be after the start date.';
    }
    return null;
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      setState(() => _formError = error);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _formError = null;
    });

    try {
      await _repo.createJourney(
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        dimensions: _dims.toList(),
        startSurah: _startSurah,
        startAyah: _startAyah,
        endSurah: _endSurah,
        endAyah: _endAyah,
        startDate: _startDate,
        endDate: _endDate,
        allowJoining: _allowJoining,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      String msg;
      if (e.isMaxActiveJourneys) {
        msg = '';
        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => AppDialog(
              title: 'Journey limit reached',
              body: "You've reached the maximum of 5 active journeys. "
                  'Complete or abandon one before starting a new one.',
              actions: [
                AppDialogAction(
                    label: 'OK',
                    isPrimary: true,
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
          );
        }
      } else {
        msg = e.message;
      }
      if (mounted && msg.isNotEmpty) {
        setState(() => _formError = msg);
      }
    } catch (e) {
      if (mounted) setState(() => _formError = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Date pickers ──────────────────────────────────────────────────────────

  Future<void> _pickStartDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        _startDate = d;
        if (!_endDate.isAfter(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 30));
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _endDate.isAfter(_startDate)
          ? _endDate
          : _startDate.add(const Duration(days: 1)),
      firstDate: _startDate.add(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _endDate = d);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Journey')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ──────────────────────────────────────────────────────
            _sectionLabel('Title'),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'e.g. Ramadan 2026 Plan',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_titleController.text.trim().isEmpty && _autoTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Text(
                  'Auto-title: $_autoTitle',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 24),

            // ── Dimensions ─────────────────────────────────────────────────
            _sectionLabel('What will you study?'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _dimensionOptions.map((option) {
                final value = option.$1;
                final label = option.$2;
                final selected = _dims.contains(value);
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  selectedColor: AppColors.primaryColor.withOpacity(0.2),
                  checkmarkColor: AppColors.primaryColor,
                  onSelected: (on) {
                    setState(() {
                      on ? _dims.add(value) : _dims.remove(value);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Range ──────────────────────────────────────────────────────
            _sectionLabel('Verse range'),
            Row(
              children: [
                Expanded(
                  child: _SurahAyahPicker(
                    label: 'Start',
                    surah: _startSurah,
                    ayah: _startAyah,
                    onChanged: (s, a) => setState(() {
                      _startSurah = s;
                      _startAyah = a;
                    }),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child:
                      Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
                ),
                Expanded(
                  child: _SurahAyahPicker(
                    label: 'End',
                    surah: _endSurah,
                    ayah: _endAyah,
                    onChanged: (s, a) => setState(() {
                      _endSurah = s;
                      _endAyah = a;
                    }),
                  ),
                ),
              ],
            ),
            if (!_rangeValid && _dims.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'End must come after the start.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
            if (_rangeValid)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'This journey covers $_coverageAyahs ayahs across '
                  '$_coverageSurahs surah${_coverageSurahs == 1 ? '' : 's'}.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ),
            const SizedBox(height: 24),

            // ── Dates ──────────────────────────────────────────────────────
            _sectionLabel('Duration'),
            Row(
              children: [
                Expanded(
                  child: _DateTile(
                    label: 'Start date',
                    date: _startDate,
                    onTap: _pickStartDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateTile(
                    label: 'Target end date',
                    date: _endDate,
                    onTap: _pickEndDate,
                  ),
                ),
              ],
            ),
            if (!_endDate.isAfter(_startDate))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'End date must be after the start date.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 24),

            // ── Allow joining ──────────────────────────────────────────────
            _sectionLabel('Group journey'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Open to companions',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(
                _allowJoining
                    ? 'Your companions can join this journey.'
                    : 'Only you will participate.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              value: _allowJoining,
              activeColor: AppColors.primaryColor,
              onChanged: (v) => setState(() => _allowJoining = v),
            ),
            const SizedBox(height: 4),

            // ── Form error ─────────────────────────────────────────────────
            if (_formError != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(_formError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),

            // ── Submit ─────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Create Journey',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey[500],
            letterSpacing: 0.8,
          ),
        ),
      );

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Surah + Ayah two-part picker
// ─────────────────────────────────────────────────────────────────────────────

class _SurahAyahPicker extends StatelessWidget {
  final String label;
  final int surah;
  final int ayah;
  final void Function(int surah, int ayah) onChanged;

  const _SurahAyahPicker({
    required this.label,
    required this.surah,
    required this.ayah,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final maxAyah = ayahCounts[surah];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          value: surah,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Surah',
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(),
          ),
          items: List.generate(114, (i) {
            final s = i + 1;
            return DropdownMenuItem(
              value: s,
              child: Text('$s · ${getSurahName(s)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13)),
            );
          }),
          onChanged: (s) {
            if (s == null) return;
            final clampedAyah = ayah.clamp(1, ayahCounts[s]);
            onChanged(s, clampedAyah);
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: ayah.clamp(1, maxAyah),
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Ayah',
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(),
          ),
          items: List.generate(maxAyah, (i) {
            final a = i + 1;
            return DropdownMenuItem(
              value: a,
              child: Text('$a', style: const TextStyle(fontSize: 13)),
            );
          }),
          onChanged: (a) {
            if (a == null) return;
            onChanged(surah, a);
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date tile
// ─────────────────────────────────────────────────────────────────────────────

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateTile(
      {required this.label, required this.date, required this.onTap});

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppColors.primaryColor),
                const SizedBox(width: 4),
                Text(
                  '${date.day} ${_months[date.month - 1]} ${date.year}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
