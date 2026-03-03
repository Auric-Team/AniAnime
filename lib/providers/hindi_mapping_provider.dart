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

  // Strategy 1: Try direct ID match (since Animelok uses HiAnime-style IDs)
  try {
    final directCheck = await api.getAnimelokWatch(hianimeId, 1);
    if (directCheck != null && directCheck['servers'] != null) {
      return hianimeId; // Direct match works!
    }
  } catch (_) {}

  // Function to search and fuzzy match against a given target title
  Future<String?> searchAndMatch(String targetTitle) async {
    try {
      final searchData = await api.searchAnimelok(targetTitle);
      if (searchData != null && searchData['animes'] != null) {
        final List<dynamic> animes = searchData['animes'];
        if (animes.isNotEmpty) {
          final List<String> candidateTitles = animes.map((a) => a['title'].toString()).toList();
          final matchResult = StringUtils.findBestMatch(targetTitle, candidateTitles);
          
          if (matchResult.score > 0.6) {
            return animes[matchResult.index]['id'].toString();
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // Strategy 2: Robust Search and Fuzzy Match using original title
  String? matchedId = await searchAndMatch(hianimeTitle);
  if (matchedId != null) return matchedId;

  // Strategy 3: Try to get MAL ID and fetch alternative titles via Jikan API
  try {
    // Wait for the info provider to finish or fetch it directly
    final info = await ref.read(animeInfoProvider(hianimeId).future);
    final malId = info['anime']?['info']?['malId'];
    
    if (malId != null && malId != 0) {
      final jikanResponse = await Dio().get('https://api.jikan.moe/v4/anime/$malId');
      final jikanData = jikanResponse.data['data'];
      
      if (jikanData != null) {
        // Collect titles
        final List<String> altTitles = [];
        if (jikanData['title_english'] != null) altTitles.add(jikanData['title_english']);
        if (jikanData['title'] != null) altTitles.add(jikanData['title']);
        
        final titlesArray = jikanData['titles'] as List<dynamic>? ?? [];
        for (var t in titlesArray) {
          if (t['title'] != null) altTitles.add(t['title'].toString());
        }

        // Try searching with alternative titles
        for (final altTitle in altTitles.toSet()) {
          if (altTitle.toLowerCase() == hianimeTitle.toLowerCase()) continue; // already tried
          
          matchedId = await searchAndMatch(altTitle);
          if (matchedId != null) return matchedId;
        }
      }
    }
  } catch (e) {
    debugPrint('MAL fallback error: $e');
  }

  return null; // Hindi not available
});
