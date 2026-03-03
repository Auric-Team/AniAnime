import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/anime_provider.dart';
import 'detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentSpotlightIndex = 0;

  @override
  Widget build(BuildContext context) {
    final homeDataAsync = ref.watch(homeDataProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.8),
                Colors.black.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0EA5E9), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
            ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(width: 12),
            const Text(
              'AniAnime',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -1.0),
            ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.2, end: 0),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 28),
            onPressed: () {},
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(width: 8),
        ],
      ),
      body: homeDataAsync.when(
        data: (data) {
          final spotlight = data['spotlightAnimes'] as List<dynamic>? ?? [];
          final trending = data['trendingAnimes'] as List<dynamic>? ?? [];
          final latestEpisodes = data['latestEpisodeAnimes'] as List<dynamic>? ?? [];
          final topAiring = data['topAiringAnimes'] as List<dynamic>? ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100), // padding for bottom nav
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (spotlight.isNotEmpty) _buildSpotlightCarousel(spotlight).animate().fadeIn(duration: 600.ms),
                const SizedBox(height: 24),
                if (trending.isNotEmpty) 
                  _buildSection('Trending Now', trending, 0).animate().slideY(begin: 0.2, end: 0, delay: 200.ms).fadeIn(),
                if (latestEpisodes.isNotEmpty) 
                  _buildSection('Latest Episodes', latestEpisodes, 1).animate().slideY(begin: 0.2, end: 0, delay: 300.ms).fadeIn(),
                if (topAiring.isNotEmpty) 
                  _buildSection('Top Airing', topAiring, 2).animate().slideY(begin: 0.2, end: 0, delay: 400.ms).fadeIn(),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9))),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load data\n$err', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => ref.refresh(homeDataProvider),
                child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpotlightCarousel(List<dynamic> animes) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        CarouselSlider.builder(
          itemCount: animes.length,
          options: CarouselOptions(
            height: MediaQuery.of(context).size.height * 0.65,
            viewportFraction: 1.0,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 6),
            onPageChanged: (index, reason) {
              setState(() {
                _currentSpotlightIndex = index;
              });
            },
          ),
          itemBuilder: (context, index, realIndex) {
            final anime = animes[index];
            return GestureDetector(
              onTap: () => _navigateToDetail(anime['id'], anime['name']),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: anime['poster'] ?? '',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: const Color(0xFF121212),
                      highlightColor: const Color(0xFF2A2A2A),
                      child: Container(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => const Center(child: Icon(Icons.error_outline, color: Colors.white54)),
                  ),
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF050505).withValues(alpha: 0.3),
                          const Color(0xFF050505).withValues(alpha: 0.8),
                          const Color(0xFF050505),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.4, 0.6, 0.85, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 50,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE50914),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${anime['rank'] ?? index + 1} Spotlight',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(anime['jname'] ?? 'Anime', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          anime['name'] ?? '',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -0.5),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          anime['description'] ?? '',
                          style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.5),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _navigateToDetail(anime['id'], anime['name']),
                                icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
                                label: const Text('Play Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.grey[300],
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        ),
        Positioned(
          bottom: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: animes.asMap().entries.map((entry) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _currentSpotlightIndex == entry.key ? 24.0 : 6.0,
                height: 6.0,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: _currentSpotlightIndex == entry.key
                      ? const Color(0xFF0EA5E9)
                      : Colors.white.withValues(alpha: 0.3),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<dynamic> animes, int indexDelay) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[500]),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: animes.length,
            itemBuilder: (context, index) {
              final anime = animes[index];
              return GestureDetector(
                onTap: () => _navigateToDetail(anime['id'], anime['name'] ?? anime['title'], heroTag: 'poster-${anime['id']}-$title'),
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Hero(
                          tag: 'poster-${anime['id']}-$title',
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: anime['poster'] ?? '',
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Shimmer.fromColors(
                                      baseColor: const Color(0xFF121212),
                                      highlightColor: const Color(0xFF2A2A2A),
                                      child: Container(color: Colors.white),
                                    ),
                                    errorWidget: (context, url, error) => const Center(child: Icon(Icons.error_outline, color: Colors.white54)),
                                  ),
                                  // Episodes badge
                                  if (anime['episodes'] != null && anime['episodes']['sub'] != null)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.closed_caption_rounded, size: 10, color: Colors.white),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${anime['episodes']['sub']}',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        anime['name'] ?? anime['title'] ?? '',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _navigateToDetail(String id, String? title, {String? heroTag}) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => DetailScreen(animeId: id, title: title ?? 'Details', heroTag: heroTag),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}
