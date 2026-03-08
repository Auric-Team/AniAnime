import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';

class ApiService {
  late Dio _dio;

  ApiService() {
    _initDio();
  }

  void _initDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: Duration(seconds: AppConfig.connectTimeout),
        receiveTimeout: Duration(seconds: AppConfig.receiveTimeout),
      ),
    );

    // Add interceptor for automated retry and logging with exponential backoff
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) async {
          // Check if we should retry (e.g. timeout, 5xx server errors, no connection)
          final shouldRetry =
              _shouldRetry(e) && (e.requestOptions.extra['retries'] ?? 0) < 3;

          if (shouldRetry) {
            final int retryCount = (e.requestOptions.extra['retries'] ?? 0) + 1;
            e.requestOptions.extra['retries'] = retryCount;

            // Exponential backoff: 2^retryCount * 500ms + random jitter (faster retries)
            final retryDelay = Duration(
              milliseconds:
                  (pow(2, retryCount) * 500).toInt() + Random().nextInt(300),
            );

            await Future.delayed(retryDelay);

            try {
              // Create a completely new Dio client for the retry to avoid interceptor loops
              // that might occur if we just called _dio.fetch(e.requestOptions)
              final result = await Dio().fetch(e.requestOptions);
              return handler.resolve(result);
            } catch (retryError) {
              if (retryError is DioException) {
                // If the retry itself fails, pass the new error to the interceptor again
                // it will hit this onError block and evaluate if it should retry further
                return handler.next(retryError);
              }
            }
          }

          // Max retries reached or not a retryable error
          return handler.next(e);
        },
      ),
    );
  }

  bool _shouldRetry(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }
    if (err.response != null) {
      final statusCode = err.response!.statusCode;
      // Retry on internal server errors or rate limits
      if (statusCode != null && (statusCode >= 500 || statusCode == 429)) {
        return true;
      }
    }
    return false;
  }

  // --- HiAnime Endpoints ---

  Future<Map<String, dynamic>?> getHomeData() async {
    try {
      final response = await _dio.get('/hianime/home');
      return response.data['data'];
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAnimeInfo(String id) async {
    try {
      final response = await _dio.get('/hianime/anime/$id');
      return response.data['data'];
    } catch (e) {
      return null;
    }
  }

  Future<List<dynamic>?> getAnimeEpisodes(String id) async {
    try {
      final response = await _dio.get('/hianime/anime/$id/episodes');
      return response.data['data']['episodes'];
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> searchHiAnime(
    String query, {
    int page = 1,
  }) async {
    try {
      final response = await _dio.get(
        '/hianime/search',
        queryParameters: {'q': query, 'page': page},
      );
      return response.data['data'];
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getHiAnimeEpisodeSources(
    String episodeId,
    String category, [
    String? server,
  ]) async {
    try {
      // category can be 'sub' or 'dub'
      final queryParams = {'animeEpisodeId': episodeId, 'category': category};

      if (server != null) {
        queryParams['server'] = server;
      }

      final response = await _dio.get(
        '/hianime/episode/sources',
        queryParameters: queryParams,
      );
      return response.data['data'];
    } catch (e) {
      return null;
    }
  }

  // --- Animelok Endpoints (Hindi) ---

  /// Binary search to find max available Hindi episode
  Future<int> getAnimelokEpisodeCount(String slug) async {
    int lo = 1, hi = 100, best = 0;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      try {
        final res = await getAnimelokWatch(slug, mid);
        if (res != null &&
            res['servers'] != null &&
            (res['servers'] as List).isNotEmpty) {
          best = mid;
          lo = mid + 1;
        } else {
          hi = mid - 1;
        }
      } catch (_) {
        hi = mid - 1;
      }
    }
    return best;
  }

  Future<Map<String, dynamic>?> searchAnimelok(String query) async {
    try {
      final response = await _dio.get(
        '/animelok/search',
        queryParameters: {'q': query},
      );
      return response.data['data'];
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAnimelokWatch(
    String id,
    int episodeNumber,
  ) async {
    try {
      final response = await _dio.get(
        '/animelok/watch/$id',
        queryParameters: {'ep': episodeNumber},
      );
      return response.data['data'];
    } catch (e) {
      return null; // Means Hindi might not be available for this ID or episode
    }
  }
}

final apiServiceProvider = Provider((ref) => ApiService());
