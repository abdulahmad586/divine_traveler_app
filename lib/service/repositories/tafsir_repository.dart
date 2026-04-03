import 'package:dio/dio.dart';

import '../../model/models.dart';
import '../app_storage.dart';

class TafsirRepository {
  // In-memory cache — fastest, lives for the session.
  static final Map<String, TafsirResponse> _memCache = {};

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

    // 1. In-memory hit — fastest path.
    if (_memCache.containsKey(key)) return _memCache[key]!;

    // 2. Persistent Hive cache — available immediately across sessions.
    final stored = AppStorage().getTafsirCache(key);
    if (stored != null) {
      final result = TafsirResponse.fromJson(stored);
      _memCache[key] = result;
      return result;
    }

    // 3. Network fetch — populate both caches for future use.
    try {
      final response = await dio.get('tafsir/$key.json');
      final result = TafsirResponse.fromJson(response.data);
      _memCache[key] = result;
      AppStorage().setTafsirCache(key, result.toJson());
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
