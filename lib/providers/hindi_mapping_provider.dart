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

  // We will build a list of candidate IDs to test directly
  Set<String> candidateIds = {};

  // 1. Direct match (if hianimeId is something like naruto-shippuden-112, we try exactly that)
  candidateIds.add(hianimeId);

  // 2. Stripped ID (remove the trailing -number)
  final strippedId = hianimeId.replaceAll(RegExp(r'-\d+$'), '');
  candidateIds.add(strippedId);
  candidateIds.add('$strippedId-hindi-dubbed');
  candidateIds.add('$strippedId-hindi-dub');

  // 3. Normalized Title as slug
  String titleSlug = hianimeTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  candidateIds.add(titleSlug);
  candidateIds.add('$titleSlug-hindi-dubbed');

  // Helper to check if a slug actually exists and has servers
  Future<bool> checkSlugHasServers(String slug) async {
    try {
      final res = await api.getAnimelokWatch(slug, 1);
      // If it returned data and has servers, it's valid
      if (res != null && res['servers'] != null && (res['servers'] as List).isNotEmpty) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  // Check candidates immediately before doing heavy searches
  for (final slug in candidateIds) {
    if (await checkSlugHasServers(slug)) {
      return slug;
    }
  }

  // Function to search and fuzzy match against a given target title
  Future<String?> searchAndMatch(String targetTitle) async {
    try {
      final searchData = await api.searchAnimelok(targetTitle);
      if (searchData != null && searchData['animes'] != null) {
        final List<dynamic> animes = searchData['animes'];
        if (animes.isNotEmpty) {
          final List<String> candidateTitles = animes.map((a) => a['title'].toString()).toList();
          final matchResult = StringUtils.findBestMatch(targetTitle, candidateTitles);
          
          if (matchResult.score >= 0.75) {
            final matchedId = animes[matchResult.index]['id'].toString();
            // Verify it has servers
            if (await checkSlugHasServers(matchedId)) {
               return matchedId;
            }
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

        // Add slugs from alt titles to direct candidates
        for (final altTitle in altTitles) {
            String altSlug = altTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
            candidateIds.add(altSlug);
            candidateIds.add('$altSlug-hindi-dubbed');
        }
        
        for (final slug in candidateIds) {
          if (await checkSlugHasServers(slug)) {
            return slug;
          }
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

  // Strategy 4: We can't find it. 
  // However, because the user wants it to be robust, 
  // if EVERYTHING failed and search is broken, return null so it doesn't show a non-working button.
  return null; 
});
