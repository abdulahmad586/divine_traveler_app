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
import 'package:tahfeex/shared/sync/progress_sync_queue.dart';
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

  // Phase 3 state
  bool _glowing = false;
  bool _showAudio = false;
  bool _showTafsir = false;

  // ── Daily progress ─────────────────────────────────────────────────────────
  int _todayCount = 0;

  int get _dailyGoal {
    final j = _journey;
    if (j == null) return 1;
    final days = j.endDate.difference(j.startDate).inDays;
    return days > 0 ? (j.totalAyahs / days).ceil() : j.totalAyahs;
  }

  /// Ayah keys (`'surah_ayah'`) marked locally but not yet confirmed by the
  /// server. Overlaid on top of [_myMember] so all UI reflects them instantly.
  Set<String> _localExtra = {};

  /// [_myMember] merged with [_localExtra] — passed to all child widgets so
  /// they automatically show optimistic completions.
  JourneyMember? get _effectiveMember =>
      _myMember?.withExtraCompletions(_localExtra);

  // ── Focus / lock state ─────────────────────────────────────────────────────
  bool _controlsVisible = true;
  bool _locked = false;
  Timer? _autoHideTimer;

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_locked) setState(() => _controlsVisible = false);
    });
  }

  void _revealControls() {
    if (_locked) return;
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleAutoHide();
  }

  void _onContentTap() {
    if (_locked) return;
    if (_controlsVisible) {
      _autoHideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _revealControls();
    }
  }

  void _toggleLock() {
    setState(() {
      if (_locked) {
        _locked = false;
        _controlsVisible = true;
        _scheduleAutoHide();
      } else {
        _locked = true;
        _autoHideTimer?.cancel();
        _controlsVisible = false;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadJourney();
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadJourney() async {
    setState(() { _loading = true; _error = null; });
    // Best-effort flush of any previously queued items while we wait for load.
    ProgressSyncQueue().flush(_repo).ignore();
    try {
      final journey  = await _repo.getJourneyById(widget.journeyId);
      final myUid    = FirebaseAuth.instance.currentUser?.uid ?? '';
      final myMember = journey.memberFor(myUid);

      // Restore any pending local completions not yet reflected by the server.
      final pending = ProgressSyncQueue().pendingFor(widget.journeyId);
      final localExtra = pending
          .where((k) => myMember?.completedAyahs[k] != true)
          .toSet();

      final first = _firstIncomplete(journey, myMember, localExtra);
      setState(() {
        _journey    = journey;
        _myMember   = myMember;
        _localExtra = localExtra;
        _loading    = false;
        _surah      = first?.$1 ?? journey.endSurah;
        _ayah       = first?.$2 ?? journey.endAyah;
        _showAudio  = journey.dimensions.contains('memorize');
        _showTafsir = journey.dimensions.contains('commentary');
        _todayCount = AppStorage().getTodayJourneyCount(widget.journeyId);
      });
      _scheduleAutoHide();
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  /// Returns the first ayah not yet done (server + local overlay).
  (int, int)? _firstIncomplete(
      Journey j, JourneyMember? member, Set<String> localExtra) {
    if (member == null && localExtra.isEmpty) return (j.startSurah, j.startAyah);
    for (int s = j.startSurah; s <= j.endSurah; s++) {
      final minA = s == j.startSurah ? j.startAyah : 1;
      final maxA = s == j.endSurah   ? j.endAyah   : ayahCounts[s];
      for (int a = minA; a <= maxA; a++) {
        final done = (member?.isAyahDone(s, a) ?? false) ||
            localExtra.contains('${s}_$a');
        if (!done) return (s, a);
      }
    }
    return null;
  }

  bool get _isFirstAyah => _surah == _journey!.startSurah && _ayah == _journey!.startAyah;
  bool get _isLastAyah  => _surah == _journey!.endSurah   && _ayah == _journey!.endAyah;

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
    _revealControls();
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
    _revealControls();
  }

  void _triggerGlow() {
    setState(() => _glowing = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _glowing = false);
    });
  }

  Future<void> _markComplete() async {
    if (_journey == null || _myMember?.isActionable != true) return;
    final surah = _surah;
    final ayah  = _ayah;

    // Already done (server or local) — nothing to do.
    if (_effectiveMember?.isAyahDone(surah, ayah) == true) return;

    HapticFeedback.lightImpact();
    _triggerGlow();
    UserProgression().recordActivity();

    // ── Optimistic update ────────────────────────────────────────────────────
    final newTodayCount = AppStorage().incrementTodayJourneyCount(widget.journeyId);
    setState(() {
      _localExtra = {..._localExtra, '${surah}_$ayah'};
      _todayCount = newTodayCount;
    });

    // Advance focus immediately — reader keeps moving without waiting.
    if (!_isLastAyah) _nextAyah();

    // Persist to queue so it survives app restarts.
    ProgressSyncQueue().enqueue(widget.journeyId, surah, ayah);

    // ── Background sync ──────────────────────────────────────────────────────
    _syncEntry(surah, ayah);
  }

  void _syncEntry(int surah, int ayah) {
    _repo
        .updateProgress(id: widget.journeyId, surah: surah, ayah: ayah)
        .then((updated) {
      if (!mounted) return;
      final myUid         = FirebaseAuth.instance.currentUser?.uid ?? '';
      final updatedMember = updated.memberFor(myUid);
      // Remove server-confirmed keys from local overlay.
      final confirmedKeys = updatedMember?.completedAyahs.keys.toSet() ?? {};
      ProgressSyncQueue().removeEntry(widget.journeyId, surah, ayah);
      setState(() {
        _journey    = updated;
        _myMember   = updatedMember;
        _localExtra = _localExtra
            .where((k) => !confirmedKeys.contains(k))
            .toSet();
      });
      if (updatedMember?.isCompleted == true) {
        UserProgression().setJourneyCompleted();
        _showCompletionDialog();
      }
    }).catchError((e) {
      // Entry stays in queue — will be retried next time _loadJourney runs.
      if (e is ApiException && e.isJourneyCompleted) {
        if (mounted) {
          UserProgression().setJourneyCompleted();
          _showCompletionDialog();
        }
      }
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppDialog(
        title: 'Journey Complete!',
        body: 'You have completed "${_journey?.title ?? 'this journey'}". Well done!',
        actions: [
          AppDialogAction(
            label: 'Done',
            isPrimary: true,
            onPressed: () {
              Navigator.pop(context); // dialog
              Navigator.pop(context); // journey screen → back to caller
            },
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
    final completedCount = _effectiveMember?.completedCount ?? 0;
    final totalCount = j.totalAyahs;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // ── Main content ──────────────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _viewMode == _ViewMode.ayahCentric
                ? _AyahCentricView(
                    key: ValueKey('${_surah}_$_ayah'),
                    journey: j,
                    myMember: _effectiveMember,
                    surah: _surah,
                    ayah: _ayah,
                    onPrev: _isFirstAyah ? null : _prevAyah,
                    onNext: _isLastAyah  ? null : _nextAyah,
                    glowing: _glowing,
                    showAudio: _showAudio,
                    showTafsir: _showTafsir,
                    isCompleting: false,
                    onToggleAudio: () { setState(() => _showAudio = !_showAudio); _revealControls(); },
                    onToggleTafsir: () { setState(() => _showTafsir = !_showTafsir); _revealControls(); },
                    onMarkComplete: _markComplete,
                    controlsVisible: _controlsVisible,
                    onTap: _onContentTap,
                  )
                : _PageContextView(
                    key: const ValueKey('page'),
                    journey: j,
                    myMember: _effectiveMember,
                    surah: _surah,
                    ayah: _ayah,
                    onSelectAyah: (s, a) => setState(() { _surah = s; _ayah = a; }),
                    onMarkComplete: _effectiveMember?.isActionable == true ? _markComplete : null,
                    controlsVisible: _controlsVisible,
                    onTap: _onContentTap,
                  ),
          ),

          // ── Top bar overlay ───────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: AnimatedSlide(
              offset: _controlsVisible ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: _buildTopBar(j, completedCount, totalCount),
              ),
            ),
          ),

          // ── Daily progress pill (focus mode only) ────────────────────────
          if (!_controlsVisible && !_locked && _journey != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0, right: 0,
              child: Center(
                child: _DailyProgressPill(
                  today: _todayCount,
                  goal: _dailyGoal,
                ),
              ),
            ),

          // ── Lock hint (always visible when locked) ────────────────────────
          if (_locked)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0, right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _toggleLock,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 13, color: Colors.white70),
                        SizedBox(width: 7),
                        Text('Tap to unlock',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Custom top bar (replaces Scaffold AppBar) ───────────────────────────────

  Widget _buildTopBar(Journey j, int completedCount, int totalCount) {
    return Material(
      color: AppColors.primary,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  BackButton(
                    color: Colors.white,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          getSurahName(_surah),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Verse $_ayah  ·  $completedCount of $totalCount done',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                  // ── Ayah / Page toggle ──────────────────────────
                  GestureDetector(
                    onTap: () {
                      if (_viewMode == _ViewMode.ayahCentric &&
                          !UserProgression().hasCompletedFirstAyah) return;
                      setState(() {
                        _viewMode = _viewMode == _ViewMode.ayahCentric
                            ? _ViewMode.pageContext
                            : _ViewMode.ayahCentric;
                      });
                      _revealControls();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _modeSegment('Ayah',
                              _viewMode == _ViewMode.ayahCentric),
                          _modeSegment('Page',
                              _viewMode == _ViewMode.pageContext),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _locked ? Icons.lock : Icons.lock_open_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _toggleLock,
                    tooltip: _locked ? 'Unlock' : 'Lock screen',
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: totalCount > 0 ? completedCount / totalCount : 0.0,
              minHeight: 2,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeSegment(String label, bool active) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.primary : Colors.white70,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily progress pill — shown in focus mode (controls hidden, not locked)
// ─────────────────────────────────────────────────────────────────────────────

class _DailyProgressPill extends StatelessWidget {
  final int today;
  final int goal;

  const _DailyProgressPill({required this.today, required this.goal});

  @override
  Widget build(BuildContext context) {
    final fraction = goal > 0 ? (today / goal).clamp(0.0, 1.0) : 0.0;
    final done = today >= goal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: 2.5,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(
                done ? AppColors.gold : Colors.white70,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            done ? 'Daily goal reached · $today ayahs' : '$today of $goal today',
            style: TextStyle(
              color: done ? AppColors.gold : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
  final VoidCallback onToggleAudio;
  final VoidCallback onToggleTafsir;
  final VoidCallback? onMarkComplete;
  final bool controlsVisible;
  final VoidCallback? onTap;

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
    required this.onToggleAudio,
    required this.onToggleTafsir,
    this.onMarkComplete,
    required this.controlsVisible,
    this.onTap,
  });

  bool get _isDone       => myMember?.isAyahDone(surah, ayah) ?? false;
  bool get _isActionable => myMember?.isActionable ?? false;
  int  get _completed    => myMember?.completedCount ?? 0;
  int  get _total        => journey.totalAyahs;

  @override
  Widget build(BuildContext context) {
    final dims = journey.dimensions;

    return Stack(
      children: [
        // ── Scrollable content — fills entire screen ───────────────────────
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v < -300) onNext?.call();
              if (v >  300) onPrev?.call();
            },
            child: SingleChildScrollView(
              // top: approx safe-area + app-bar (100) + padding (28)
              // bottom: approx bottom-bar height (220)
              padding: const EdgeInsets.fromLTRB(24, 128, 24, 220),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Verse identifier row ───────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isDone
                                ? AppColors.gold.withValues(alpha: 0.5)
                                : AppColors.border,
                          ),
                          color: _isDone
                              ? AppColors.gold.withValues(alpha: 0.08)
                              : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(
                            '$ayah',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _isDone
                                  ? AppColors.gold
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              getSurahName(surah),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Verse $ayah',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (_isDone) const _DoneBadge(),
                    ],
                  ),

                  // ── Arabic text ────────────────────────────────────────
                  if (dims.contains('read')) ...[
                    const SizedBox(height: 28),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      decoration: glowing
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.18),
                                  blurRadius: 28,
                                  spreadRadius: 0,
                                ),
                              ],
                            )
                          : null,
                      child: Text(
                        getVerse(surah, ayah),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.lateef(
                          textStyle: TextStyle(
                            fontSize: 38,
                            color: glowing
                                ? AppColors.gold
                                : _isDone
                                    ? AppColors.gold.withValues(alpha: 0.72)
                                    : AppColors.textPrimary,
                            height: 2.1,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // ── Translation ────────────────────────────────────────
                  if (dims.contains('read') && dims.contains('translate')) ...[
                    const SizedBox(height: 28),
                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 24),
                  ] else if (dims.contains('translate'))
                    const SizedBox(height: 28),

                  if (dims.contains('translate'))
                    Text(
                      getVerseTranslation(surah, ayah,
                          translation: Translation.enSaheeh),
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.85,
                        color: AppColors.textSecondary,
                      ),
                    ),

                  // ── Inline audio ─────────────────────────────────────────
                  if (showAudio) ...[
                    const SizedBox(height: 20),
                    _JourneyAudioPlayer(
                      key: ValueKey('audio_${surah}_$ayah'),
                      surah: surah,
                      ayah: ayah,
                    ),
                  ],

                  // ── Inline tafsir ─────────────────────────────────────────
                  if (showTafsir) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'COMMENTARY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    CommentarySection(surahNumber: surah, ayahNumber: ayah),
                  ],
                ],
              ),
            ),
          ),
        ),

        // ── Bottom bar — animated overlay ──────────────────────────────────
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: AnimatedSlide(
            offset:
                controlsVisible ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              opacity: controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              child: IgnorePointer(
                ignoring: !controlsVisible,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.cardSurface,
                    border: Border(
                        top: BorderSide(
                            color: AppColors.border, width: 0.5)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 14, 20, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Tool chips
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              _ToolChip(
                                icon: Icons.volume_up_outlined,
                                label: 'Audio',
                                active: showAudio,
                                onTap: onToggleAudio,
                              ),
                              const SizedBox(width: 8),
                              _ToolChip(
                                icon: Icons.menu_book_outlined,
                                label: 'Tafsir',
                                active: showTafsir,
                                onTap: onToggleTafsir,
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Primary action
                          if (_isActionable)
                            _isDone
                                ? Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                          Icons.check_circle_rounded,
                                          size: 17,
                                          color: AppColors.gold),
                                      const SizedBox(width: 8),
                                      Text(
                                        onNext != null
                                            ? 'Done · swipe or tap › for next'
                                            : 'All done',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight:
                                                FontWeight.w500,
                                            color: AppColors
                                                .textSecondary),
                                      ),
                                    ],
                                  )
                                : SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: FilledButton(
                                      onPressed: isCompleting
                                          ? null
                                          : onMarkComplete,
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            AppColors.primary,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor:
                                            AppColors.primary
                                                .withValues(alpha: 0.5),
                                        shape: const StadiumBorder(),
                                        elevation: 0,
                                      ),
                                      child: isCompleting
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color:
                                                          Colors.white),
                                            )
                                          : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .center,
                                              children: [
                                                Icon(
                                                    Icons.check_rounded,
                                                    size: 18),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Mark Complete',
                                                  style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight
                                                              .w600),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),

                          const SizedBox(height: 8),

                          // Navigation row
                          Row(
                            children: [
                              IconButton(
                                onPressed: onPrev,
                                icon: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 16,
                                  color: onPrev != null
                                      ? AppColors.textSecondary
                                      : AppColors.border,
                                ),
                                style: IconButton.styleFrom(
                                    minimumSize:
                                        const Size(40, 36)),
                              ),
                              Expanded(
                                child: Text(
                                  '$_completed of $_total verses',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                              IconButton(
                                onPressed: onNext,
                                icon: Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: onNext != null
                                      ? AppColors.textSecondary
                                      : AppColors.border,
                                ),
                                style: IconButton.styleFrom(
                                    minimumSize:
                                        const Size(40, 36)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tool chip (Audio / Tafsir / Page view toggle)
// ─────────────────────────────────────────────────────────────────────────────

class _ToolChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool locked;
  final VoidCallback? onTap;

  const _ToolChip({
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
            ? AppColors.primary
            : AppColors.textSecondary;
    return Tooltip(
      message: locked ? 'Complete your first ayah to unlock' : '',
      child: GestureDetector(
        onTap: locked ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: locked
                  ? AppColors.border
                  : active
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                locked ? Icons.lock_outline : icon,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
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
  final Future<void> Function()? onMarkComplete;
  final bool controlsVisible;
  final VoidCallback onTap;

  const _PageContextView({
    super.key,
    required this.journey,
    required this.myMember,
    required this.surah,
    required this.ayah,
    required this.onSelectAyah,
    this.onMarkComplete,
    required this.controlsVisible,
    required this.onTap,
  });

  @override
  State<_PageContextView> createState() => _PageContextViewState();
}

class _PageContextViewState extends State<_PageContextView> {
  late int _page;
  late final int _firstPage;
  late final int _lastPage;
  bool _completing = false;

  Future<void> _doMarkComplete() async {
    if (_completing || widget.onMarkComplete == null) return;
    setState(() => _completing = true);
    try {
      await widget.onMarkComplete!();
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

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
    return Stack(
      children: [
        // ── Full-screen page viewer ─────────────────────────────────────────
        // onBackgroundClick fires when the tap lands outside any ayah text
        // span — the inner TapAndPanGestureRecognizer wins for ayah taps,
        // so this only triggers on truly empty regions.
        Positioned.fill(
          child: ArabicPageViewer(
            page: _page,
            surah: widget.surah,
            ayah: widget.ayah,
            ayahColor: _ayahColor,
            onAyahClicked: _onAyahTapped,
            onBackgroundClick: widget.onTap,
          ),
        ),

        // ── Bottom bar — animated overlay ───────────────────────────────────
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: AnimatedSlide(
            offset: widget.controlsVisible
                ? Offset.zero
                : const Offset(0, 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              opacity: widget.controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              child: IgnorePointer(
                ignoring: !widget.controlsVisible,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.cardSurface,
                    border: Border(
                        top: BorderSide(
                            color: AppColors.border, width: 0.5)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Page navigation ──────────────────────
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                    Icons.chevron_left, size: 26),
                                color: _page > _firstPage
                                    ? AppColors.primary
                                    : AppColors.border,
                                onPressed: _page > _firstPage
                                    ? () => setState(() => _page--)
                                    : null,
                                style: IconButton.styleFrom(
                                    minimumSize: const Size(40, 36)),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      'Page $_page',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      '${getSurahName(widget.surah)}  ·  Verse ${widget.ayah}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color:
                                              AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                    Icons.chevron_right, size: 26),
                                color: _page < _lastPage
                                    ? AppColors.primary
                                    : AppColors.border,
                                onPressed: _page < _lastPage
                                    ? () => setState(() => _page++)
                                    : null,
                                style: IconButton.styleFrom(
                                    minimumSize: const Size(40, 36)),
                              ),
                            ],
                          ),

                          // ── Mark complete ────────────────────────
                          if (widget.onMarkComplete != null) ...[
                            const SizedBox(height: 8),
                            Builder(builder: (context) {
                              final isDone = widget.myMember
                                      ?.isAyahDone(
                                          widget.surah, widget.ayah) ??
                                  false;
                              return SizedBox(
                                width: double.infinity,
                                height: AppSizes.buttonHeight,
                                child: isDone
                                    ? OutlinedButton.icon(
                                        onPressed: null,
                                        style: OutlinedButton.styleFrom(
                                          disabledForegroundColor:
                                              AppColors.primaryMuted,
                                          side: const BorderSide(
                                              color:
                                                  AppColors.primaryMuted),
                                          shape: const StadiumBorder(),
                                        ),
                                        icon: const Icon(
                                            Icons.check_circle_outline,
                                            size: 18),
                                        label: const Text('Completed',
                                            style: TextStyle(
                                                fontWeight:
                                                    FontWeight.w600)),
                                      )
                                    : FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              AppColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: const StadiumBorder(),
                                          elevation: 0,
                                        ),
                                        onPressed: _completing
                                            ? null
                                            : _doMarkComplete,
                                        icon: _completing
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            Colors.white),
                                              )
                                            : const Icon(
                                                Icons.check_rounded,
                                                size: 18),
                                        label: const Text('Mark Complete',
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight:
                                                    FontWeight.w600)),
                                      ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 12, color: AppColors.gold),
            const SizedBox(width: 4),
            Text(
              'Done',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}
