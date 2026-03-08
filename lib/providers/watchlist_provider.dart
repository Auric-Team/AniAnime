import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final watchlistProvider =
    NotifierProvider<WatchlistNotifier, List<Map<String, dynamic>>>(() {
      return WatchlistNotifier();
    });

class WatchlistNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    _loadWatchlist();
    return [];
  }

  Future<void> _loadWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('watchlist');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      state = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }
  }

  Future<void> _saveWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(state);
    await prefs.setString('watchlist', data);
  }

  bool isInWatchlist(String animeId) {
    return state.any((anime) => anime['id'] == animeId);
  }

  Future<void> toggleWatchlist(Map<String, dynamic> anime) async {
    final String id = anime['id'];
    if (isInWatchlist(id)) {
      state = state.where((item) => item['id'] != id).toList();
    } else {
      state = [...state, anime];
    }
    await _saveWatchlist();
  }
}
