Quran Recitation Frontend Guide (Flutter)
1. Overview
   The Flutter frontend is responsible for:
   Authenticating the user with Google
   Uploading audio files + JSON timing data to the user's own Google Drive
   Setting public read permissions for uploaded files
   Sending metadata (fileIds, reciter name, surah, etc.) to the backend
   The backend only stores metadata; it does not handle file uploads.
2. Dependencies
```yaml
dependencies:
  google_sign_in: ^6.0.0
  googleapis: ^12.0.0
  http: ^1.0.0
  dio: ^6.0.0 # optional for sending metadata
```
3. Authentication
   Using `google_sign_in`
```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: [
    'https://www.googleapis.com/auth/drive.file', // allows uploading to Drive
  ],
);

final GoogleSignInAccount? user = await _googleSignIn.signIn();
final authHeaders = await user!.authHeaders;
```
The user must explicitly consent
Access token is used to upload files
4. Setting Up Google Drive Client
```dart
import 'package:googleapis/drive/v3.dart' as drive;

final client = GoogleAuthClient(authHeaders);
final driveApi = drive.DriveApi(client);
```
`GoogleAuthClient` is a helper that implements `http.Client` with the OAuth headers.
5. Uploading Files
   Optional: Create or select folder
   A. App-created folder
```dart
final folder = await driveApi.files.create(
  drive.File()
    ..name = 'QuranAppUploads'
    ..mimeType = 'application/vnd.google-apps.folder',
);
final folderId = folder.id;
```
Store `folderId` locally
All uploads go inside this folder
B. User-selected folder
Use Drive Picker (web is easier than Flutter)
Retrieve `folderId` from selection
Upload Audio
```dart
var audioFile = drive.File()
  ..name = 'surah_1_reciterX.mp3'
  ..parents = [folderId];

final result = await driveApi.files.create(
  audioFile,
  uploadMedia: drive.Media(File(audioPath).openRead(), audioSize),
);
final audioFileId = result.id;
```
Upload JSON Timing File
```dart
var jsonFile = drive.File()
  ..name = 'surah_1_reciterX.json'
  ..parents = [folderId];

final resultJson = await driveApi.files.create(
  jsonFile,
  uploadMedia: drive.Media(File(jsonPath).openRead(), jsonSize),
);
final timingFileId = resultJson.id;
```
6. Make Files Public
```dart
await driveApi.permissions.create(
  drive.Permission()
    ..type = 'anyone'
    ..role = 'reader',
  audioFileId,
);
await driveApi.permissions.create(
  drive.Permission()
    ..type = 'anyone'
    ..role = 'reader',
  timingFileId,
);
```
7. Send Metadata to Backend
```dart
final response = await dio.post(
  'https://your-backend.com/contributions',
  data: {
    'reciterName': 'Abdulrahman Al-Sudais',
    'surah': 1,
    'audioFileId': audioFileId,
    'timingFileId': timingFileId,
    'audioHash': audioHash, // optional hash for duplicates
  },
);
```
8. Duplicate Prevention (Optional)
   Compute SHA-256 hash of the audio before uploading
   Compare with backend metadata
   Skip upload if duplicate hash exists
9. UX Considerations
   Show progress bars during upload
   Confirm folder creation or selection
   Warn users if their file will be public
   Handle network failures gracefully
10. Error Handling
    Token expiration → reauthenticate
    Upload failure → retry or warn user
    Invalid metadata → validate before sending
11. Summary
    Frontend responsibilities:
    Google OAuth authentication
    Upload audio + JSON to user’s Drive
    Set public access
    Send metadata to backend
    Optionally handle duplicates
    Graceful error handling and UX
    Backend responsibilities:
    Store metadata
    Validate entries
    Serve contributions to other users