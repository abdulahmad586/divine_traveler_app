# Bug Hunt — Tahfeex

> Audited: 2026-03-28
> Scope: all Dart source files under `lib/`

---

## BUG-01 — `dispose()` calls `super.dispose()` before releasing resources

**Severity:** High
**Files:**
- `lib/screens/new_audio_screen.dart:50`
- `lib/screens/audio_training_screen.dart:49`

**Description:**
Both screens call `super.dispose()` as the *first* statement in `dispose()`. This is incorrect — calling `super.dispose()` marks the widget as disposed, making any subsequent access to the widget's state (including controller `.dispose()` calls) undefined behavior. Flutter's contract is that `super.dispose()` must be called **last**.

Additionally, `_AudioTrainingScreenState.dispose()` (audio_training_screen.dart) calls `super.dispose()` and exits without disposing the `MyAudioPlayer` (which holds a live `just_audio.AudioPlayer`), resulting in a resource leak.

**In `new_audio_screen.dart`:**
```dart
// Current (wrong order)
@override
void dispose() {
  super.dispose();       // ← called first
  recitationTitle.dispose();
  recitersName.dispose();
  trackDuration.dispose();
  fileHash.dispose();
  // fileSize is never disposed at all (see BUG-02)
}
```

---

## BUG-02 — `fileSize` TextEditingController never disposed

**Severity:** Medium
**File:** `lib/screens/new_audio_screen.dart:54`

**Description:**
`fileSize` is a `TextEditingController` created in `initState()` but is missing from `dispose()`. This leaks a listener/resource that is never cleaned up.

```dart
// dispose() disposes these four:
recitationTitle.dispose();
recitersName.dispose();
trackDuration.dispose();
fileHash.dispose();
// fileSize.dispose() ← missing
```

---

## BUG-03 — `setState` called after dispose in `new_audio_screen.dart`

**Severity:** High
**File:** `lib/screens/new_audio_screen.dart:198–223`

**Description:**
The "CONTINUE" button sets `loading = true` then schedules work with `Future.delayed(Duration(seconds: 3), ...)`. Inside the delayed callback, `setState()` and `context` are used without a `mounted` guard. If the user navigates away within 3 seconds, the widget is disposed and these calls throw `"setState() called after dispose()"`.

```dart
AppButton(
  onTap: () {
    setState(() => loading = true);
    Future.delayed(const Duration(seconds: 3), () {
      setState(() => loading = false);   // ← no mounted check
      widget.onSurahAdd?.call(...);
      NavUtils.navTo(context, SuccessPage(...)); // ← context may be stale
    });
  },
),
```

---

## BUG-04 — `onPositionChanged` stream never cancelled — audio stream leak

**Severity:** High
**File:** `lib/utils/my_audio_player.dart:69–77`

**Description:**
`onPositionChanged` uses `await for` on a position stream that never completes:

```dart
void onPositionChanged(Function(Duration) onChanged) async {
  await for (Duration position in _audioPlayer.createPositionStream(...)) {
    onChanged(position);
    // break was commented out ← intentional stream leak
  }
}
```

When `stop()` or `pause()` is called, the `AudioPlayer` stops emitting but the `await for` loop just waits indefinitely, holding the closure and all referenced objects alive. Since `play()` calls this every time a new file is loaded, multiple orphaned stream listeners accumulate over a session.

The fix requires keeping a `StreamSubscription` reference and cancelling it on `stop()`.

---

## BUG-05 — `stop()` modifies state outside `setState` — UI not rebuilt

**Severity:** Medium
**File:** `lib/utils/my_audio_player.dart:55–63`

**Description:**
`stop()` sets `playing = false` and `initialisedPlayback = false` directly, bypassing `setState`. The `setState` block was commented out:

```dart
void stop({required bool Function()? isMounted}) {
  _audioPlayer.stop();
  // if(isMounted !=null && isMounted() ){
  //   setState(() {
      playing = false;
      initialisedPlayback = false;
  //   });
  // }
}
```

As a result, when audio is stopped (e.g., on `deactivate`, on surah change), the play/pause button does not update. The icon stays on "pause" even though playback has stopped.

---

## BUG-06 — Force-unwrap after nullable default in `onPageChanged` (`quran_reader.dart` & `tafseer_screen.dart`)

**Severity:** High
**Files:**
- `lib/screens/quran_reader.dart:108–111`
- `lib/screens/tafseer_screen.dart:109–112`

**Description:**
`currentPage` is nullable (`int?`). The code handles the null case for computing `id` with `??`, but then immediately force-unwraps the same variable:

```dart
// quran_reader.dart
int id = totalPages - (currentPage ?? totalPages); // safe
List pageData = getPageData(currentPage!);          // ← crash if null
```

If `currentPage` is ever `null` (which is possible per the API signature), line `currentPage!` throws `Null check operator used on a null value`.

Additionally, when `currentPage` is `null`, `id = totalPages - totalPages = 0`, and `setSurahLabel(0)` is called. Page 0 is outside the valid range 1–604, which will cause `getPageData(0)` to throw or return unexpected results.

---

## BUG-07 — `setSurahNumber` callback assigned but never invoked — surah state not updated

**Severity:** High
**File:** `lib/screens/memorization_page.dart:282–293`

**Description:**
When the user selects a surah from the `SurahSelector` modal in the memorization screen, the code stores a closure in `setSurahNumber` and then moves the page view, but `setSurahNumber` is never called:

```dart
onSurahSelected: (int surahNumber) {
  setSurahNumber = () {          // ← stored but never invoked
    setState(() {
      this.surahNumber = surahNumber;
      ayahFrom = 1;
      ayah = ayahFrom;
      ayahTo = getVerseCount(surahNumber);
    });
  };
  var surahFirstPage = getSurahPages(surahNumber).first;
  controller.move(totalPages - surahFirstPage); // ← page moves but state doesn't
}
```

The page view navigates to the correct page, but `surahNumber`, `ayahFrom`, `ayah`, `ayahTo` remain unchanged. Audio playback still references the old surah, and the "from/to" ayah markers are wrong.

Compare with the commented-out helper file (`memoriztion_page_helper.dart`), which called `setSurahNumber?.call()` inside `setSurahLabel` — that call path was lost when the file was refactored.

---

## BUG-08 — `setPageLabels` does not update `surahNumber` on page swipe

**Severity:** High
**File:** `lib/screens/memorization_page.dart:151–174`

**Description:**
When the user manually swipes the page, `onPageChanged` → `setPageLabels` runs. `setPageLabels` updates `surahLabel`, `juzNumber`, `ayahFrom`, `surahFrom`, `surahTo`, and `ayahTo` from `getPageData(page).first['surah']`, but **never updates `surahNumber`**.

`surahNumber` drives which audio is loaded (`loadSurahAudio(surahNumber)`). After swiping to a page belonging to a different surah, `surahNumber` still points to the old surah. Pressing play will load and play the wrong surah's audio.

---

## BUG-09 — Dead code: `if (ayah == -1)` can never be true

**Severity:** Low
**File:** `lib/screens/memorization_page.dart:161`

**Description:**
`ayah` is initialised to `1` (line 30) and is never set to `-1` anywhere. The guard condition is dead:

```dart
int ayah = 1;   // line 30
...
if(ayah == -1){ // line 161 — never true
  ayah = ayahFrom;
}
```

---

## BUG-10 — `AppSettings` getters return nullable `dynamic` typed as `int`

**Severity:** High
**File:** `lib/service/app_settings.dart:16–19`

**Description:**
Both property getters have return type `int`, but the actual expression can return `null` when `box` is null (before Hive is initialised):

```dart
int get arabicTextSize => box?.get("arabicTextSize", defaultValue: 14); // returns int?
int get englishTextSize => box?.get("englishTextSize", defaultValue: 14); // returns int?
```

When `box` is null, `box?.get(...)` evaluates to `null`. Dart's sound null safety means assigning `null` to `int` causes a runtime cast exception. This will crash on first launch or if the settings box fails to open.

`SettingsCubit._loadSettings()` (called in the constructor) invokes these getters immediately, which means the app will crash on startup in this scenario.

---

## BUG-11 — Concurrent `Hive.init()` calls from `AppStorage` and `AppSettings`

**Severity:** Medium
**File:** `lib/service/app_config.dart:18`, `lib/service/app_storage.dart:38`, `lib/service/app_settings.dart:30`

**Description:**
`AppConfig.configure()` calls both `storage.initHive()` and `settings.initHive()` concurrently via `Future.wait`:

```dart
await Future.wait([storage.initHive(), settings.initHive()]);
```

Both `initHive()` methods call `Hive.init(config.appStoreBoxPath)`. Running two `Hive.init()` calls concurrently (before either sets `initialisedHive = true`) can trigger a Hive error because `Hive.init` is not idempotent in all versions. In addition, the `initialisedHive` flag is per-class, so the race condition is real — both will enter the `if (!initialisedHive)` block simultaneously.

---

## BUG-12 — `TapAndPanGestureRecognizer` created in `build()` — gesture recognizer leak

**Severity:** Medium
**File:** `lib/widgets/arabic_page_viewer.dart:80`

**Description:**
A `TapAndPanGestureRecognizer` is created inside the `build()` method of a `StatelessWidget` on every rebuild:

```dart
TapAndPanGestureRecognizer recognizer = TapAndPanGestureRecognizer();
```

Flutter's `TextSpan` takes ownership of gesture recognizers but does not dispose them when the `RichText` is rebuilt. This is a well-documented Flutter pitfall: each rebuild leaks the previous recognizer. For a page with many ayahs, this quickly accumulates.

The fix is to create and dispose recognizers in a `StatefulWidget`.

---

## BUG-13 — "Delete file" menu option is a no-op

**Severity:** Medium
**File:** `lib/screens/audio_files_screen.dart:78–85`

**Description:**
The `MorePopup` shows two options: `"Delete record"` (index 0) and `"Delete file"` (index 1). The `onAction` handler only handles case 0:

```dart
onAction: (i) {
  switch(i) {
    case 0:
      BlocProvider.of<AudioFilesCubit>(context).removeSurahAudio(index);
      break;
    // case 1 ("Delete file") ← not handled, silently does nothing
  }
},
```

Tapping "Delete file" does nothing — the actual file on disk is never deleted.

---

## BUG-14 — `PageButton` scroll target uses `MediaQuery.of(context).size.width` at attachment time — wrong target

**Severity:** Low
**File:** `lib/widgets/page_button.dart:38–40`

**Description:**
The `ScrollController.onAttach` callback fires immediately on attach and tries to scroll to `MediaQuery.of(context).size.width`. This is an arbitrary pixel offset (screen width) rather than the position of the current page button, so the auto-scroll lands at a random point. The current-page button is never guaranteed to be centered.

---

## BUG-15 — `WillPopScope` is deprecated

**Severity:** Low
**File:** `lib/screens/audio_training_screen.dart:124`

**Description:**
`WillPopScope` was deprecated in Flutter 3.12 and removed in 3.16 in favour of `PopScope`. Using it in new code produces deprecation warnings and will break on newer Flutter SDK versions.

```dart
return WillPopScope(
  onWillPop: () async {
    Navigator.of(context).pop(widget.surahAudio);
    return true;
  },
  ...
```

---

## BUG-16 — `textScaleFactor` is deprecated on `Text` widgets

**Severity:** Low
**Files:**
- `lib/screens/memorization_page.dart:545, 598`
- `lib/screens/audio_training_screen.dart:317, 330`
- `lib/widgets/surah_selector.dart:28`
- `lib/widgets/juz_selector.dart:34`

**Description:**
`textScaleFactor` on `Text` was deprecated in Flutter 3.x in favour of `TextScaler`. All usages will produce deprecation warnings.

---

## BUG-17 — `controlPosition` not clamped — controls can be dragged off-screen

**Severity:** Low
**Files:**
- `lib/screens/memorization_page.dart:496–499`
- `lib/screens/audio_training_screen.dart:286–289`

**Description:**
Dragging the controls panel uses `globalPosition.dy` to compute `controlPosition` with no clamping:

```dart
controlPosition = screenHeight - details.globalPosition.dy;
```

This allows `controlPosition` to become negative (controls off the bottom) or exceed `screenHeight` (controls off the top), making the controls inaccessible with no way to recover.

---

## BUG-18 — `addNewFile` in `memorization_page.dart` overwrites existing audio entries

**Severity:** Medium
**File:** `lib/screens/memorization_page.dart:248–256`

**Description:**
When a new audio file is added via the memorization screen's play button, the `onSurahAdd` callback calls:

```dart
storage.setAudioSurahs(surahNumber, SurahAudio.toJsonArray([surahAudio]));
```

This serialises a list with only the *new* entry, completely overwriting any previously stored audio files for that surah. Any existing recordings the user had for that surah are permanently lost.

The `AudioFilesScreen` flow (via `AudioFilesCubit.addSurahAudio`) correctly appends to the existing list, but the memorization screen's shortcut path does not.

---

## Summary Table

| ID | Severity | File(s) | Description |
|----|----------|---------|-------------|
| BUG-01 | High | `new_audio_screen.dart`, `audio_training_screen.dart` | `super.dispose()` called first; audio player not disposed |
| BUG-02 | Medium | `new_audio_screen.dart` | `fileSize` controller never disposed |
| BUG-03 | High | `new_audio_screen.dart` | No `mounted` guard in `Future.delayed` — setState after dispose |
| BUG-04 | High | `my_audio_player.dart` | Position stream never cancelled — accumulating stream leak |
| BUG-05 | Medium | `my_audio_player.dart` | `stop()` mutates state outside `setState` — UI stale |
| BUG-06 | High | `quran_reader.dart`, `tafseer_screen.dart` | Force-unwrap after nullable default causes crash |
| BUG-07 | High | `memorization_page.dart` | Surah selector callback stored but never called — state not updated |
| BUG-08 | High | `memorization_page.dart` | Page swipe doesn't update `surahNumber` — wrong audio plays |
| BUG-09 | Low | `memorization_page.dart` | Dead code: `ayah == -1` is never true |
| BUG-10 | High | `app_settings.dart` | Getters return nullable `dynamic` declared as `int` — startup crash |
| BUG-11 | Medium | `app_config.dart`, `app_storage.dart`, `app_settings.dart` | Concurrent `Hive.init()` calls race condition |
| BUG-12 | Medium | `arabic_page_viewer.dart` | Gesture recognizers created in `build()` — leak on every rebuild |
| BUG-13 | Medium | `audio_files_screen.dart` | "Delete file" menu option does nothing |
| BUG-14 | Low | `page_button.dart` | Auto-scroll target uses screen width, not current-page position |
| BUG-15 | Low | `audio_training_screen.dart` | `WillPopScope` deprecated, broken in Flutter ≥3.16 |
| BUG-16 | Low | Multiple files | `textScaleFactor` deprecated in favour of `TextScaler` |
| BUG-17 | Low | `memorization_page.dart`, `audio_training_screen.dart` | Controls drag position not clamped — can go off-screen |
| BUG-18 | Medium | `memorization_page.dart` | Adding audio via memorization screen overwrites all existing entries |
