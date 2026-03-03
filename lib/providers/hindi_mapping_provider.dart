import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../utils/string_utils.dart';

// Provides the mapped Animelok ID for a given HiAnime ID and Title.
// It returns null if no Hindi version is found.
final hindiMappingProvider = FutureProvider.family<String?, Map<String, String>>((ref, params) async {
  final api = ref.read(apiServiceProvider);
  final hianimeId = params['id']!;
  final hianimeTitle = params['title']!;

  // Strategy 1: Try direct ID match (since Animelok uses HiAnime-style IDs)
  // We can test this by checking if watch endpoint returns something valid for ep 1
  try {
    final directCheck = await api.getAnimelokWatch(hianimeId, 1);
    if (directCheck != null && directCheck['servers'] != null) {
      return hianimeId; // Direct match works!
    }
  } catch (_) {
    // Ignore error and proceed to search
  }

  // Strategy 2: Robust Search and Fuzzy Match
  try {
    // Search by title
    final searchData = await api.searchAnimelok(hianimeTitle);
    if (searchData != null && searchData['animes'] != null) {
      final List<dynamic> animes = searchData['animes'];
      if (animes.isEmpty) return null;

      final List<String> candidateTitles = animes.map((a) => a['title'].toString()).toList();
      
      // Use string_similarity to find the best match
      final matchResult = StringUtils.findBestMatch(hianimeTitle, candidateTitles);
      
      // If the best match score is good enough (e.g., > 0.6)
      if (matchResult.score > 0.6) {
        return animes[matchResult.index]['id'].toString();
      }
    }
  } catch (e) {
    print('Hindi mapping error: $e');
  }

  return null; // Hindi not available
});
