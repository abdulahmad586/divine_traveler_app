import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tahfeex/model/app_user_model.dart';
import 'package:tahfeex/model/companion_models.dart';
import 'package:tahfeex/service/app_storage.dart';
import 'package:tahfeex/service/repositories/companion_repository.dart';

// ── Cubit ─────────────────────────────────────────────────────────────────────

class CompanionsCubit extends Cubit<CompanionsState> {
  final _repo = CompanionRepository();

  CompanionsCubit() : super(const CompanionsState()) {
    load();
  }

  /// Loads companions list and incoming requests in parallel.
  Future<void> load() async {
    // Serve cached data immediately.
    final cachedCompanions = AppStorage().getCompanionsCache();
    final cachedRequests   = AppStorage().getIncomingRequestsCache();
    if (cachedCompanions != null || cachedRequests != null) {
      emit(state.copyWith(
        isLoading: true,
        clearError: true,
        clearActing: true,
        companions:       cachedCompanions?.map(AppUser.fromJson).toList(),
        incomingRequests: cachedRequests?.map(CompanionRequest.fromJson).toList(),
      ));
    } else {
      emit(state.copyWith(isLoading: true, clearError: true, clearActing: true));
    }
    try {
      final results = await Future.wait([
        _repo.getCompanions(),
        _repo.getIncomingRequests(),
      ]);
      final companions = results[0] as List<AppUser>;
      final requests   = results[1] as List<CompanionRequest>;
      AppStorage().setCompanionsCache(companions.map((u) => u.toJson()).toList());
      AppStorage().setIncomingRequestsCache(requests.map((r) => r.toJson()).toList());
      emit(state.copyWith(
        isLoading: false,
        companions: companions,
        incomingRequests: requests,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: (cachedCompanions == null && cachedRequests == null) ? e.toString() : null,
      ));
    }
  }

  /// Returns true if auto-accepted, false if pending. Throws on API error.
  Future<bool> sendRequest(String username) async {
    final autoAccepted = await _repo.sendRequest(username);
    await load(); // refresh companions + requests
    return autoAccepted;
  }

  Future<void> acceptRequest(String requestId) async {
    emit(state.copyWith(actingRequestId: requestId));
    await _repo.acceptRequest(requestId);
    await load();
  }

  Future<void> rejectRequest(String requestId) async {
    emit(state.copyWith(actingRequestId: requestId));
    await _repo.cancelOrRejectRequest(requestId);
    // Optimistically remove from list while full reload happens.
    final updated = state.incomingRequests
        ?.where((r) => r.id != requestId)
        .toList();
    if (updated != null) {
      AppStorage().setIncomingRequestsCache(updated.map((r) => r.toJson()).toList());
    }
    emit(state.copyWith(incomingRequests: updated, clearActing: true));
    await load();
  }
}

// ── State ─────────────────────────────────────────────────────────────────────

class CompanionsState {
  final List<AppUser>? companions;
  final List<CompanionRequest>? incomingRequests;
  final bool isLoading;
  final String? error;
  // ID of the request currently being accepted or rejected.
  final String? actingRequestId;

  const CompanionsState({
    this.companions,
    this.incomingRequests,
    this.isLoading = false,
    this.error,
    this.actingRequestId,
  });

  int get incomingCount => incomingRequests?.length ?? 0;

  CompanionsState copyWith({
    List<AppUser>? companions,
    List<CompanionRequest>? incomingRequests,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? actingRequestId,
    bool clearActing = false,
  }) =>
      CompanionsState(
        companions: companions ?? this.companions,
        incomingRequests: incomingRequests ?? this.incomingRequests,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        actingRequestId:
            clearActing ? null : (actingRequestId ?? this.actingRequestId),
      );
}
