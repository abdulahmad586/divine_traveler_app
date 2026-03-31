import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tahfeex/shared/connections/connections.dart';

/// Handles Google → Firebase sign-in and wires the ID token into [DioClient].
///
/// Both the Firebase backend token and the Google Drive OAuth headers come from
/// the same [GoogleSignIn] session, so the user only signs in once.
class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  final _auth = FirebaseAuth.instance;

  // Only basic identity scopes at login.  Drive access is requested
  // incrementally in getGoogleAuthHeaders() when the user actually uploads.
  final _googleSignIn = GoogleSignIn(scopes: ['email']);

  // ── State ────────────────────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;

  /// Fires whenever the sign-in state changes (sign-in, sign-out, token refresh).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Sign-in ───────────────────────────────────────────────────────────────

  /// Opens the Google account picker, signs into Firebase, and wires the
  /// token provider into [DioClient].
  ///
  /// Returns `null` if the user cancels the picker.
  Future<User?> signInWithGoogle() async {
    debugPrint('[AuthService] starting Google sign-in');
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      debugPrint('[AuthService] sign-in cancelled by user');
      return null;
    }
    debugPrint('[AuthService] Google account: ${googleUser.email}');

    final googleAuth = await googleUser.authentication;
    debugPrint('[AuthService] got Google auth tokens — accessToken present: ${googleAuth.accessToken != null}, idToken present: ${googleAuth.idToken != null}');

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    debugPrint('[AuthService] signing into Firebase');
    final userCredential = await _auth.signInWithCredential(credential);
    debugPrint('[AuthService] Firebase sign-in success: ${userCredential.user?.uid}');
    _wireDioToken();
    return userCredential.user;
  }

  /// Attempts a silent sign-in (restores a previous session without UI).
  /// Called on app start to skip the login screen when already signed in.
  Future<User?> signInSilently() async {
    final googleUser = await _googleSignIn.signInSilently();
    if (googleUser == null) return null;

    // Firebase may already have a valid session — just refresh the token wire.
    if (_auth.currentUser != null) {
      _wireDioToken();
      return _auth.currentUser;
    }

    // Re-authenticate with Firebase using the restored Google credential.
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    _wireDioToken();
    return userCredential.user;
  }

  // ── Sign-out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    DioClient().setTokenProvider(null);
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  // ── Drive API helper ──────────────────────────────────────────────────────

  static const _driveScope = 'https://www.googleapis.com/auth/drive.file';

  /// Returns the OAuth headers needed to authenticate a googleapis [DriveApi]
  /// client.  Called only when the user initiates an upload — this is where
  /// we ask for Drive permission so the user understands why.
  ///
  /// If the scope isn't granted yet, shows Google's incremental-auth consent
  /// screen.  Throws if the user denies or is not signed in.
  Future<Map<String, String>> getGoogleAuthHeaders() async {
    final account = _googleSignIn.currentUser;
    if (account == null) throw Exception('Not signed in.');

    // requestScopes is a no-op (returns true) if the scope is already granted,
    // and shows the consent screen only when it isn't.
    final granted = await _googleSignIn.requestScopes([_driveScope]);
    if (!granted) {
      throw Exception(
          'Drive access is required to upload. Please grant permission and try again.');
    }

    return account.authHeaders;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _wireDioToken() {
    DioClient().setTokenProvider(() async {
      final user = _auth.currentUser;
      if (user == null) return null;
      return user.getIdToken();
    });
  }
}
