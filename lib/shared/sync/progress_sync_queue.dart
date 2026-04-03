import 'package:flutter/foundation.dart';
import 'package:tahfeex/service/app_storage.dart';
import 'package:tahfeex/service/repositories/journey_repository.dart';

/// Persists progress marks that haven't been confirmed by the server yet.
///
/// Each entry is encoded as `'journeyId:surah:ayah'` and stored in a Hive
/// list. Call [enqueue] immediately when the user marks an ayah, then call
/// [flush] (e.g. when the journey screen opens) to drain the queue while the
/// device is online. Failures silently stay in the queue.
class ProgressSyncQueue {
  static final ProgressSyncQueue _instance = ProgressSyncQueue._internal();
  factory ProgressSyncQueue() => _instance;
  ProgressSyncQueue._internal();

  static const _key = 'prog_sync_queue';
  bool _flushing = false;

  // ── Hive helpers ────────────────────────────────────────────────────────────

  List<String> _read() {
    final raw = AppStorage().box?.get(_key, defaultValue: <String>[]);
    if (raw is List) return raw.cast<String>().toList();
    return [];
  }

  void _write(List<String> items) => AppStorage().box?.put(_key, items);

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Adds an entry if not already queued. Idempotent.
  void enqueue(String journeyId, int surah, int ayah) {
    final entry = '$journeyId:$surah:$ayah';
    final items = _read();
    if (!items.contains(entry)) {
      items.add(entry);
      _write(items);
    }
  }

  /// Returns the set of `'surah_ayah'` keys for a journey that are pending
  /// sync. Used to overlay local completions on top of server state.
  Set<String> pendingFor(String journeyId) {
    return _read()
        .where((e) => e.startsWith('$journeyId:'))
        .map((e) {
          final parts = e.split(':');
          return '${parts[1]}_${parts[2]}';
        })
        .toSet();
  }

  /// Removes one specific entry after the server confirms it.
  void removeEntry(String journeyId, int surah, int ayah) {
    final entry = '$journeyId:$surah:$ayah';
    final items = _read()..remove(entry);
    _write(items);
  }

  /// Attempts to sync every pending item. Items that fail stay in the queue.
  /// Safe to call concurrently — a second call while flushing is a no-op.
  Future<void> flush(JourneyRepository repo) async {
    if (_flushing) return;
    _flushing = true;
    try {
      final items = _read();
      if (items.isEmpty) return;
      final remaining = <String>[];
      for (final entry in items) {
        final parts = entry.split(':');
        if (parts.length != 3) continue; // malformed — discard silently
        final journeyId = parts[0];
        final surah     = int.tryParse(parts[1]);
        final ayah      = int.tryParse(parts[2]);
        if (surah == null || ayah == null) continue;
        try {
          await repo.updateProgress(id: journeyId, surah: surah, ayah: ayah);
        } catch (e) {
          debugPrint('[ProgressSyncQueue] flush failed for $entry: $e');
          remaining.add(entry);
        }
      }
      _write(remaining);
    } finally {
      _flushing = false;
    }
  }
}
