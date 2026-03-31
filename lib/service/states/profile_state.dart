import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tahfeex/model/app_user_model.dart';
import 'package:tahfeex/service/repositories/user_repository.dart';

// ── Cubit ─────────────────────────────────────────────────────────────────────

class ProfileCubit extends Cubit<ProfileState> {
  final _repo = UserRepository();

  ProfileCubit() : super(const ProfileState()) {
    load();
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await _repo.getMe();
      emit(state.copyWith(isLoading: false, user: user));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Returns the updated [AppUser] on success, throws on failure.
  Future<AppUser> updateUsername(String username) async {
    emit(state.copyWith(isSaving: true, clearSaveError: true));
    try {
      final updated = await _repo.updateUsername(username);
      emit(state.copyWith(isSaving: false, user: updated));
      return updated;
    } catch (e) {
      emit(state.copyWith(isSaving: false, saveError: e.toString()));
      rethrow;
    }
  }

  Future<void> toggleAllowFriendRequests() async {
    final current = state.user;
    if (current == null) return;
    emit(state.copyWith(isSaving: true));
    try {
      final updated = await _repo.updateSettings(
        allowFriendRequests: !current.allowFriendRequests,
      );
      emit(state.copyWith(isSaving: false, user: updated));
    } catch (e) {
      emit(state.copyWith(isSaving: false, saveError: e.toString()));
    }
  }
}

// ── State ─────────────────────────────────────────────────────────────────────

class ProfileState {
  final AppUser? user;
  final bool isLoading;
  final String? error;
  final bool isSaving;
  final String? saveError;

  const ProfileState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isSaving = false,
    this.saveError,
  });

  ProfileState copyWith({
    AppUser? user,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isSaving,
    String? saveError,
    bool clearSaveError = false,
  }) =>
      ProfileState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        isSaving: isSaving ?? this.isSaving,
        saveError: clearSaveError ? null : (saveError ?? this.saveError),
      );
}
