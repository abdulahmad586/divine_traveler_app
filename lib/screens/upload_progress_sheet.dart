import 'package:flutter/material.dart';
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/service/google_drive_service.dart';
import 'package:tahfeex/widgets/widgets.dart';

/// Shows a bottom sheet that drives a Google Drive upload and displays
/// step-by-step progress.  Call [UploadProgressSheet.show] as a convenience.
class UploadProgressSheet extends StatefulWidget {
  final SurahAudio surahAudio;
  final void Function(DriveUploadResult result)? onSuccess;
  /// When non-null, skips the Drive upload and immediately force-POSTs
  /// the metadata (used after DUPLICATE_RECITER_SURAH confirmation).
  final DriveUploadResult? pendingResult;

  const UploadProgressSheet({
    super.key,
    required this.surahAudio,
    this.onSuccess,
    this.pendingResult,
  });

  /// Show a fresh upload sheet.
  static Future<void> show(
    BuildContext context, {
    required SurahAudio surahAudio,
    void Function(DriveUploadResult)? onSuccess,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => UploadProgressSheet(
        surahAudio: surahAudio,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<UploadProgressSheet> createState() => _UploadProgressSheetState();
}

class _UploadProgressSheetState extends State<UploadProgressSheet> {
  final _service = GoogleDriveService();
  UploadProgress? _latest;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.pendingResult != null) {
        _forcePost(widget.pendingResult!);
      } else {
        _start();
      }
    });
  }

  void _start() {
    if (_started) return;
    _started = true;

    _service
        .upload(
          surahAudio: widget.surahAudio,
          onResult: widget.onSuccess ?? (_) {},
        )
        .listen(
          (p) { if (mounted) setState(() => _latest = p); },
          onError: (e) {
            if (mounted) setState(() => _latest = UploadProgress.error(e.toString()));
          },
        );
  }

  Future<void> _forcePost(DriveUploadResult result) async {
    setState(() => _latest = const UploadProgress(
          step: UploadStep.savingMetadata,
          fraction: 0.92,
          label: 'Saving to community…'));
    try {
      await _service.forcePostContribution(
          surahAudio: widget.surahAudio, result: result);
      widget.onSuccess?.call(result);
      if (mounted) {
        setState(() => _latest = const UploadProgress(
              step: UploadStep.done,
              fraction: 1.0,
              label: 'Shared with the community!'));
      }
    } catch (e) {
      if (mounted) setState(() => _latest = UploadProgress.error(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _latest;
    final isDone = p?.step == UploadStep.done && !(p?.isError ?? false);
    final isError = p?.isError ?? false;
    final needsForce = p?.needsForce ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Text(
            isDone
                ? 'Upload complete!'
                : isError
                    ? 'Upload failed'
                    : needsForce
                        ? 'Already submitted'
                        : 'Sharing with the community…',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.surahAudio.surahNameEnglish} — ${widget.surahAudio.reciterName}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // ── Step list ────────────────────────────────────────────────────
          if (widget.pendingResult == null) ...[
            _StepRow(label: 'Sign in to Google',
                state: _stepState(UploadStep.signingIn, p)),
            _StepRow(label: 'Prepare upload folder',
                state: _stepState(UploadStep.preparingFolder, p)),
            _StepRow(label: 'Upload audio file',
                state: _stepState(UploadStep.uploadingAudio, p)),
            _StepRow(label: 'Upload timing data',
                state: _stepState(UploadStep.uploadingTiming, p)),
            _StepRow(label: 'Set public access',
                state: _stepState(UploadStep.settingPermissions, p)),
          ],
          _StepRow(label: 'Save to community',
              state: _stepState(UploadStep.savingMetadata, p)),
          const SizedBox(height: 20),

          // ── Progress bar ─────────────────────────────────────────────────
          if (!isDone && !isError && !needsForce) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p?.fraction,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(p?.label ?? 'Starting…',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600])),
            const SizedBox(height: 20),
          ],

          // ── Duplicate reciter+surah dialog ───────────────────────────────
          if (needsForce) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You already have a submission for this surah. '
                      'Submit anyway to replace it?',
                      style: TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'SUBMIT ANYWAY',
                backgroundColor: AppColors.primaryColor,
                labelColor: Colors.white,
                onTap: () => _forcePost(p!.pendingResult!),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'CANCEL',
                backgroundColor: Colors.grey[200]!,
                labelColor: Colors.black87,
                onTap: () => Navigator.pop(context),
              ),
            ),
          ],

          // ── Error details ────────────────────────────────────────────────
          if (isError) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p?.errorMessage ?? 'An unexpected error occurred.',
                      style:
                          const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'CLOSE',
                backgroundColor: Colors.grey[200]!,
                labelColor: Colors.black87,
                onTap: () => Navigator.pop(context),
              ),
            ),
          ],

          // ── Success ──────────────────────────────────────────────────────
          if (isDone) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Other users can now benefit from your recitation.',
                      style: TextStyle(color: Colors.green, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'DONE',
                backgroundColor: AppColors.primaryColor,
                labelColor: Colors.white,
                onTap: () => Navigator.pop(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _StepRowState _stepState(UploadStep step, UploadProgress? p) {
    if (p == null) return _StepRowState.pending;
    // On needsForce, all steps up to savingMetadata are done.
    if (p.needsForce) {
      return step.index <= UploadStep.settingPermissions.index
          ? _StepRowState.done
          : _StepRowState.pending;
    }
    if (p.isError) {
      return step.index < p.step.index
          ? _StepRowState.done
          : _StepRowState.pending;
    }
    if (step.index < p.step.index) return _StepRowState.done;
    if (step == p.step) {
      return p.step == UploadStep.done
          ? _StepRowState.done
          : _StepRowState.active;
    }
    return _StepRowState.pending;
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Step row widget
// ──────────────────────────────────────────────────────────────────────────────

enum _StepRowState { pending, active, done }

class _StepRow extends StatelessWidget {
  final String label;
  final _StepRowState state;

  const _StepRow({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    Widget leading;
    Color labelColor;

    switch (state) {
      case _StepRowState.done:
        leading = const Icon(Icons.check_circle, color: Colors.green, size: 20);
        labelColor = Colors.black87;
      case _StepRowState.active:
        leading = SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.primaryColor),
        );
        labelColor = Colors.black87;
      case _StepRowState.pending:
        leading =
            Icon(Icons.radio_button_unchecked, color: Colors.grey[400], size: 20);
        labelColor = Colors.grey[400]!;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 14, color: labelColor)),
        ],
      ),
    );
  }
}
