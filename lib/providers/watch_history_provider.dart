import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final watchHistoryProvider =
    NotifierProvider<WatchHistoryNotifier, List<Map<String, dynamic>>>(() {
      return WatchHistoryNotifier();
    });

class WatchHistoryNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    _loadHistory();
    return [];
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('watch_history');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      state = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(state);
    await prefs.setString('watch_history', data);
  }

  List<String> getWatchedEpisodeIds(String animeId) {
    final Map<String, dynamic> animeEntry = state.firstWhere(
      (entry) => entry['animeId'] == animeId,
      orElse: () => <String, dynamic>{},
    );
    if (animeEntry.isEmpty) return [];
    final List<dynamic>? eps = animeEntry['watchedEpisodes'];
    return eps?.map((e) => e.toString()).toList() ?? [];
  }

  Future<void> markEpisodeWatched({
    required String animeId,
    required String animeTitle,
    required String animePoster,
    required String episodeId,
    required int episodeNumber,
  }) async {
    final newState = [...state];
    final index = newState.indexWhere((entry) => entry['animeId'] == animeId);

    if (index >= 0) {
      final entry = Map<String, dynamic>.from(newState[index]);
      final List<String> watchedEps =
          (entry['watchedEpisodes'] as List<dynamic>)
              .map((e) => e.toString())
              .toList();

      if (!watchedEps.contains(episodeId)) {
        watchedEps.add(episodeId);
      }

      entry['watchedEpisodes'] = watchedEps;
      entry['lastWatchedEpisodeId'] = episodeId;
      entry['lastWatchedEpisodeNumber'] = episodeNumber;
      entry['lastUpdated'] = DateTime.now().toIso8601String();

      newState[index] = entry;
      final item = newState.removeAt(index);
      newState.insert(0, item);
    } else {
      newState.insert(0, {
        'animeId': animeId,
        'animeTitle': animeTitle,
        'animePoster': animePoster,
        'watchedEpisodes': [episodeId],
        'lastWatchedEpisodeId': episodeId,
        'lastWatchedEpisodeNumber': episodeNumber,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
    }

    state = newState;
    await _saveHistory();
  }

  void removeHistory(String animeId) {
    state = state.where((item) => item['animeId'] != animeId).toList();
    _saveHistory();
  }
}
