import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tahfeex/model/app_user_model.dart';
import 'package:tahfeex/service/app_storage.dart';
import 'package:tahfeex/service/auth_service.dart';
import 'package:tahfeex/service/repositories/user_repository.dart';

// ── Cubit ─────────────────────────────────────────────────────────────────────

class ProfileCubit extends Cubit<ProfileState> {
  final _repo = UserRepository();

  ProfileCubit() : super(const ProfileState()) {
    load();
  }

  Future<void> load() async {
    final cached = AppStorage().getProfileCache();
    if (cached != null) {
      emit(state.copyWith(isLoading: true, user: AppUser.fromJson(cached), clearError: true));
    } else {
      emit(state.copyWith(isLoading: true, clearError: true));
    }
    try {
      final user = await _repo.getMe();
      AppStorage().setProfileCache(user.toJson());
      emit(state.copyWith(isLoading: false, user: user));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: cached == null ? e.toString() : null));
    }
  }

  /// Returns the updated [AppUser] on success, throws on failure.
  Future<AppUser> updateUsername(String username) async {
    emit(state.copyWith(isSaving: true, clearSaveError: true));
    try {
      final updated = await _repo.updateUsername(username);
      AppStorage().setProfileCache(updated.toJson());
      emit(state.copyWith(isSaving: false, user: updated));
      return updated;
    } catch (e) {
      emit(state.copyWith(isSaving: false, saveError: e.toString()));
      rethrow;
    }
  }

  /// Deletes the account from the backend, clears local caches, then signs out.
  /// Throws on API failure — callers must handle the error.
  Future<void> deleteAccount() async {
    await _repo.deleteAccount();
    AppStorage().setProfileCache({});
    await AuthService().signOut();
  }

  Future<void> toggleAllowFriendRequests() async {
    final current = state.user;
    if (current == null) return;
    emit(state.copyWith(isSaving: true));
    try {
      final updated = await _repo.updateSettings(
        allowFriendRequests: !current.allowFriendRequests,
      );
      AppStorage().setProfileCache(updated.toJson());
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
