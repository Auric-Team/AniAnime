import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../providers/watch_history_provider.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String animeId;
  final String hianimeEpisodeId;
  final String? animelokId;
  final int episodeNumber;
  final String selectedType;
  final String animeTitle;
  final List<dynamic> allEpisodes;

  const PlayerScreen({
    super.key,
    required this.animeId,
    required this.hianimeEpisodeId,
    this.animelokId,
    required this.episodeNumber,
    required this.selectedType,
    required this.animeTitle,
    required this.allEpisodes,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMsg;
  String _currentBaseUrl = '';

  bool _showOverlay = true;
  Timer? _hideControlsTimer;
  double _startAt = 0.0;

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  @override
  void initState() {
    super.initState();
    // Allow landscape rotation for full screen immersive experience
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Hide status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    if (controller.platform is AndroidWebViewController) {
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..addJavaScriptChannel(
        'VideoProgress',
        onMessageReceived: (message) async {
          final position = double.tryParse(message.message);
          if (position != null && position > 0) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setDouble(
              'progress_${widget.animeId}_${widget.hianimeEpisodeId}',
              position,
            );
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            // Allow our base URL or the exact stream URL
            if (_currentBaseUrl.isNotEmpty &&
                url.startsWith(_currentBaseUrl.toLowerCase())) {
              return NavigationDecision.navigate;
            }
            if (url.contains('hianime.to') ||
                url.contains('animelok') ||
                url.contains('tatakai') ||
                url.contains('megacloud') ||
                url.contains('rapid') ||
                url.contains('filemoon') ||
                url.contains('vidplay') ||
                url.contains('as-cdn') ||
                url.contains('short.icu') ||
                url.contains('anvod') ||
                url.contains('owocdn') ||
                url.contains('abyess') ||
                url.contains('player') ||
                url.contains('stream')) {
              return NavigationDecision.navigate;
            }
            // Block all other redirects
            return NavigationDecision.prevent;
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame ?? false) {
              if (mounted) {
                setState(() {
                  _errorMsg = "Connection error: ${error.description}";
                  _isLoading = false;
                });
              }
            }
          },
        ),
      );

    _controller = controller;
    _loadStream();
  }

  @override
  void dispose() {
    // Restore default orientation and UI mode
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadStream() async {
    try {
      ref
          .read(watchHistoryProvider.notifier)
          .markEpisodeWatched(
            animeId: widget.animeId,
            animeTitle: widget.animeTitle,
            animePoster:
                '', // We don't have the poster here, detail screen handles that or we pass it later
            episodeId: widget.hianimeEpisodeId,
            episodeNumber: widget.episodeNumber,
          );

      final prefs = await SharedPreferences.getInstance();
      _startAt =
          prefs.getDouble(
            'progress_${widget.animeId}_${widget.hianimeEpisodeId}',
          ) ??
          0.0;

      _startHideTimer();
      String? streamUrl;
      bool isM3U8 = false;
      List<dynamic> tracks = [];
      String baseUrl = 'https://megacloud.blog/';

      if (widget.selectedType == 'hindi' && widget.animelokId != null) {
        final api = ref.read(apiServiceProvider);

        // Try multiple episode numbers to find the right Hindi episode
        List<int> episodeNumbersToTry = [widget.episodeNumber];
        if (widget.episodeNumber > 1) {
          episodeNumbersToTry.add(widget.episodeNumber - 1);
        }
        episodeNumbersToTry.add(widget.episodeNumber + 1);

        Map<String, dynamic>? bestRes;

        for (int epNum in episodeNumbersToTry) {
          try {
            final res = await api.getAnimelokWatch(widget.animelokId!, epNum);
            if (res != null && res['servers'] != null) {
              final List servers = res['servers'];
              // Look for Hindi servers
              final hindiServers = servers
                  .where(
                    (s) =>
                        s['language'] == 'Hindi' ||
                        s['name'] == 'Hindi' ||
                        s['tip'] == 'Multi' ||
                        s['name'] == 'Multi',
                  )
                  .toList();

              if (hindiServers.isNotEmpty) {
                // Strictly prioritize the 'Multi' server for Hindi as requested!
                final selectedServer = hindiServers.firstWhere(
                  (s) => s['name'] == 'Multi' && s['language'] == 'Hindi',
                  orElse: () => hindiServers.firstWhere(
                    (s) => s['name'] == 'Multi',
                    orElse: () => hindiServers.firstWhere(
                      (s) => s['language'] == 'Hindi' && s['isM3U8'] == true,
                      orElse: () => hindiServers.first,
                    ),
                  ),
                );

                bestRes = {'server': selectedServer, 'episodeNumber': epNum};
                break; // Found Hindi, use this
              }
            }
          } catch (_) {
            continue;
          }
        }

        if (bestRes != null) {
          final server = bestRes['server'];
          streamUrl = server['url'];
          if (streamUrl != null && streamUrl.contains('localhost:4000')) {
            streamUrl = streamUrl.replaceFirst(
              'http://localhost:4000',
              AppConfig.apiBaseUrl.replaceAll('/api/v1', ''),
            );
          }
          isM3U8 = server['isM3U8'] == true;
          if (isM3U8) baseUrl = 'https://animelok.site/';
        } else {
          throw Exception('No Hindi server found for this episode');
        }
      } else {
        // Fetch HiAnime sources
        final api = ref.read(apiServiceProvider);
        Map<String, dynamic>? res;

        // 1. Try fetching 'hd-2' specifically
        try {
          res = await api.getHiAnimeEpisodeSources(
            widget.hianimeEpisodeId,
            widget.selectedType,
            'hd-2', // Prefer HD-2
          );
        } catch (_) {}

        // 2. Fallback to default if HD-2 failed or returned no sources
        if (res == null ||
            res['sources'] == null ||
            (res['sources'] as List).isEmpty) {
          try {
            res = await api.getHiAnimeEpisodeSources(
              widget.hianimeEpisodeId,
              widget.selectedType,
            );
          } catch (_) {
            // 3. Fallback to sub if dub failed
            if (widget.selectedType == 'dub') {
              try {
                res = await api.getHiAnimeEpisodeSources(
                  widget.hianimeEpisodeId,
                  'sub',
                );
              } catch (e) {
                rethrow;
              }
            } else {
              rethrow;
            }
          }
        }

        if (res != null && res['sources'] != null) {
          final sources = res['sources'] as List;
          if (sources.isNotEmpty) {
            final hlsSource = sources.firstWhere(
              (s) => s['isM3U8'] == true,
              orElse: () => sources.first,
            );
            streamUrl = hlsSource['url'];
            isM3U8 = hlsSource['isM3U8'] == true;

            tracks = res['tracks'] as List? ?? [];
            final headers = res['headers'] as Map<String, dynamic>? ?? {};
            if (headers['Referer'] != null) {
              baseUrl = headers['Referer'];
            }
          }
        }
      }

      if (streamUrl == null) {
        throw Exception('No stream found for the selected language.');
      }

      _currentBaseUrl = baseUrl;

      if (isM3U8) {
        // Generate an HTML player using Plyr and HLS.js
        String tracksHtml = '';
        for (var track in tracks) {
          if (track['kind'] == 'captions' ||
              track['kind'] == 'subtitles' ||
              track['file']?.endsWith('.vtt') == true ||
              track['url']?.endsWith('.vtt') == true) {
            final label = track['label'] ?? track['lang'] ?? 'Unknown';
            final src = track['file'] ?? track['url'];
            final isDefault = label.toLowerCase().contains('english')
                ? 'default'
                : '';
            tracksHtml +=
                '<track kind="captions" label="$label" srclang="en" src="$src" $isDefault />';
          }
        }

        final htmlString =
            '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Player</title>
    <link rel="stylesheet" href="https://cdn.plyr.io/3.7.8/plyr.css" />
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;700&display=swap');
        
        :root {
            --primary: #8B5CF6;
            --secondary: #EC4899;
            --bg: #0F172A;
            --surface: rgba(30, 41, 59, 0.95);
        }

        body, html { 
            margin: 0; padding: 0; width: 100%; height: 100%; 
            background: #000; overflow: hidden; 
            display: flex; align-items: center; justify-content: center; 
            font-family: 'Outfit', sans-serif;
            -webkit-tap-highlight-color: transparent;
        }
        
        .plyr--video { width: 100%; height: 100%; background: #000; }
        
        .plyr {
            --plyr-color-main: var(--primary);
            --plyr-video-control-color: #fff;
            --plyr-menu-background: var(--surface);
            --plyr-menu-color: #fff;
            --plyr-menu-radius: 12px;
            --plyr-font-family: 'Outfit', sans-serif;
        }

        /* Modern Controls */
        .plyr__control--overlaid {
            background: rgba(139, 92, 246, 0.8);
            backdrop-filter: blur(8px);
            border-radius: 50%;
            padding: 24px;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
        }
        
        .plyr__control--overlaid:hover {
            transform: scale(1.1);
            background: var(--primary);
            box-shadow: 0 0 30px rgba(139, 92, 246, 0.5);
        }

        .plyr__controls {
            background: linear-gradient(to top, rgba(0,0,0,0.95), transparent) !important;
            padding: 30px 24px !important;
        }
        
        .plyr__menu__container {
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            box-shadow: 0 10px 40px rgba(0,0,0,0.5);
            border: 1px solid rgba(255,255,255,0.1);
        }

        /* Custom Loading */
        #loading { 
            position: absolute; z-index: 50; 
            display: flex; flex-direction: column; align-items: center; justify-content: center;
            background: #000; width: 100%; height: 100%;
            transition: opacity 0.3s ease;
        }
        
        .loader {
            width: 50px; height: 50px;
            border: 3px solid rgba(255,255,255,0.1);
            border-radius: 50%;
            border-top-color: var(--primary);
            border-right-color: var(--secondary);
            animation: spin 0.8s cubic-bezier(0.68, -0.55, 0.265, 1.55) infinite;
        }
        
        .loading-text {
            margin-top: 16px; color: rgba(255,255,255,0.8);
            font-size: 0.9rem; letter-spacing: 1px;
            font-weight: 500;
        }

        /* Error UI */
        #error-msg {
            position: absolute; color: white; z-index: 60;
            text-align: center; width: 80%;
            background: rgba(15, 23, 42, 0.9);
            padding: 32px; border-radius: 20px;
            backdrop-filter: blur(12px);
            border: 1px solid rgba(255,255,255,0.1);
            display: none;
        }

        #error-msg h3 { margin: 0 0 12px; color: #EF4444; }
        
        #error-msg button {
            background: var(--primary); color: white;
            border: none; padding: 12px 24px;
            border-radius: 8px; font-weight: 600;
            margin-top: 20px; cursor: pointer;
            transition: transform 0.2s;
        }
        
        #error-msg button:active { transform: scale(0.95); }

        @keyframes spin { 100% { transform: rotate(360deg); } }
    </style>
</head>
<body>
    <div id="loading">
        <div class="loader"></div>
        <div class="loading-text">INITIALIZING STREAM</div>
    </div>
    <div id="error-msg"></div>
    <video id="player" playsinline controls crossorigin>
        $tracksHtml
    </video>
    
    <script src="https://cdn.jsdelivr.net/npm/hls.js@1.5.7/dist/hls.min.js"></script>
    <script src="https://cdn.plyr.io/3.7.8/plyr.polyfilled.js"></script>
    
    <script>
        document.addEventListener('DOMContentLoaded', () => {
            const video = document.querySelector('video');
            const source = '$streamUrl';
            const errorMsg = document.getElementById('error-msg');
            const loadingMsg = document.getElementById('loading');
            
            const options = {
                captions: { active: true, update: true, language: 'en' },
                controls: ['play-large', 'play', 'progress', 'current-time', 'duration', 'mute', 'volume', 'captions', 'settings', 'pip', 'airplay', 'fullscreen'],
                autoplay: true,
                keyboard: { focused: true, global: true },
                settings: ['captions', 'quality', 'speed', 'loop'],
                tooltips: { controls: true, seek: true },
                speed: { selected: 1, options: [0.5, 0.75, 1, 1.25, 1.5, 2] }
            };

            function showError(msg) {
                loadingMsg.style.display = 'none';
                errorMsg.style.display = 'block';
                errorMsg.innerHTML = '<h3>Stream Error</h3><p>' + msg + '</p><button onclick="location.reload()">Retry Connection</button>';
            }

            if (Hls.isSupported()) {
                const hls = new Hls({
                    maxBufferLength: 60,
                    enableWorker: true,
                    lowLatencyMode: true, // Try low latency
                    backBufferLength: 60,
                });
                
                hls.loadSource(source);
                
                hls.on(Hls.Events.MANIFEST_PARSED, function (event, data) {
                    loadingMsg.style.display = 'none';
                    const availableQualities = hls.levels.map((l) => l.height);
                    options.quality = {
                        default: availableQualities[0],
                        options: availableQualities,
                        forced: true,
                        onChange: (e) => {
                            window.hls.levels.forEach((level, levelIndex) => {
                                if (level.height === e) window.hls.currentLevel = levelIndex;
                            });
                        },
                    };
                    const player = new Plyr(video, options);
                    player.on('ready', () => {
                       if ($_startAt > 0) player.currentTime = $_startAt;
                    });
                    player.on('timeupdate', () => {
                       VideoProgress.postMessage(player.currentTime.toString());
                    });
                });

                hls.on(Hls.Events.ERROR, function(event, data) {
                    if (data.fatal) {
                        switch(data.type) {
                            case Hls.ErrorTypes.NETWORK_ERROR:
                                console.log("Network error, recovering...");
                                hls.startLoad();
                                break;
                            case Hls.ErrorTypes.MEDIA_ERROR:
                                console.log("Media error, recovering...");
                                hls.recoverMediaError();
                                break;
                            default:
                                hls.destroy();
                                showError("Fatal playback error.");
                                break;
                        }
                    }
                });
                
                hls.attachMedia(video);
                window.hls = hls;
            } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
                video.src = source;
                const player = new Plyr(video, options);
                player.on('ready', () => {
                   if ($_startAt > 0) player.currentTime = $_startAt;
                });
                player.on('timeupdate', () => {
                   VideoProgress.postMessage(player.currentTime.toString());
                });
                loadingMsg.style.display = 'none';
            } else {
                showError("Video format not supported.");
            }
        });
    </script>
</body>
</html>
''';
        _controller.loadHtmlString(htmlString, baseUrl: baseUrl);
      } else {
        bool isAnimelok =
            widget.selectedType == 'hindi' || streamUrl.contains('animelok');
        _controller.loadRequest(
          Uri.parse(streamUrl),
          headers: {
            'Referer': isAnimelok
                ? 'https://animelok.site/'
                : 'https://hianime.to/',
            'Origin': isAnimelok
                ? 'https://animelok.site'
                : 'https://hianime.to',
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg =
              "Unable to load stream. Please try again or switch servers.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int currentIndex = widget.allEpisodes.indexWhere(
      (ep) => ep['episodeId'] == widget.hianimeEpisodeId,
    );
    bool hasNext =
        currentIndex >= 0 && currentIndex < widget.allEpisodes.length - 1;
    bool hasPrev = currentIndex > 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() => _showOverlay = !_showOverlay);
          if (_showOverlay) _startHideTimer();
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Center(
              child: _errorMsg != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white54,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMsg!,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _errorMsg = null;
                            });
                            _loadStream();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : SafeArea(
                      bottom: false,
                      child: WebViewWidget(controller: _controller),
                    ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                ),
              ),

            // Controls Overlay
            AnimatedOpacity(
              opacity: _showOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_showOverlay,
                child: Stack(
                  children: [
                    // Top Bar
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.animeTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Episode ${widget.episodeNumber}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Next / Prev Buttons
                    Positioned(
                      bottom: 40,
                      right: 40,
                      child: Row(
                        children: [
                          if (hasPrev)
                            FloatingActionButton.extended(
                              heroTag: 'prevBtn',
                              onPressed: () {
                                final prevEp =
                                    widget.allEpisodes[currentIndex - 1];
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PlayerScreen(
                                      animeId: widget.animeId,
                                      hianimeEpisodeId: prevEp['episodeId'],
                                      animelokId: widget.animelokId,
                                      episodeNumber: prevEp['number'],
                                      selectedType: widget.selectedType,
                                      animeTitle: widget.animeTitle,
                                      allEpisodes: widget.allEpisodes,
                                    ),
                                  ),
                                );
                              },
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.7,
                              ),
                              icon: const Icon(Icons.skip_previous_rounded),
                              label: const Text('Prev'),
                            ),
                          if (hasPrev && hasNext) const SizedBox(width: 16),
                          if (hasNext)
                            FloatingActionButton.extended(
                              heroTag: 'nextBtn',
                              onPressed: () {
                                final nextEp =
                                    widget.allEpisodes[currentIndex + 1];
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PlayerScreen(
                                      animeId: widget.animeId,
                                      hianimeEpisodeId: nextEp['episodeId'],
                                      animelokId: widget.animelokId,
                                      episodeNumber: nextEp['number'],
                                      selectedType: widget.selectedType,
                                      animeTitle: widget.animeTitle,
                                      allEpisodes: widget.allEpisodes,
                                    ),
                                  ),
                                );
                              },
                              backgroundColor: const Color(0xFF0EA5E9),
                              icon: const Icon(Icons.skip_next_rounded),
                              label: const Text('Next'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
