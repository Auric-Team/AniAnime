import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiService {
  static const String baseUrl = 'https://api.tatakai.me/api/v1';
  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  // --- HiAnime Endpoints ---

  Future<Map<String, dynamic>> getHomeData() async {
    try {
      final response = await _dio.get('/hianime/home');
      return response.data['data'];
    } catch (e) {
      throw Exception('Failed to load home data: $e');
    }
  }

  Future<Map<String, dynamic>> getAnimeInfo(String id) async {
    try {
      final response = await _dio.get('/hianime/anime/$id');
      return response.data['data'];
    } catch (e) {
      throw Exception('Failed to load anime info: $e');
    }
  }

  Future<List<dynamic>> getAnimeEpisodes(String id) async {
    try {
      final response = await _dio.get('/hianime/anime/$id/episodes');
      return response.data['data']['episodes'];
    } catch (e) {
      throw Exception('Failed to load episodes: $e');
    }
  }

  Future<Map<String, dynamic>> getHiAnimeEpisodeSources(String episodeId, String category) async {
    try {
      // category can be 'sub' or 'dub'
      final response = await _dio.get(
        '/hianime/episode/sources',
        queryParameters: {
          'animeEpisodeId': episodeId,
          'category': category,
        },
      );
      return response.data['data'];
    } catch (e) {
      throw Exception('Failed to load sources: $e');
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

  Future<Map<String, dynamic>?> getAnimelokWatch(String id, int episodeNumber) async {
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
