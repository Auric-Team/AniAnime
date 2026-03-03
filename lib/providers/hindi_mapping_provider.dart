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
      // Very fast timeout so the UI doesn't hang
      final res = await api.getAnimelokWatch(slug, 1).timeout(const Duration(seconds: 3));
      if (res != null && res['servers'] != null && (res['servers'] as List).isNotEmpty) {
        return slug;
      }
    } catch (_) {}
    return null;
  }

  // --- Phase 1: High Probability Direct Slugs (Fast Parallel Check) ---
  final strippedId = hianimeId.replaceAll(RegExp(r'-\d+$'), '');
  String titleSlug = hianimeTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  
  // Predictably strong candidates checked concurrently
  List<Future<String?>> futures = [
    checkSlug('$hianimeId-hindi-dubbed'),
    checkSlug(hianimeId),
    checkSlug('$strippedId-hindi-dubbed'),
    checkSlug(strippedId),
    checkSlug('$strippedId-hindi-dub'),
    checkSlug('$titleSlug-hindi-dubbed'),
    checkSlug(titleSlug),
  ];

  // We race them. The first one to return non-null wins instantly.
  try {
    String? foundSlug;
    await Future.any(futures.map((f) => f.then((val) {
      if (val != null) {
        foundSlug = val;
        throw 'FOUND'; // Break out of Future.any
      }
    })));
  } catch (e) {
    if (e == 'FOUND') {
      // One of the checks succeeded! (The others might still be running in bg, but we return early)
      // Actually we can't get the foundSlug out cleanly with Future.any easily because 
      // Future.any only resolves when the *first* future completes (which could be a null return).
    }
  }

  // A better parallel approach to return the first successful result:
  final completer = Completer<String?>();
  int pending = futures.length;
  
  for (final f in futures) {
    f.then((result) {
      if (result != null && !completer.isCompleted) {
        completer.complete(result);
      } else {
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      }
    }).catchError((_) {
      pending--;
      if (pending == 0 && !completer.isCompleted) {
        completer.complete(null);
      }
    });
  }

  final phase1Result = await completer.future;
  if (phase1Result != null) return phase1Result;

  // --- Phase 2: MAL ID Alternative Titles (Parallel Check) ---
  try {
    // Wait for the info provider to finish or fetch it directly
    final info = await ref.read(animeInfoProvider(hianimeId).future).timeout(const Duration(seconds: 3), onTimeout: () => {});
    final malId = info['anime']?['info']?['malId'];
    
    if (malId != null && malId != 0) {
      final jikanResponse = await Dio().get('https://api.jikan.moe/v4/anime/$malId').timeout(const Duration(seconds: 3));
      final jikanData = jikanResponse.data['data'];
      
      if (jikanData != null) {
        final Set<String> altTitles = {};
        if (jikanData['title_english'] != null) altTitles.add(jikanData['title_english']);
        if (jikanData['title'] != null) altTitles.add(jikanData['title']);
        
        final titlesArray = jikanData['titles'] as List<dynamic>? ?? [];
        for (var t in titlesArray) {
          if (t['title'] != null) altTitles.add(t['title'].toString());
        }

        List<Future<String?>> phase2Futures = [];
        for (final altTitle in altTitles) {
            String altSlug = altTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
            phase2Futures.add(checkSlug('$altSlug-hindi-dubbed'));
            phase2Futures.add(checkSlug(altSlug));
        }
        
        if (phase2Futures.isNotEmpty) {
          final completer2 = Completer<String?>();
          int pending2 = phase2Futures.length;
          for (final f in phase2Futures) {
            f.then((result) {
              if (result != null && !completer2.isCompleted) {
                completer2.complete(result);
              } else {
                pending2--;
                if (pending2 == 0 && !completer2.isCompleted) {
                  completer2.complete(null);
                }
              }
            }).catchError((_) {
              pending2--;
              if (pending2 == 0 && !completer2.isCompleted) {
                completer2.complete(null);
              }
            });
          }
          final phase2Result = await completer2.future;
          if (phase2Result != null) return phase2Result;
        }
      }
    }
  } catch (e) {
    debugPrint('MAL fallback error: $e');
  }

  return null; 
});
