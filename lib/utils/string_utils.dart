import 'package:string_similarity/string_similarity.dart';

class StringUtils {
  static String normalize(String input) {
    String normalized = input.toLowerCase();

    // 1. Remove common symbols and punctuations that interfere with matching
    // Replace with spaces to keep word boundaries intact
    normalized = normalized.replaceAll(RegExp(r'[\\/;:.,!@#\$%\^&\*()_\+\=\[\]{}<>\|`~]'), ' ');
    // Keep dashes and apostrophes for now, then handle specific cases
    normalized = normalized.replaceAll(RegExp(r"['\-]"), '');

    // 2. Remove stopwords / descriptive tags that differ between platforms
    final stopwords = [
      r'season\s*\d+', r'part\s*\d+', r'cour\s*\d+',
      r'movie', r'tv', r'special', r'ova', r'ona',
      r'dub', r'sub', r'hindi', r'1st', r'2nd', r'3rd', r'4th', r'5th',
      r's\d+', r'pt\s*\d+', r'dubbed', r'subbed', r'uncensored',
      r'the', r'a', r'an', r'in', r'of', r'and', r'to'
    ];

    for (final stopword in stopwords) {
      normalized = normalized.replaceAll(RegExp('\\b$stopword\\b', caseSensitive: false), ' ');
    }

    // 3. Convert Roman numerals to numbers for better consistency
    normalized = normalized.replaceAll(RegExp(r'\bix\b'), '9')
                           .replaceAll(RegExp(r'\bviii\b'), '8')
                           .replaceAll(RegExp(r'\bvii\b'), '7')
                           .replaceAll(RegExp(r'\bvi\b'), '6')
                           .replaceAll(RegExp(r'\biv\b'), '4')
                           .replaceAll(RegExp(r'\bv\b'), '5')
                           .replaceAll(RegExp(r'\biii\b'), '3')
                           .replaceAll(RegExp(r'\bii\b'), '2')
                           .replaceAll(RegExp(r'\bi\b'), '1');

    // 4. Remove multiple spaces and trim
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    return normalized;
  }

  static String extractAlphanumeric(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
  }

  static double getSimilarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final normA = normalize(a);
    final normB = normalize(b);

    if (normA == normB) return 1.0;

    // Direct subset check on fully stripped strings
    final rawA = extractAlphanumeric(normA);
    final rawB = extractAlphanumeric(normB);
    
    if (rawA.isNotEmpty && rawB.isNotEmpty) {
       if (rawA == rawB) return 0.95;
       if (rawA.contains(rawB) && rawB.length > 5) return 0.85;
       if (rawB.contains(rawA) && rawA.length > 5) return 0.85;
    }

    // High threshold if strings start with the same major words
    final wordsA = normA.split(' ');
    final wordsB = normB.split(' ');
    if (wordsA.isNotEmpty && wordsB.isNotEmpty && wordsA[0] == wordsB[0]) {
      // Bonus for matching first word
      double score = normA.similarityTo(normB);
      return score + 0.1 > 1.0 ? 1.0 : score + 0.1;
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
