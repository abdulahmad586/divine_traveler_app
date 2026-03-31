import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
import 'package:tahfeex/shared/models/models.dart';
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
        _journey  = journey;
        _myMember = myMember;
        _loading  = false;
        _surah    = first?.$1 ?? journey.endSurah;
        _ayah     = first?.$2 ?? journey.endAyah;
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

  bool get _isCurrentDone  => _myMember?.isAyahDone(_surah, _ayah) ?? false;
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

  Future<void> _markComplete() async {
    if (_completing || _journey == null || _myMember?.isActionable != true) return;
    setState(() => _completing = true);
    try {
      final updated = await _repo.updateProgress(
        id: widget.journeyId,
        surah: _surah,
        ayah: _ayah,
      );
      if (!mounted) return;
      final myUid      = FirebaseAuth.instance.currentUser?.uid ?? '';
      final wasLast    = _isLastAyah;
      final updatedMember = updated.memberFor(myUid);
      setState(() {
        _journey  = updated;
        _myMember = updatedMember;
        _completing = false;
      });
      if (updatedMember?.isCompleted == true) {
        _showCompletionDialog();
      } else if (!wasLast) {
        _nextAyah();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _completing = false);
      if (e.isJourneyCompleted) {
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
            child: CircularProgressIndicator(color: AppColors.primaryColor)),
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
    final allDone = _firstIncomplete(j, _myMember) == null;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              j.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              allDone
                  ? 'All ayahs complete'
                  : '${getSurahName(_surah)} · Ayah $_ayah',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Center(
              child: Text(
                '${_myMember?.completedCount ?? 0}/${j.totalAyahs}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
          IconButton(
            tooltip: _viewMode == _ViewMode.ayahCentric
                ? 'Page context view'
                : 'Ayah focus view',
            icon: Icon(
              _viewMode == _ViewMode.ayahCentric
                  ? Icons.menu_book_rounded
                  : Icons.article_outlined,
            ),
            onPressed: () => setState(() {
              _viewMode = _viewMode == _ViewMode.ayahCentric
                  ? _ViewMode.pageContext
                  : _ViewMode.ayahCentric;
            }),
          ),
        ],
      ),
      floatingActionButton: _buildFab(j),
      body: _viewMode == _ViewMode.ayahCentric
          ? _AyahCentricView(
              // key forces a fresh widget (and fresh audio/commentary state) on
              // every ayah change.
              key: ValueKey('${_surah}_$_ayah'),
              journey: j,
              myMember: _myMember,
              surah: _surah,
              ayah: _ayah,
              onPrev: _isFirstAyah ? null : _prevAyah,
              onNext: _isLastAyah  ? null : _nextAyah,
            )
          : _PageContextView(
              journey: j,
              myMember: _myMember,
              surah: _surah,
              ayah: _ayah,
              onSelectAyah: (s, a) => setState(() { _surah = s; _ayah = a; }),
            ),
    );
  }

  Widget? _buildFab(Journey j) {
    if (_myMember?.isActionable != true) return null;

    if (_isCurrentDone) {
      if (_isLastAyah) return null;
      return FloatingActionButton.extended(
        backgroundColor: Colors.grey[600],
        onPressed: _nextAyah,
        icon: const Icon(Icons.arrow_forward, color: Colors.white),
        label: const Text('Next', style: TextStyle(color: Colors.white)),
      );
    }

    return FloatingActionButton.extended(
      backgroundColor: AppColors.primaryColor,
      onPressed: _completing ? null : _markComplete,
      icon: _completing
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.check_circle_outline, color: Colors.white),
      label: const Text('Mark Complete',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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

  const _AyahCentricView({
    super.key,
    required this.journey,
    required this.myMember,
    required this.surah,
    required this.ayah,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = myMember?.isAyahDone(surah, ayah) ?? false;
    final dims   = journey.dimensions;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ayah header ───────────────────────────────────────────────────
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
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Ayah $ayah',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              if (isDone) _DoneBadge(),
            ],
          ),
          const SizedBox(height: 16),

          // ── Arabic (read) ─────────────────────────────────────────────────
          if (dims.contains('read'))
            _SectionCard(
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  getVerse(surah, ayah),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.lateef(
                    textStyle: const TextStyle(
                        fontSize: 30, color: Colors.black87, height: 1.8),
                  ),
                ),
              ),
            ),

          // ── Translation (translate) ───────────────────────────────────────
          if (dims.contains('translate')) ...[
            const SizedBox(height: 12),
            _SectionCard(
              label: 'Translation',
              child: Text(
                getVerseTranslation(surah, ayah,
                    translation: Translation.enSaheeh),
                style: TextStyle(
                    fontSize: 15, height: 1.7, color: Colors.grey[800]),
              ),
            ),
          ],

          // ── Commentary (commentary) ───────────────────────────────────────
          if (dims.contains('commentary')) ...[
            const SizedBox(height: 12),
            _SectionCard(
              child: CommentarySection(surahNumber: surah, ayahNumber: ayah),
            ),
          ],

          // ── Audio (memorize) ──────────────────────────────────────────────
          if (dims.contains('memorize')) ...[
            const SizedBox(height: 12),
            _SectionCard(
              label: 'Memorize',
              child: _JourneyAudioPlayer(
                key: ValueKey('audio_${surah}_$ayah'),
                surah: surah,
                ayah: ayah,
              ),
            ),
          ],

          // ── Prev / Next navigation ────────────────────────────────────────
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: onPrev != null
                    ? OutlinedButton.icon(
                        onPressed: onPrev,
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Previous'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (onPrev != null && onNext != null) const SizedBox(width: 12),
              Expanded(
                child: onNext != null
                    ? OutlinedButton.icon(
                        onPressed: onNext,
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Next'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryColor,
                          side: BorderSide(
                              color: AppColors.primaryColor.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
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

  const _PageContextView({
    required this.journey,
    required this.myMember,
    required this.surah,
    required this.ayah,
    required this.onSelectAyah,
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

  /// Color for each ayah's verse-end symbol in the page viewer.
  Color? _ayahColor(int ayahNo, int surahNo) {
    final j            = widget.journey;
    final linear       = journeyLinearIndex(surahNo, ayahNo);
    final linearStart  = journeyLinearIndex(j.startSurah, j.startAyah);
    final linearEnd    = journeyLinearIndex(j.endSurah,   j.endAyah);

    if (linear < linearStart || linear > linearEnd) return Colors.grey[300];
    if (surahNo == widget.surah && ayahNo == widget.ayah) {
      return AppColors.primaryColor;
    }
    if (widget.myMember?.isAyahDone(surahNo, ayahNo) == true) return Colors.teal;
    return Colors.green;
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
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: AppColors.primaryColor,
                disabledColor: Colors.grey[300],
                onPressed:
                    _page > _firstPage ? () => setState(() => _page--) : null,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Page $_page',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    'Tap an ayah for details',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: AppColors.primaryColor,
                disabledColor: Colors.grey[300],
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
                    color: Colors.grey[300],
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
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('Ayah $ayah',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[500])),
                    ],
                  ),
                ),
                if (isDone) _DoneBadge(),
              ],
            ),
            const Divider(height: 24),

            // Arabic
            if (dims.contains('read')) ...[
              SizedBox(
                width: double.infinity,
                child: Text(
                  getVerse(surah, ayah),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.lateef(
                    textStyle: const TextStyle(
                        fontSize: 26, height: 1.8, color: Colors.black87),
                  ),
                ),
              ),
              const Divider(height: 24),
            ],

            // Translation
            if (dims.contains('translate')) ...[
              _SheetLabel('Translation'),
              const SizedBox(height: 8),
              Text(
                getVerseTranslation(surah, ayah,
                    translation: Translation.enSaheeh),
                style: TextStyle(
                    fontSize: 14, height: 1.65, color: Colors.grey[800]),
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
              _SheetLabel('Memorize'),
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
      MaterialPageRoute(
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
        // Scholar downloads have no verse timings yet — go straight to sync.
        if (ctx.mounted) {
          await Navigator.push(
            ctx,
            MaterialPageRoute(
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
      MaterialPageRoute(
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
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.headphones_outlined,
                  size: 16, color: Colors.grey[400]),
              const SizedBox(width: 6),
              Text(
                'No recitation set up',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
          color: Colors.amber[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.music_note, color: Colors.amber[700], size: 20),
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
                    style:
                        TextStyle(fontSize: 11, color: Colors.amber[700]),
                  ),
                ],
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.amber[800],
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
        color: AppColors.primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Play / Pause
          GestureDetector(
            onTap: _playing ? _pause : _play,
            child: Icon(
              _playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: AppColors.primaryColor,
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
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  _surahAudio!.reciterName,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Replay
          IconButton(
            tooltip: 'Replay',
            onPressed: _play,
            icon: Icon(Icons.replay,
                color: AppColors.primaryColor.withOpacity(0.8), size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _AudioInfoBox extends StatelessWidget {
  final IconData icon;
  final Color iconColor, bgColor, borderColor, textColor;
  final String message;

  const _AudioInfoBox({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.message,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: TextStyle(fontSize: 13, color: textColor))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Compact tappable button used in the audio source picker.
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
          color: AppColors.primaryColor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: AppColors.primaryColor.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primaryColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String? label;
  final Widget child;
  const _SectionCard({this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null) ...[
              Text(
                label!.toUpperCase(),
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: Colors.grey[500], letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;
  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: Colors.grey[500], letterSpacing: 0.8,
        ),
      );
}

class _DoneBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.teal[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.teal[200]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 13, color: Colors.teal[600]),
            const SizedBox(width: 4),
            Text(
              'Done',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.teal[700],
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}
