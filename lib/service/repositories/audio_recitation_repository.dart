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

  /// Fetch verse audio (all reciters for a specific verse)
  Future<AudioResponse> getVerseAudio({
    required int surahNo,
    required int ayahNo,
  }) async {
    try {
      final response = await dio.get(
        'audio/$surahNo/$ayahNo.json',
      );

      return AudioResponse.fromJson(
        response.data,
        surahNo: surahNo,
        ayahNo: ayahNo,
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?.toString() ?? 'Failed to fetch verse audio',
      );
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }
}
