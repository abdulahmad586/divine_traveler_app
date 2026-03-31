import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/shared/connections/connections.dart';
import 'package:tahfeex/shared/constants/constants.dart';
import 'package:tahfeex/shared/models/models.dart';

/// Wraps all `/contributions` endpoints defined in API.md.
///
/// **Duplicate-submission flow** (see API.md):
///   1. Call [postContribution] with `force: false` (default).
///   2. If [ApiException.isDuplicateHash] — hard block, show error.
///   3. If [ApiException.isDuplicateReciterSurah] — soft block:
///        ask the user "You already submitted this surah, submit anyway?"
///        then call [postContribution] again with `force: true`.
class ContributionRepository {
  final _client = DioClient();

  /// Submit a new contribution.
  ///
  /// Throws [ApiException] on 4xx/5xx — including:
  ///   • [ApiException.isDuplicateHash] (409) — hard block, no override.
  ///   • [ApiException.isDuplicateReciterSurah] (409) — call again with [force]=true
  ///     after confirming with the user.
  Future<ContributionModel> postContribution({
    required String reciterName,
    required int surah,
    required String audioFileId,
    required String timingFileId,
    required String audioHash,
    bool force = false,
  }) async {
    final data = await _client.post(
      ApiConstants.contributions,
      data: {
        'reciterName': reciterName,
        'surah': surah,
        'audioFileId': audioFileId,
        'timingFileId': timingFileId,
        'audioHash': audioHash,
        'force': force,
      },
    );
    return ContributionModel.fromMap(data as Map<String, dynamic>);
  }

  /// Fetch all approved contributions for [surah] (1–114).
  /// Returns `[]` when none exist.
  Future<List<ContributionModel>> getContributionsBySurah(int surah) async {
    final data = await _client.get(
      ApiConstants.contributions,
      queryParameters: {'surah': surah},
    );
    return ContributionModel.parseList(data as List<dynamic>);
  }

  /// Fetch a single contribution by its [id].
  /// Throws [ApiException] with [ApiException.isNotFound] when missing.
  Future<ContributionModel> getContributionById(String id) async {
    final data = await _client.get(ApiConstants.contributionById(id));
    return ContributionModel.fromMap(data as Map<String, dynamic>);
  }

  /// Increment the `likes` counter.  Auth required.
  /// Returns void on 204; throws [ApiException] on error.
  Future<void> likeContribution(String id) async {
    await _client.post(ApiConstants.likeContribution(id));
  }

  /// Record a download event (increments `downloads`).  Auth required.
  /// Call this once when the user actually downloads the audio file.
  Future<void> recordDownload(String id) async {
    await _client.post(ApiConstants.downloadContribution(id));
  }

  /// Delete a contribution.  Auth required; only the original submitter may delete.
  /// Throws [ApiException] with [ApiException.isForbidden] if not the owner.
  Future<void> deleteContribution(String id) async {
    await _client.delete(ApiConstants.contributionById(id));
  }
}
