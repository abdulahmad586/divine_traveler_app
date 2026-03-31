import 'package:dio/dio.dart';

import '../../model/models.dart';

class AudioRepository {
  final Dio dio;

  AudioRepository({Dio? dio})
      : dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://quranapi.pages.dev/api/',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ));

  /// Fetch full surah audio (all reciters)
  Future<AudioResponse> getSurahAudio({
    required int surahNo,
  }) async {
    try {
      final response = await dio.get(
        'audio/$surahNo.json',
      );

      return AudioResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?.toString() ?? 'Failed to fetch surah audio',
      );
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }
}
