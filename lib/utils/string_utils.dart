import 'package:string_similarity/string_similarity.dart';

class StringUtils {
  static String normalize(String input) {
    String normalized = input.toLowerCase();
    
    // Remove "season x", "part x", "cour x", "movie", "tv", "special", "ova", "ona", "dub", "sub", "hindi"
    final stopwords = [
      r'season\s*\d*', r'part\s*\d*', r'cour\s*\d*', 
      r'movie', r'tv', r'special', r'ova', r'ona', 
      r'dub', r'sub', r'hindi', r'1st', r'2nd', r'3rd', r'4th'
    ];
    
    for (final stopword in stopwords) {
      normalized = normalized.replaceAll(RegExp(stopword), ' ');
    }

    // Convert roman numerals to numbers roughly (I, II, III, IV, etc.) for common cases
    normalized = normalized.replaceAll(RegExp(r'\bii\b'), '2')
                           .replaceAll(RegExp(r'\biii\b'), '3')
                           .replaceAll(RegExp(r'\biv\b'), '4')
                           .replaceAll(RegExp(r'\bv\b'), '5');
                           
    // Replace non-alphanumeric with space
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]'), ' ');
    
    // Replace multiple spaces with single space
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    
    return normalized.trim();
  }

  static double getSimilarity(String a, String b) {
    final normA = normalize(a);
    final normB = normalize(b);
    
    if (normA == normB) return 1.0;
    
    // Sometimes one title is a subset of another
    if (normA.contains(normB) || normB.contains(normA)) {
      // Very high similarity if it's a direct containment
      return 0.9;
    }

    return normA.similarityTo(normB);
  }

  /// Finds the best match from a list of strings, returning the index and score
  static ({int index, double score}) findBestMatch(String target, List<String> candidates) {
    if (candidates.isEmpty) return (index: -1, score: 0.0);
    
    int bestIndex = -1;
    double bestScore = -1.0;
    
    for (int i = 0; i < candidates.length; i++) {
      double score = getSimilarity(target, candidates[i]);
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }
    
    return (index: bestIndex, score: bestScore);
  }
}
