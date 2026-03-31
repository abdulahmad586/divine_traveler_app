import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tahfeex/model/companion_models.dart';
import 'package:tahfeex/service/repositories/companion_repository.dart';

// ── Cubit ─────────────────────────────────────────────────────────────────────

class UserProfileCubit extends Cubit<UserProfileState> {
  final _repo = CompanionRepository();
  final String username;

  UserProfileCubit(this.username) : super(const UserProfileState()) {
    load();
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final profile = await _repo.getUserProfile(username);
      String? pendingRequestId;

      // Fetch the request ID needed for accept/cancel actions.
      if (profile.relationship?.sentRequest == true) {
        final outgoing = await _repo.getOutgoingRequests();
        for (final r in outgoing) {
          if (r.toUsername == username) {
            pendingRequestId = r.id;
            break;
          }
        }
      } else if (profile.relationship?.receivedRequest == true) {
        final incoming = await _repo.getIncomingRequests();
        for (final r in incoming) {
          if (r.fromUsername == username) {
            pendingRequestId = r.id;
            break;
          }
        }
      }

      emit(state.copyWith(
        isLoading: false,
        profile: profile,
        pendingRequestId: pendingRequestId,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> sendRequest() => _act(() => _repo.sendRequest(username));

  Future<void> cancelRequest() async {
    final id = state.pendingRequestId;
    if (id == null) return;
    await _act(() => _repo.cancelOrRejectRequest(id));
  }

  Future<void> acceptRequest() async {
    final id = state.pendingRequestId;
    if (id == null) return;
    await _act(() => _repo.acceptRequest(id));
  }

  Future<void> removeCompanion() async {
    final userId = state.profile?.id;
    if (userId == null) return;
    await _act(() => _repo.removeCompanion(userId));
  }

  Future<void> block() async {
    await _act(() => _repo.block(username));
  }

  Future<void> unblock() async {
    final userId = state.profile?.id;
    if (userId == null) return;
    await _act(() => _repo.unblock(userId));
  }

  /// Runs [action], sets isActing, reloads profile on success, surfaces error.
  Future<void> _act(Future<dynamic> Function() action) async {
    emit(state.copyWith(isActing: true, clearActionError: true));
    try {
      await action();
      await load();
    } catch (e) {
      emit(state.copyWith(isActing: false, actionError: e.toString()));
    }
  }
}

// ── State ─────────────────────────────────────────────────────────────────────

class UserProfileState {
  final UserProfile? profile;
  final bool isLoading;
  final String? error;
  final bool isActing;
  final String? actionError;
  // The ID of a pending companion request (sent or received) needed for
  // accept / cancel actions.
  final String? pendingRequestId;

  const UserProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
    this.isActing = false,
    this.actionError,
    this.pendingRequestId,
  });

  UserProfileState copyWith({
    UserProfile? profile,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isActing,
    String? actionError,
    bool clearActionError = false,
    String? pendingRequestId,
  }) =>
      UserProfileState(
        profile: profile ?? this.profile,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        isActing: isActing ?? this.isActing,
        actionError:
            clearActionError ? null : (actionError ?? this.actionError),
        pendingRequestId: pendingRequestId ?? this.pendingRequestId,
      );
}
