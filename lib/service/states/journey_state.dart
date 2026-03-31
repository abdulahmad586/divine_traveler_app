import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/service/repositories/journey_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Journey List
// ─────────────────────────────────────────────────────────────────────────────

class JourneyListCubit extends Cubit<JourneyListState> {
  final _repo = JourneyRepository();

  JourneyListCubit() : super(const JourneyListState()) {
    load();
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final journeys = await _repo.getJourneys();
      emit(state.copyWith(isLoading: false, journeys: journeys));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Count of active memberships (not created journeys) for the 5-journey cap.
  /// Pass [myUid] to count based on the current user's own member status.
  int activeCount(String myUid) {
    return state.journeys
            ?.where((j) {
              final m = j.memberFor(myUid);
              if (m == null) return false;
              return m.isActive || m.isPaused || m.isDelayed;
            })
            .length ??
        0;
  }

  bool atCap(String myUid) => activeCount(myUid) >= 5;
}

class JourneyListState {
  final List<Journey>? journeys;
  final bool isLoading;
  final String? error;

  const JourneyListState({
    this.journeys,
    this.isLoading = false,
    this.error,
  });

  JourneyListState copyWith({
    List<Journey>? journeys,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      JourneyListState(
        journeys:  journeys  ?? this.journeys,
        isLoading: isLoading ?? this.isLoading,
        error:     clearError ? null : (error ?? this.error),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Journey Detail
// ─────────────────────────────────────────────────────────────────────────────

class JourneyDetailCubit extends Cubit<JourneyDetailState> {
  final _repo = JourneyRepository();
  final String journeyId;

  JourneyDetailCubit(this.journeyId) : super(const JourneyDetailState()) {
    load();
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final journey = await _repo.getJourneyById(journeyId);
      emit(state.copyWith(isLoading: false, journey: journey));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Returns the updated journey. Throws [ApiException] on error — callers
  /// should handle JOURNEY_COMPLETED and JOURNEY_ABANDONED specially.
  Future<Journey> updateProgress({required int surah, int? ayah}) async {
    final updated = await _repo.updateProgress(
        id: journeyId, surah: surah, ayah: ayah);
    emit(state.copyWith(journey: updated));
    return updated;
  }

  Future<void> pause() async {
    final updated =
        await _repo.updateStatus(id: journeyId, status: 'paused');
    emit(state.copyWith(journey: updated));
  }

  Future<void> resume() async {
    final updated =
        await _repo.updateStatus(id: journeyId, status: 'active');
    emit(state.copyWith(journey: updated));
  }

  Future<void> abandon() async {
    final updated =
        await _repo.updateStatus(id: journeyId, status: 'abandoned');
    emit(state.copyWith(journey: updated));
  }

  Future<void> join() async {
    final updated = await _repo.joinJourney(journeyId);
    emit(state.copyWith(journey: updated));
  }

  Future<void> leave() async {
    await _repo.leaveJourney(journeyId);
  }

  Future<void> removeMember(String memberId) async {
    final updated =
        await _repo.removeMember(journeyId: journeyId, memberId: memberId);
    emit(state.copyWith(journey: updated));
  }

  Future<void> nudge(String memberId) async {
    await _repo.nudgeMember(journeyId: journeyId, memberId: memberId);
  }

  Future<void> toggleAllowJoining({required bool allowJoining}) async {
    final updated = await _repo.updateSettings(
        id: journeyId, allowJoining: allowJoining);
    emit(state.copyWith(journey: updated));
  }
}

class JourneyDetailState {
  final Journey? journey;
  final bool isLoading;
  final String? error;

  const JourneyDetailState({
    this.journey,
    this.isLoading = false,
    this.error,
  });

  JourneyDetailState copyWith({
    Journey? journey,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      JourneyDetailState(
        journey:   journey   ?? this.journey,
        isLoading: isLoading ?? this.isLoading,
        error:     clearError ? null : (error ?? this.error),
      );
}
