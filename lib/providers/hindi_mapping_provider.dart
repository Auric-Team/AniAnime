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
      // Use a custom short timeout so we don't hang the UI if a server blocks us
      final res = await api.getAnimelokWatch(slug, 1)
          .timeout(const Duration(seconds: 4));
      if (res != null && res['servers'] != null && (res['servers'] as List).isNotEmpty) {
        return slug; // Valid!
      }
    } catch (_) {}
    return null;
  }

  // Helper to check a list of slugs concurrently and return the FIRST successful one
  Future<String?> checkCandidates(Iterable<String> slugs) async {
    if (slugs.isEmpty) return null;
    
    // Create a Completer that will complete as soon as we find a valid slug
    // or when all slugs have been checked and failed.
    final completer = Completer<String?>();
    int pending = slugs.length;
    
    for (final slug in slugs) {
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
    
    return completer.future;
  }

  // --- Phase 1: High Probability Direct Slugs (Fast Parallel Check) ---
  final strippedId = hianimeId.replaceAll(RegExp(r'-\d+$'), '');
  String titleSlug = hianimeTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  
  Set<String> phase1Candidates = {
    hianimeId,
    '$hianimeId-hindi-dubbed',
    strippedId,
    '$strippedId-hindi-dubbed',
    '$strippedId-hindi-dub',
    titleSlug,
    '$titleSlug-hindi-dubbed',
  };

  final phase1Result = await checkCandidates(phase1Candidates);
  if (phase1Result != null) return phase1Result;

  // --- Phase 2: MAL ID Alternative Titles (Parallel Check) ---
  try {
    // Wait for the info provider to finish or fetch it directly
    final info = await ref.read(animeInfoProvider(hianimeId).future).timeout(const Duration(seconds: 5));
    final malId = info['anime']?['info']?['malId'];
    
    if (malId != null && malId != 0) {
      final jikanResponse = await Dio().get('https://api.jikan.moe/v4/anime/$malId').timeout(const Duration(seconds: 5));
      final jikanData = jikanResponse.data['data'];
      
      if (jikanData != null) {
        // Collect alternative titles
        final Set<String> altTitles = {};
        if (jikanData['title_english'] != null) altTitles.add(jikanData['title_english']);
        if (jikanData['title'] != null) altTitles.add(jikanData['title']);
        
        final titlesArray = jikanData['titles'] as List<dynamic>? ?? [];
        for (var t in titlesArray) {
          if (t['title'] != null) altTitles.add(t['title'].toString());
        }

        Set<String> phase2Candidates = {};
        for (final altTitle in altTitles) {
            String altSlug = altTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
            phase2Candidates.add(altSlug);
            phase2Candidates.add('$altSlug-hindi-dubbed');
        }
        
        final phase2Result = await checkCandidates(phase2Candidates);
        if (phase2Result != null) return phase2Result;
      }
    }
  } catch (e) {
    debugPrint('MAL fallback error: $e');
  }

  // --- Phase 3: Robust Search API as last resort ---
  try {
    // Also timeout the search
    final searchData = await api.searchAnimelok(hianimeTitle).timeout(const Duration(seconds: 5));
    if (searchData != null && searchData['animes'] != null) {
      final List<dynamic> animes = searchData['animes'];
      if (animes.isNotEmpty) {
        final List<String> candidateTitles = animes.map((a) => a['title'].toString()).toList();
        final matchResult = StringUtils.findBestMatch(hianimeTitle, candidateTitles);
        
        if (matchResult.score >= 0.75) {
          final matchedId = animes[matchResult.index]['id'].toString();
          final isValid = await checkSlug(matchedId);
          if (isValid != null) return isValid;
        }
      }
    }
  } catch (_) {}

  // Hindi not found
  return null; 
});
