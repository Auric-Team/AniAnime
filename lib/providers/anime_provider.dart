import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

final homeDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getHomeData();
});

final animeInfoProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.read(apiServiceProvider);
  return api.getAnimeInfo(id);
});

final animeEpisodesProvider = FutureProvider.family<List<dynamic>, String>((ref, id) async {
  final api = ref.read(apiServiceProvider);
  return api.getAnimeEpisodes(id);
});
