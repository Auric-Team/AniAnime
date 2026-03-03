import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import 'anime_provider.dart';

final hindiMappingProvider = FutureProvider.family<String?, ({String id, String title})>((ref, params) async {
  final api = ref.read(apiServiceProvider);
  final hianimeId = params.id;
  final hianimeTitle = params.title;

  Future<String?> checkSlug(String slug) async {
    try {
      final res = await api.getAnimelokWatch(slug, 1).timeout(const Duration(seconds: 4));
      if (res != null && res['servers'] != null && (res['servers'] as List).isNotEmpty) {
        return slug;
      }
    } catch (_) {}
    return null;
  }

  Set<String> candidatesToTest = {};

  final strippedId = hianimeId.replaceAll(RegExp(r'-\d+$'), '');
  String titleSlug = hianimeTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  
  candidatesToTest.addAll([
    '$hianimeId-hindi-dubbed',
    hianimeId,
    '$strippedId-hindi-dubbed',
    strippedId,
    '$strippedId-hindi-dub',
    '$titleSlug-hindi-dubbed',
    titleSlug,
  ]);

  try {
    // Quickly attempt MAL integration for highest accuracy
    final info = await ref.read(animeInfoProvider(hianimeId).future).timeout(const Duration(seconds: 2));
    final malId = info['anime']?['info']?['malId'];
    
    if (malId != null && malId != 0) {
      final jikanResponse = await Dio().get('https://api.jikan.moe/v4/anime/$malId').timeout(const Duration(seconds: 2));
      final jikanData = jikanResponse.data['data'];
      
      if (jikanData != null) {
        if (jikanData['title_english'] != null) {
          String altSlug = jikanData['title_english'].toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
          candidatesToTest.add('$altSlug-hindi-dubbed');
          candidatesToTest.add(altSlug);
        }
        if (jikanData['title'] != null) {
          String altSlug = jikanData['title'].toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
          candidatesToTest.add('$altSlug-hindi-dubbed');
          candidatesToTest.add(altSlug);
        }
      }
    }
  } catch (_) {
    // Ignore MAL failure and proceed with direct slugs
  }

  // Fast concurrent execution with Future.wait for stability instead of Completer
  final results = await Future.wait(candidatesToTest.map((slug) => checkSlug(slug)));

  // Return the first successful match
  for (final res in results) {
    if (res != null) return res;
  }

  return null; 
});
