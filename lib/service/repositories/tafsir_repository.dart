import 'package:dio/dio.dart';

import '../../model/models.dart';

class TafsirRepository {
  static final Map<String, TafsirResponse> _cache = {};

  final Dio dio;

  TafsirRepository({Dio? dio})
      : dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://quranapi.pages.dev/api/',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ));

  Future<TafsirResponse> getTafsir({
    required int surahNo,
    required int ayahNo,
  }) async {
    final key = '${surahNo}_$ayahNo';
    if (_cache.containsKey(key)) return _cache[key]!;

    try {
      final response = await dio.get('tafsir/$key.json');
      final result = TafsirResponse.fromJson(response.data);
      _cache[key] = result;
      return result;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?.toString() ?? 'Failed to fetch tafsir',
      );
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }
}
