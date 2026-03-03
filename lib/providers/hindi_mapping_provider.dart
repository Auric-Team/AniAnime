import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../utils/string_utils.dart';
import 'anime_provider.dart';

// Provides the mapped Animelok ID for a given HiAnime ID and Title.
// It returns null if no Hindi version is found.
final hindiMappingProvider = FutureProvider.family<String?, Map<String, String>>((ref, params) async {
  final api = ref.read(apiServiceProvider);
  final hianimeId = params['id']!;
  final hianimeTitle = params['title']!;

  // Helper to check if a slug actually exists and has servers
  Future<String?> checkSlug(String slug) async {
    try {
      final res = await api.getAnimelokWatch(slug, 1).timeout(const Duration(seconds: 3));
      if (res != null && res['servers'] != null && (res['servers'] as List).isNotEmpty) {
        return slug;
      }
    } catch (_) {}
    return null;
  }

  // --- Phase 1: High Probability Direct Slugs & MAL Fetch (Concurrent) ---
  final strippedId = hianimeId.replaceAll(RegExp(r'-\d+$'), '');
  String titleSlug = hianimeTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  
  Set<String> candidatesToTest = {
    '$hianimeId-hindi-dubbed',
    hianimeId,
    '$strippedId-hindi-dubbed',
    strippedId,
    '$strippedId-hindi-dub',
    '$titleSlug-hindi-dubbed',
    titleSlug,
  };

  try {
    // Attempt to get MAL ID quickly, since it has the highest accuracy for English/Romaji names
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
    // If MAL fails or times out, we continue with direct slugs
  }

  // We test all unique candidates concurrently. 
  // We use Future.wait to fire them all off, but we return as soon as one completes successfully.
  final completer = Completer<String?>();
  int pending = candidatesToTest.length;
  
  for (final slug in candidatesToTest) {
    checkSlug(slug).then((result) {
      if (result != null && !completer.isCompleted) {
        completer.complete(result);
      } else {
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      }
    });
  }

  final matchedSlug = await completer.future;
  if (matchedSlug != null) return matchedSlug;

  return null; 
});
