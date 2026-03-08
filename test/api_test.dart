import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anianime/services/api_service.dart';
import 'package:anianime/providers/hindi_mapping_provider.dart';
import 'package:anianime/config/app_config.dart';

void main() {
  group('AniAnime API Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      // Ensure config is set for testing
      AppConfig.apiBaseUrl = 'https://api.tatakai.me/api/v1';
    });

    tearDown(() {
      container.dispose();
    });

    test('Test getHomeData', () async {
      final apiService = container.read(apiServiceProvider);
      final homeData = await apiService.getHomeData();

      expect(homeData, isNotNull);
      expect(homeData!['spotlightAnimes'], isA<List>());
      final length = homeData['spotlightAnimes'].length;
      print('✅ Home Data fetched successfully: $length spotlight animes');
    });

    test('Test searchHiAnime', () async {
      final apiService = container.read(apiServiceProvider);
      final searchResult = await apiService.searchHiAnime('Demon Slayer');

      expect(searchResult, isNotNull);
      expect(searchResult!['animes'], isA<List>());
      expect((searchResult['animes'] as List).isNotEmpty, true);

      final firstResult = searchResult['animes'][0];
      final name = firstResult['name'];
      final id = firstResult['id'];
      print('✅ Search successful. First result: $name (ID: $id)');
    });

    test('Test getAnimeEpisodes', () async {
      final apiService = container.read(apiServiceProvider);
      // Using a known ID for Demon Slayer Season 1
      final episodes = await apiService.getAnimeEpisodes(
        'demon-slayer-kimetsu-no-yaiba-47',
      );

      expect(episodes, isNotNull);
      expect(episodes!.isNotEmpty, true);
      final length = episodes.length;
      print('✅ Episodes fetched successfully: $length episodes found.');
    });

    test('Test getHiAnimeEpisodeSources (hd-2) - SUB', () async {
      final apiService = container.read(apiServiceProvider);
      final episodes = await apiService.getAnimeEpisodes(
        'demon-slayer-kimetsu-no-yaiba-47',
      );
      if (episodes != null && episodes.isNotEmpty) {
        final epId = episodes.first['episodeId'];
        final sources = await apiService.getHiAnimeEpisodeSources(
          epId,
          'sub',
          'hd-2',
        );
        if (sources != null && sources['sources'] != null) {
          final s = sources['sources'];
          print('✅ SUB HD-2 Sources fetched successfully: $s');
        } else {
          print('⚠️ SUB HD-2 unavailable.');
        }
      }
    });

    test('Test getHiAnimeEpisodeSources (hd-2) - DUB', () async {
      final apiService = container.read(apiServiceProvider);
      final episodes = await apiService.getAnimeEpisodes(
        'demon-slayer-kimetsu-no-yaiba-47',
      );
      if (episodes != null && episodes.isNotEmpty) {
        final epId = episodes.first['episodeId'];
        final sources = await apiService.getHiAnimeEpisodeSources(
          epId,
          'dub',
          'hd-2',
        );
        if (sources != null && sources['sources'] != null) {
          final s = sources['sources'];
          print('✅ DUB HD-2 Sources fetched successfully: $s');
        } else {
          print('⚠️ DUB HD-2 unavailable.');
        }
      }
    });

    test('Test Hindi Mapping & Stream Fetch (Animelok)', () async {
      // hindiMappingProvider returns String? (the animelok slug), NOT a Map.
      final String? animelokSlug = await container.read(
        hindiMappingProvider((
          id: 'demon-slayer-kimetsu-no-yaiba-47',
          title: 'Demon Slayer',
        )).future,
      );

      print('✅ Hindi Mapping Result (Animelok Slug): $animelokSlug');

      if (animelokSlug != null) {
        final apiService = container.read(apiServiceProvider);

        // Fetch Hindi watch data for episode 1
        final hindiWatchData = await apiService.getAnimelokWatch(
          animelokSlug,
          1,
        );
        if (hindiWatchData != null) {
          print('✅ Hindi Stream fetched successfully for Ep 1!');
          print('   Response keys: ${hindiWatchData.keys.toList()}');
          print('   Full response: $hindiWatchData');
        } else {
          print('⚠️ Could not fetch Hindi stream for slug: $animelokSlug ep 1');
        }
      } else {
        print('⚠️ No Hindi mapping found. (Animelok may not have this anime)');
      }
    });
  });
}
