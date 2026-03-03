import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:readmore/readmore.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/anime_provider.dart';
import '../providers/hindi_mapping_provider.dart';
import 'player_screen.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final String animeId;
  final String title;
  final String? heroTag;

  const DetailScreen({super.key, required this.animeId, required this.title, this.heroTag});

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  String _selectedType = 'sub';
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 250 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 250 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final infoAsync = ref.watch(animeInfoProvider(widget.animeId));
    final episodesAsync = ref.watch(animeEpisodesProvider(widget.animeId));
    final hindiMappingAsync = ref.watch(hindiMappingProvider({'id': widget.animeId, 'title': widget.title}));

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: _isScrolled ? const Color(0xFF050505).withValues(alpha: 0.9) : Colors.transparent,
        elevation: 0,
        title: _isScrolled 
            ? Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))
                .animate().fadeIn()
            : null,
        flexibleSpace: _isScrolled ? ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ) : null,
      ),
      body: infoAsync.when(
        data: (info) {
          final anime = info['anime']['info'];
          return CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeroHeader(anime),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // Meta Info Row
                      Row(
                        children: [
                          if (anime['stats']?['rating'] != null) ...[
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              anime['stats']['rating'].toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                          ],
                          _buildBadge(anime['stats']?['quality'] ?? 'HD', const Color(0xFF0EA5E9)),
                          const SizedBox(width: 12),
                          _buildBadge(anime['stats']?['type'] ?? 'TV', Colors.grey[800]!),
                          const SizedBox(width: 12),
                          if (anime['stats']?['duration'] != null)
                            Text(
                              anime['stats']['duration'],
                              style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                        ],
                      ).animate().fadeIn(delay: 200.ms).slideX(),
                      const SizedBox(height: 24),
                      // Description
                      ReadMoreText(
                        anime['description'] ?? '',
                        trimLines: 4,
                        colorClickableText: const Color(0xFF0EA5E9),
                        trimMode: TrimMode.Line,
                        trimCollapsedText: ' Read more',
                        trimExpandedText: ' Show less',
                        style: TextStyle(color: Colors.grey[300], height: 1.6, fontSize: 14),
                        moreStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9)),
                        lessStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9)),
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 32),
                      
                      // Language Selector
                      Row(
                        children: [
                          const Text('Audio: ', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF8B5CF6)]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _selectedType.toUpperCase(),
                              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 400.ms),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildLangChip('Sub', 'sub'),
                            const SizedBox(width: 12),
                            _buildLangChip('Dub', 'dub'),
                            const SizedBox(width: 12),
                            hindiMappingAsync.when(
                              data: (hindiId) => hindiId != null
                                  ? _buildLangChip('Hindi', 'hindi')
                                  : const SizedBox.shrink(),
                              loading: () => const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0EA5E9))),
                              ),
                              error: (err, stack) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 450.ms).slideX(),
                      const SizedBox(height: 40),
                      
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Episodes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                          Icon(Icons.sort_rounded, color: Colors.grey),
                        ],
                      ).animate().fadeIn(delay: 500.ms),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              episodesAsync.when(
                data: (episodes) => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final ep = episodes[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121212),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              final hindiId = hindiMappingAsync.value;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PlayerScreen(
                                    hianimeEpisodeId: ep['episodeId'],
                                    animelokId: hindiId,
                                    episodeNumber: ep['number'],
                                    selectedType: _selectedType,
                                    animeTitle: widget.title,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  // Episode thumbnail placeholder (since api might not provide ep thumb)
                                  Container(
                                    width: 100,
                                    height: 65,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: CachedNetworkImageProvider(
                                        anime['poster'] ?? '',
                                        errorListener: (err) => debugPrint('Image error: $err'),
                                      ),
                                        fit: BoxFit.cover,
                                        colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.4), BlendMode.darken),
                                      ),
                                    ),                                    alignment: Alignment.center,
                                    child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 32),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Episode ${ep['number']}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          ep['title'] ?? 'Episode ${ep['number']}',
                                          style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (ep['isFiller'] == true)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('Filler', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: Duration(milliseconds: 500 + (index * 50))).slideX(begin: 0.1, end: 0);
                      },
                      childCount: episodes.length,
                    ),
                  ),
                ),
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Center(child: Padding(padding: EdgeInsets.all(40), child: Text('Error loading episodes: $err', style: const TextStyle(color: Colors.red)))),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          );
        },
        loading: () => _buildDetailSkeleton(),
        error: (err, stack) => Center(child: Text('Error loading details\n$err')),
      ),
    );
  }

  Widget _buildDetailSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero skeleton
          Stack(
            children: [
              Shimmer.fromColors(
                baseColor: const Color(0xFF121212),
                highlightColor: const Color(0xFF2A2A2A),
                child: Container(
                  height: 450,
                  width: double.infinity,
                  color: Colors.white,
                ),
              ),
              Positioned(
                bottom: 0,
                left: 20,
                right: 20,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Shimmer.fromColors(
                      baseColor: const Color(0xFF121212),
                      highlightColor: const Color(0xFF2A2A2A),
                      child: Container(
                        width: 130,
                        height: 190,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Shimmer.fromColors(
                            baseColor: const Color(0xFF121212),
                            highlightColor: const Color(0xFF2A2A2A),
                            child: Container(
                              height: 30,
                              width: 200,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Shimmer.fromColors(
                            baseColor: const Color(0xFF121212),
                            highlightColor: const Color(0xFF2A2A2A),
                            child: Container(
                              height: 30,
                              width: 150,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Content skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer.fromColors(
                  baseColor: const Color(0xFF121212),
                  highlightColor: const Color(0xFF2A2A2A),
                  child: Container(height: 20, width: double.infinity, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Shimmer.fromColors(
                  baseColor: const Color(0xFF121212),
                  highlightColor: const Color(0xFF2A2A2A),
                  child: Container(height: 20, width: double.infinity, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Shimmer.fromColors(
                  baseColor: const Color(0xFF121212),
                  highlightColor: const Color(0xFF2A2A2A),
                  child: Container(height: 20, width: 250, color: Colors.white),
                ),
                const SizedBox(height: 40),
                Shimmer.fromColors(
                  baseColor: const Color(0xFF121212),
                  highlightColor: const Color(0xFF2A2A2A),
                  child: Container(height: 30, width: 120, color: Colors.white),
                ),
                const SizedBox(height: 16),
                for (int i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Shimmer.fromColors(
                      baseColor: const Color(0xFF121212),
                      highlightColor: const Color(0xFF2A2A2A),
                      child: Container(
                        height: 90,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(dynamic anime) {
    return SizedBox(
      height: 450,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: widget.heroTag ?? 'poster-${widget.animeId}',
            child: CachedNetworkImage(
              imageUrl: anime['poster'] ?? '',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorWidget: (context, url, error) => const Center(child: Icon(Icons.error_outline, color: Colors.white54)),
            ),
          ),
          // Blur effect for background
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                child: Container(color: Colors.black.withValues(alpha: 0.2)),
              ),
            ),
          ),
          // Gradient fading into background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF050505).withValues(alpha: 0.8),
                  const Color(0xFF050505),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.3, 0.8, 1.0],
              ),
            ),
          ),
          // Main Poster and Title
          Positioned(
            bottom: 0,
            left: 20,
            right: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Hero(
                  tag: widget.heroTag != null ? '${widget.heroTag}-img' : 'poster-${widget.animeId}-img',
                  child: Container(
                    width: 130,
                    height: 190,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: anime['poster'] ?? '',
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Center(child: Icon(Icons.error_outline, color: Colors.white54)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anime['name'] ?? widget.title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildLangChip(String label, String type) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF8B5CF6)])
              : LinearGradient(colors: [const Color(0xFF1A1A1A), const Color(0xFF1A1A1A)]),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16).animate().scale(duration: 200.ms),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
