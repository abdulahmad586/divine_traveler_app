import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran/quran.dart';
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/screens/audio_training_screen.dart';
import 'package:tahfeex/screens/community_audio_picker.dart';
import 'package:tahfeex/screens/new_audio_screen.dart';
import 'package:tahfeex/screens/scholar_audio_picker.dart';
import 'package:tahfeex/screens/tafseer_screen.dart';
import 'package:tahfeex/service/app_storage.dart';
import 'package:tahfeex/service/repositories/journey_repository.dart';
import 'package:tahfeex/shared/constants/constants.dart';
import 'package:tahfeex/shared/models/models.dart';
import 'package:tahfeex/shared/progression/user_progression.dart';
import 'package:tahfeex/widgets/widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

enum _ViewMode { ayahCentric, pageContext }

class QuranJourneyScreen extends StatefulWidget {
  final String journeyId;
  const QuranJourneyScreen({super.key, required this.journeyId});

  @override
  State<QuranJourneyScreen> createState() => _QuranJourneyScreenState();
}

class _QuranJourneyScreenState extends State<QuranJourneyScreen> {
  final _repo = JourneyRepository();

  Journey? _journey;
  JourneyMember? _myMember;
  bool _loading = true;
  String? _error;

  int _surah = 1;
  int _ayah = 1;
  _ViewMode _viewMode = _ViewMode.ayahCentric;
  bool _completing = false;

  // Phase 3 state
  bool _glowing = false;
  bool _showAudio = false;
  bool _showTafsir = false;

  @override
  void initState() {
    super.initState();
    _loadJourney();
  }

  Future<void> _loadJourney() async {
    setState(() { _loading = true; _error = null; });
    try {
      final journey  = await _repo.getJourneyById(widget.journeyId);
      final myUid    = FirebaseAuth.instance.currentUser?.uid ?? '';
      final myMember = journey.memberFor(myUid);
      final first    = _firstIncomplete(journey, myMember);
      setState(() {
        _journey    = journey;
        _myMember   = myMember;
        _loading    = false;
        _surah      = first?.$1 ?? journey.endSurah;
        _ayah       = first?.$2 ?? journey.endAyah;
        _showAudio  = journey.dimensions.contains('memorize');
        _showTafsir = journey.dimensions.contains('commentary');
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  /// Returns the first ayah that has not been completed, or null if all done.
  (int, int)? _firstIncomplete(Journey j, JourneyMember? member) {
    if (member == null) return (j.startSurah, j.startAyah);
    for (int s = j.startSurah; s <= j.endSurah; s++) {
      final minA = s == j.startSurah ? j.startAyah : 1;
      final maxA = s == j.endSurah   ? j.endAyah   : ayahCounts[s];
      for (int a = minA; a <= maxA; a++) {
        if (!member.isAyahDone(s, a)) return (s, a);
      }
    }
    return null;
  }

  bool get _isFirstAyah    => _surah == _journey!.startSurah && _ayah == _journey!.startAyah;
  bool get _isLastAyah     => _surah == _journey!.endSurah   && _ayah == _journey!.endAyah;

  void _prevAyah() {
    if (_journey == null || _isFirstAyah) return;
    setState(() {
      final minA = _surah == _journey!.startSurah ? _journey!.startAyah : 1;
      if (_ayah > minA) {
        _ayah--;
      } else {
        _surah--;
        _ayah = _surah == _journey!.endSurah ? _journey!.endAyah : ayahCounts[_surah];
      }
    });
  }

  void _nextAyah() {
    if (_journey == null || _isLastAyah) return;
    setState(() {
      final maxA = _surah == _journey!.endSurah ? _journey!.endAyah : ayahCounts[_surah];
      if (_ayah < maxA) {
        _ayah++;
      } else {
        _surah++;
        _ayah = _surah == _journey!.startSurah ? _journey!.startAyah : 1;
      }
    });
  }

  void _triggerGlow() {
    setState(() => _glowing = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _glowing = false);
    });
  }

  Future<void> _markComplete() async {
    if (_completing || _journey == null || _myMember?.isActionable != true) return;
    HapticFeedback.lightImpact();
    _triggerGlow();
    setState(() => _completing = true);
    try {
      final updated = await _repo.updateProgress(
        id: widget.journeyId,
        surah: _surah,
        ayah: _ayah,
      );
      if (!mounted) return;
      UserProgression().recordActivity();
      final myUid      = FirebaseAuth.instance.currentUser?.uid ?? '';
      final wasLast    = _isLastAyah;
      final updatedMember = updated.memberFor(myUid);
      setState(() {
        _journey  = updated;
        _myMember = updatedMember;
        _completing = false;
      });
      if (updatedMember?.isCompleted == true) {
        UserProgression().setJourneyCompleted();
        _showCompletionDialog();
      } else if (!wasLast) {
        _nextAyah();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _completing = false);
      if (e.isJourneyCompleted) {
        UserProgression().setJourneyCompleted();
        _showCompletionDialog();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) setState(() => _completing = false);
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Journey Complete!'),
        content: Text(
          'You have completed "${_journey?.title ?? 'this journey'}". Well done!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // dialog
              Navigator.pop(context); // journey screen → back to caller
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton(
                    onPressed: _loadJourney, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final j = _journey!;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          getSurahName(_surah),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_viewMode == _ViewMode.pageContext)
            TextButton(
              onPressed: () => setState(() => _viewMode = _ViewMode.ayahCentric),
              child: const Text('Ayah view',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _viewMode == _ViewMode.ayahCentric
            ? _AyahCentricView(
                key: ValueKey('${_surah}_$_ayah'),
                journey: j,
                myMember: _myMember,
                surah: _surah,
                ayah: _ayah,
                onPrev: _isFirstAyah ? null : _prevAyah,
                onNext: _isLastAyah  ? null : _nextAyah,
                glowing: _glowing,
                showAudio: _showAudio,
                showTafsir: _showTafsir,
                isCompleting: _completing,
                pageUnlocked: UserProgression().hasCompletedFirstAyah,
                onToggleAudio: () => setState(() => _showAudio = !_showAudio),
                onToggleTafsir: () => setState(() => _showTafsir = !_showTafsir),
                onSwitchToPage: () => setState(() => _viewMode = _ViewMode.pageContext),
                onMarkComplete: _markComplete,
              )
            : _PageContextView(
                key: const ValueKey('page'),
                journey: j,
                myMember: _myMember,
                surah: _surah,
                ayah: _ayah,
                onSelectAyah: (s, a) => setState(() { _surah = s; _ayah = a; }),
                onBackToAyah: () => setState(() => _viewMode = _ViewMode.ayahCentric),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ayah-centric view
// ─────────────────────────────────────────────────────────────────────────────

class _AyahCentricView extends StatelessWidget {
  final Journey journey;
  final JourneyMember? myMember;
  final int surah;
  final int ayah;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool glowing;
  final bool showAudio;
  final bool showTafsir;
  final bool isCompleting;
  final bool pageUnlocked;
  final VoidCallback onToggleAudio;
  final VoidCallback onToggleTafsir;
  final VoidCallback onSwitchToPage;
  final VoidCallback? onMarkComplete;

  const _AyahCentricView({
    super.key,
    required this.journey,
    required this.myMember,
    required this.surah,
    required this.ayah,
    this.onPrev,
    this.onNext,
    required this.glowing,
    required this.showAudio,
    required this.showTafsir,
    required this.isCompleting,
    required this.pageUnlocked,
    required this.onToggleAudio,
    required this.onToggleTafsir,
    required this.onSwitchToPage,
    this.onMarkComplete,
  });

  bool get _isDone       => myMember?.isAyahDone(surah, ayah) ?? false;
  bool get _isActionable => myMember?.isActionable ?? false;
  int  get _completed    => myMember?.completedCount ?? 0;
  int  get _total        => journey.totalAyahs;

  @override
  Widget build(BuildContext context) {
    final dims = journey.dimensions;

    return Column(
      children: [
        // ── Slim progress bar ──────────────────────────────────────────────
        _ProgressHeader(completed: _completed, total: _total),

        // ── Main scrollable content ────────────────────────────────────────
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v < -300) onNext?.call();
              if (v >  300) onPrev?.call();
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding, 16,
                AppSizes.pagePadding, 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Ayah card ──────────────────────────────────────────
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                      border: Border.all(
                        color: glowing ? AppColors.gold : AppColors.border,
                        width: glowing ? 2.0 : 1.0,
                      ),
                      boxShadow: glowing
                          ? [BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.25),
                              blurRadius: 12,
                              spreadRadius: 2,
                            )]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Surah name + ayah number + done badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    getSurahName(surah),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Ayah $ayah',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_isDone) const _DoneBadge(),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Arabic text
                        if (dims.contains('read'))
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              getVerse(surah, ayah),
                              textAlign: TextAlign.right,
                              style: GoogleFonts.lateef(
                                textStyle: const TextStyle(
                                  fontSize: 32,
                                  color: AppColors.textPrimary,
                                  height: 2.0,
                                ),
                              ),
                            ),
                          ),

                        // Divider between Arabic and translation
                        if (dims.contains('read') && dims.contains('translate'))
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(color: AppColors.border, height: 1),
                          ),

                        // Translation
                        if (dims.contains('translate'))
                          Text(
                            getVerseTranslation(surah, ayah,
                                translation: Translation.enSaheeh),
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.7,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── Inline audio ─────────────────────────────────────────
                  if (showAudio) ...[
                    const SizedBox(height: 12),
                    _JourneyAudioPlayer(
                      key: ValueKey('audio_${surah}_$ayah'),
                      surah: surah,
                      ayah: ayah,
                    ),
                  ],

                  // ── Inline tafsir ─────────────────────────────────────────
                  if (showTafsir) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                        border: const Border.fromBorderSide(
                            BorderSide(color: AppColors.border)),
                      ),
                      child: CommentarySection(
                          surahNumber: surah, ayahNumber: ayah),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // ── Bottom controls ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding, 8,
            AppSizes.pagePadding, 16,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Prev / Next
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: onPrev,
                    icon: Icon(
                      Icons.chevron_left,
                      color: onPrev != null
                          ? AppColors.textSecondary
                          : AppColors.border,
                      size: 28,
                    ),
                  ),
                  IconButton(
                    onPressed: onNext,
                    icon: Icon(
                      Icons.chevron_right,
                      color: onNext != null
                          ? AppColors.textSecondary
                          : AppColors.border,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Mark Complete button
              if (_isActionable && !_isDone)
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    onPressed: isCompleting ? null : onMarkComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.buttonRadius),
                      ),
                      elevation: 0,
                    ),
                    child: isCompleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Mark Complete',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),

              // Already done nudge
              if (_isActionable && _isDone)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: AppColors.gold),
                      const SizedBox(width: 6),
                      Text(
                        onNext != null ? 'Done — swipe or tap › to continue' : 'All done',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Secondary actions row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SecondaryAction(
                    icon: Icons.volume_up_outlined,
                    label: 'Audio',
                    active: showAudio,
                    onTap: onToggleAudio,
                  ),
                  const SizedBox(width: 32),
                  _SecondaryAction(
                    icon: Icons.menu_book_outlined,
                    label: 'Tafsir',
                    active: showTafsir,
                    onTap: onToggleTafsir,
                  ),
                  const SizedBox(width: 32),
                  _SecondaryAction(
                    icon: Icons.grid_view_outlined,
                    label: 'Page',
                    active: false,
                    locked: !pageUnlocked,
                    onTap: pageUnlocked ? onSwitchToPage : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slim progress header
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  final int completed;
  final int total;
  const _ProgressHeader({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? completed / total : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding, 12, AppSizes.pagePadding, 0),
      child: Row(
        children: [
          Expanded(
            child: AnimatedProgressBar(
              value: fraction,
              minHeight: 4,
              backgroundColor: AppColors.border,
              color: AppColors.primaryMuted,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$completed/$total',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Secondary action button (Audio / Tafsir / Page)
// ─────────────────────────────────────────────────────────────────────────────

class _SecondaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool locked;
  final VoidCallback? onTap;

  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.active,
    this.locked = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = locked
        ? AppColors.border
        : active
            ? AppColors.primaryMuted
            : AppColors.textSecondary;
    return Tooltip(
      message: locked ? 'Complete your first ayah to unlock' : '',
      child: GestureDetector(
        onTap: locked ? null : onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 22, color: color),
                if (locked)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: Icon(Icons.lock_outline, size: 10, color: AppColors.border),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page-context view
// ─────────────────────────────────────────────────────────────────────────────

class _PageContextView extends StatefulWidget {
  final Journey journey;
  final JourneyMember? myMember;
  final int surah;
  final int ayah;
  final void Function(int surah, int ayah) onSelectAyah;
  final VoidCallback onBackToAyah;

  const _PageContextView({
    super.key,
    required this.journey,
    required this.myMember,
    required this.surah,
    required this.ayah,
    required this.onSelectAyah,
    required this.onBackToAyah,
  });

  @override
  State<_PageContextView> createState() => _PageContextViewState();
}

class _PageContextViewState extends State<_PageContextView> {
  late int _page;
  late final int _firstPage;
  late final int _lastPage;

  @override
  void initState() {
    super.initState();
    final j = widget.journey;
    _page      = getPageNumber(widget.surah, widget.ayah);
    _firstPage = getPageNumber(j.startSurah, j.startAyah);
    _lastPage  = getPageNumber(j.endSurah,   j.endAyah);
  }

  @override
  void didUpdateWidget(_PageContextView old) {
    super.didUpdateWidget(old);
    if (old.surah != widget.surah || old.ayah != widget.ayah) {
      final p = getPageNumber(widget.surah, widget.ayah);
      if (p != _page) setState(() => _page = p);
    }
  }

  Color? _ayahColor(int ayahNo, int surahNo) {
    final j            = widget.journey;
    final linear       = journeyLinearIndex(surahNo, ayahNo);
    final linearStart  = journeyLinearIndex(j.startSurah, j.startAyah);
    final linearEnd    = journeyLinearIndex(j.endSurah,   j.endAyah);

    if (linear < linearStart || linear > linearEnd) return Colors.grey[300];
    if (surahNo == widget.surah && ayahNo == widget.ayah) {
      return AppColors.primary;
    }
    if (widget.myMember?.isAyahDone(surahNo, ayahNo) == true) {
      return AppColors.primaryMuted;
    }
    return AppColors.primary.withValues(alpha: 0.4);
  }

  void _onAyahTapped(int ayahNo, int surahNo) {
    widget.onSelectAyah(surahNo, ayahNo);
    _showAyahSheet(surahNo, ayahNo);
  }

  void _showAyahSheet(int surah, int ayah) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AyahBottomSheet(
        journey: widget.journey,
        myMember: widget.myMember,
        surah: surah,
        ayah: ayah,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ArabicPageViewer(
            page: _page,
            surah: widget.surah,
            ayah: widget.ayah,
            ayahColor: _ayahColor,
            onAyahClicked: _onAyahTapped,
          ),
        ),
        // ── Page navigation bar ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: AppColors.primary,
                disabledColor: AppColors.border,
                onPressed:
                    _page > _firstPage ? () => setState(() => _page--) : null,
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Page $_page',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      'Tap an ayah for details',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: AppColors.primary,
                disabledColor: AppColors.border,
                onPressed:
                    _page < _lastPage ? () => setState(() => _page++) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ayah bottom sheet (page-context view)
// ─────────────────────────────────────────────────────────────────────────────

class _AyahBottomSheet extends StatelessWidget {
  final Journey journey;
  final JourneyMember? myMember;
  final int surah;
  final int ayah;

  const _AyahBottomSheet({
    required this.journey,
    required this.myMember,
    required this.surah,
    required this.ayah,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = myMember?.isAyahDone(surah, ayah) ?? false;
    final dims   = journey.dimensions;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(getSurahName(surah),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      Text('Ayah $ayah',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (isDone) const _DoneBadge(),
              ],
            ),
            const Divider(height: 24, color: AppColors.border),

            // Arabic
            if (dims.contains('read')) ...[
              SizedBox(
                width: double.infinity,
                child: Text(
                  getVerse(surah, ayah),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.lateef(
                    textStyle: const TextStyle(
                        fontSize: 28, height: 2.0,
                        color: AppColors.textPrimary),
                  ),
                ),
              ),
              const Divider(height: 24, color: AppColors.border),
            ],

            // Translation
            if (dims.contains('translate')) ...[
              const Text(
                'TRANSLATION',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary, letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                getVerseTranslation(surah, ayah,
                    translation: Translation.enSaheeh),
                style: const TextStyle(
                    fontSize: 14, height: 1.65,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
            ],

            // Commentary
            if (dims.contains('commentary')) ...[
              CommentarySection(surahNumber: surah, ayahNumber: ayah),
              const SizedBox(height: 16),
            ],

            // Audio
            if (dims.contains('memorize')) ...[
              const Text(
                'MEMORIZE',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary, letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              _JourneyAudioPlayer(
                key: ValueKey('sheet_${surah}_$ayah'),
                surah: surah,
                ayah: ayah,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio player for memorize dimension
// ─────────────────────────────────────────────────────────────────────────────

class _JourneyAudioPlayer extends StatefulWidget {
  final int surah;
  final int ayah;
  const _JourneyAudioPlayer({super.key, required this.surah, required this.ayah});

  @override
  State<_JourneyAudioPlayer> createState() => _JourneyAudioPlayerState();
}

class _JourneyAudioPlayerState extends State<_JourneyAudioPlayer> {
  SurahAudio?  _surahAudio;
  AyahAudio?   _ayahAudio;
  AudioPlayer? _player;
  bool _playing = false;
  StreamSubscription<Duration>? _posSub;

  @override
  void initState() {
    super.initState();
    _loadAudio();
  }

  void _loadAudio() {
    final json   = AppStorage().getAudioSurahs(widget.surah);
    final audios = SurahAudio.fromJsonArray(json);
    if (audios.isEmpty) return;
    _surahAudio = audios.first;
    try {
      _ayahAudio = _surahAudio!.ayahs.firstWhere(
          (a) => a.ayahNumber == widget.ayah);
    } catch (_) {
      _ayahAudio = null;
    }
  }

  Future<void> _play() async {
    if (_surahAudio?.localFileUrl == null || _ayahAudio == null) return;
    _player ??= AudioPlayer();
    if (_player!.processingState == ProcessingState.idle ||
        _player!.processingState == ProcessingState.completed) {
      await _player!.setFilePath(_surahAudio!.localFileUrl!);
    }
    await _player!.seek(Duration(milliseconds: _ayahAudio!.startFrom));
    await _player!.play();
    if (mounted) setState(() => _playing = true);

    _posSub?.cancel();
    _posSub = _player!.positionStream.listen((pos) {
      if (pos.inMilliseconds >= _ayahAudio!.endAt) {
        _player!.pause();
        if (mounted) setState(() => _playing = false);
        _posSub?.cancel();
      }
    });
  }

  Future<void> _pause() async {
    _posSub?.cancel();
    await _player?.pause();
    if (mounted) setState(() => _playing = false);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  // ── AppStorage helpers ─────────────────────────────────────────────────────

  void _saveAudio(SurahAudio audio) {
    final storage = AppStorage();
    final existing =
        SurahAudio.fromJsonArray(storage.getAudioSurahs(widget.surah));
    existing.add(audio);
    storage.setAudioSurahs(widget.surah, SurahAudio.toJsonArray(existing));
  }

  void _updateAudio(SurahAudio updated) {
    final storage = AppStorage();
    final existing =
        SurahAudio.fromJsonArray(storage.getAudioSurahs(widget.surah));
    final idx = existing.indexWhere((a) => a.audioName == updated.audioName);
    if (idx >= 0) {
      existing[idx] = updated;
    } else {
      existing.add(updated);
    }
    storage.setAudioSurahs(widget.surah, SurahAudio.toJsonArray(existing));
  }

  // ── Audio source pickers ────────────────────────────────────────────────────

  Future<void> _pickFromDevice(BuildContext ctx) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.single.path == null) return;
    if (!ctx.mounted) return;

    await Navigator.push(
      ctx,
      AppRoute(
        builder: (_) => NewAudio(
          widget.surah,
          result.files.single,
          launchTrainingOnSave: true,
          onSurahAdd: _saveAudio,
          onTrainingUpdate: _updateAudio,
        ),
      ),
    );
    _loadAudio();
    if (mounted) setState(() {});
  }

  void _pickFromScholars(BuildContext ctx) {
    ScholarAudioPicker.show(
      ctx,
      surahNumber: widget.surah,
      surahNameEnglish: getSurahName(widget.surah),
      onSelected: (audio) async {
        _saveAudio(audio);
        if (ctx.mounted) {
          await Navigator.push(
            ctx,
            AppRoute(
              builder: (_) =>
                  AudioTrainingScreen(audio, onUpdate: _updateAudio),
            ),
          );
        }
        _loadAudio();
        if (mounted) setState(() {});
      },
    );
  }

  void _pickFromCommunity(BuildContext ctx) {
    CommunityAudioPicker.show(
      ctx,
      surahNumber: widget.surah,
      surahNameEnglish: getSurahName(widget.surah),
      onSelected: (audio) {
        _saveAudio(audio);
        _loadAudio();
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _openTraining(BuildContext ctx) async {
    if (_surahAudio == null) return;
    await Navigator.push(
      ctx,
      AppRoute(
        builder: (_) =>
            AudioTrainingScreen(_surahAudio!, onUpdate: _updateAudio),
      ),
    );
    _loadAudio();
    if (mounted) setState(() {});
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // No audio file for this surah — show source picker inline.
    if (_surahAudio == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.headphones_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Text(
                'No recitation set up',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _AudioSourceButton(
                  icon: Icons.upload_file,
                  label: 'Device',
                  onTap: () => _pickFromDevice(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AudioSourceButton(
                  icon: Icons.school_outlined,
                  label: 'Scholars',
                  onTap: () => _pickFromScholars(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AudioSourceButton(
                  icon: Icons.people_outline,
                  label: 'Community',
                  onTap: () => _pickFromCommunity(context),
                ),
              ),
            ]),
          ],
        ),
      );
    }

    // Audio exists but this ayah has no timing yet.
    if (_ayahAudio == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.music_note, color: AppColors.gold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _surahAudio!.reciterName.isNotEmpty
                        ? _surahAudio!.reciterName
                        : _surahAudio!.audioName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Verses not synced yet',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.gold.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _openTraining(context),
              child: const Text('Sync verses →',
                  style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Play / Pause
          GestureDetector(
            onTap: _playing ? _pause : _play,
            child: Icon(
              _playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: AppColors.primary,
              size: 44,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _playing ? 'Playing ayah ${widget.ayah}…' : 'Ayah ${widget.ayah}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                Text(
                  _surahAudio!.reciterName,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Replay
          IconButton(
            tooltip: 'Replay',
            onPressed: _play,
            icon: Icon(Icons.replay,
                color: AppColors.primary.withValues(alpha: 0.8), size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _AudioSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AudioSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(height: 4),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneBadge extends StatelessWidget {
  const _DoneBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 13, color: AppColors.gold),
            const SizedBox(width: 4),
            Text(
              'Done',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}
