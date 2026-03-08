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

    // Add interceptors for automated retry and logging if needed
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) {
          // We can add retry logic here if needed, but for now just pass the error
          // to be caught by the methods below
          return handler.next(e);
        },
      ),
    );
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
