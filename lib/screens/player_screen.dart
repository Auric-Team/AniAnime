import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/api_service.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String hianimeEpisodeId;
  final String? animelokId;
  final int episodeNumber;
  final String selectedType;
  final String animeTitle;

  const PlayerScreen({
    super.key,
    required this.hianimeEpisodeId,
    this.animelokId,
    required this.episodeNumber,
    required this.selectedType,
    required this.animeTitle,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMsg;
  String _currentBaseUrl = '';

  @override
  void initState() {
    super.initState();
    // Allow landscape rotation for full screen immersive experience
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Hide status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = WebViewController()
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
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
                url.contains('vidplay')) {
              return NavigationDecision.navigate;
            }
            // Block all other redirects (e.g. ad popups attempting to hijack the frame)
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
            if (mounted) {
              setState(() {
                _errorMsg = "Failed to load player: ${error.description}";
                _isLoading = false;
              });
            }
          },
        ),
      );
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
              // Look for Hindi servers (try M3U8 first for better quality)
              final hindiServers = servers.where((s) => s['language'] == 'Hindi').toList();
              
              if (hindiServers.isNotEmpty) {
                // Prefer M3U8 streams for better playback
                final m3u8Server = hindiServers.firstWhere(
                  (s) => s['isM3U8'] == true,
                  orElse: () => hindiServers.first,
                );
                bestRes = {
                  'server': m3u8Server,
                  'episodeNumber': epNum,
                };
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
          isM3U8 = server['isM3U8'] == true;
          if (isM3U8) baseUrl = 'https://animelok.site/';
        } else {
          throw Exception('No Hindi server found for this episode');
        }
      } else {
        // Fetch HiAnime sources using API directly!
        final api = ref.read(apiServiceProvider);
        Map<String, dynamic>? res;
        try {
          res = await api.getHiAnimeEpisodeSources(
            widget.hianimeEpisodeId,
            widget.selectedType,
          );
        } catch (e) {
          // If dub fails, try falling back to sub automatically!
          if (widget.selectedType == 'dub') {
            try {
              res = await api.getHiAnimeEpisodeSources(
                widget.hianimeEpisodeId,
                'sub',
              );
            } catch (_) {
              rethrow;
            }
          } else {
            rethrow;
          }
        }

        if (res['sources'] != null) {
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
        // For Hindi, fallback to sub if Hindi not available
        if (widget.selectedType == 'hindi') {
          try {
            final api = ref.read(apiServiceProvider);
            final res = await api.getHiAnimeEpisodeSources(widget.hianimeEpisodeId, 'sub');
            if (res['sources'] != null) {
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
          } catch (_) {
            throw Exception('No Hindi stream found and fallback failed.');
          }
        } else {
          throw Exception('No stream found for the selected language.');
        }
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
        @import url('https://fonts.googleapis.com/css2?family=Poppins:wght@400;600&display=swap');
        body, html { 
            margin: 0; padding: 0; width: 100%; height: 100%; 
            background: #000; overflow: hidden; 
            display: flex; align-items: center; justify-content: center; 
            font-family: 'Poppins', sans-serif;
        }
        .plyr--video { width: 100%; height: 100%; }
        :root { 
            --plyr-color-main: #0EA5E9;
            --plyr-video-control-background-hover: rgba(14, 165, 233, 0.8);
            --plyr-menu-background: rgba(15, 23, 42, 0.95);
            --plyr-menu-color: #fff;
            --plyr-font-family: 'Poppins', sans-serif;
            --plyr-video-controls-background: linear-gradient(rgba(0,0,0,0), rgba(0,0,0,0.8));
        }
        
        .plyr__control--overlaid {
            background: rgba(14, 165, 233, 0.8);
            box-shadow: 0 4px 15px rgba(14, 165, 233, 0.4);
            transition: all 0.3s ease;
        }
        .plyr__control--overlaid:hover {
            transform: scale(1.1);
            background: rgba(14, 165, 233, 1);
        }
        
        #error-msg { 
            position: absolute; color: white; z-index: 10; 
            text-align: center; padding: 30px; display: none; 
            background: rgba(15, 23, 42, 0.9); 
            border-radius: 16px; border: 1px solid rgba(255,255,255,0.1);
            backdrop-filter: blur(10px); box-shadow: 0 10px 30px rgba(0,0,0,0.5);
            max-width: 80%;
        }
        #error-msg h3 { margin: 0 0 10px 0; color: #ef4444; font-size: 1.2rem; }
        #error-msg p { margin: 0 0 20px 0; color: #cbd5e1; font-size: 0.9rem; line-height: 1.4; }
        #error-msg button {
            padding: 10px 24px; background: linear-gradient(135deg, #0EA5E9, #3B82F6);
            color: #fff; border: none; border-radius: 8px; font-weight: 600;
            cursor: pointer; font-family: 'Poppins', sans-serif; transition: all 0.2s;
        }
        #error-msg button:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(14, 165, 233, 0.4); }
        
        #loading { 
            position: absolute; z-index: 5; 
            display: flex; flex-direction: column; align-items: center;
        }
        .spinner {
            width: 40px; height: 40px; border: 4px solid rgba(255,255,255,0.1);
            border-left-color: #0EA5E9; border-radius: 50%;
            animation: spin 1s linear infinite; margin-bottom: 12px;
        }
        @keyframes spin { 100% { transform: rotate(360deg); } }
    </style>
</head>
<body>
    <div id="loading">
        <div class="spinner"></div>
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
            
            const defaultOptions = {
                captions: { active: true, update: true, language: 'en' },
                controls: ['play-large', 'play', 'progress', 'current-time', 'duration', 'mute', 'volume', 'captions', 'settings', 'pip', 'airplay', 'fullscreen'],
                autoplay: true,
                keyboard: { focused: true, global: true },
                settings: ['captions', 'quality', 'speed', 'loop'],
                tooltips: { controls: true, seek: true }
            };

            function showError(msg) {
                loadingMsg.style.display = 'none';
                errorMsg.style.display = 'block';
                errorMsg.innerHTML = '<h3>Stream Error</h3><p>' + msg + '</p><button onclick="location.reload()">Retry Connection</button>';
            }

            try {
                if (typeof Hls !== 'undefined' && Hls.isSupported()) {
                    const hls = new Hls({
                        maxBufferLength: 30,
                        maxMaxBufferLength: 60,
                        maxBufferSize: 60 * 1000 * 1000,
                        maxBufferHole: 0.5,
                        enableWorker: true,
                        lowLatencyMode: true,
                        backBufferLength: 30
                    });
                    
                    hls.autoLevelEnabled = true;
                    
                    hls.loadSource(source);
                    hls.on(Hls.Events.MANIFEST_PARSED, function (event, data) {
                        loadingMsg.style.display = 'none';
                        const availableQualities = hls.levels.map((l) => l.height);
                        defaultOptions.quality = {
                            default: availableQualities[0],
                            options: availableQualities,
                            forced: true,
                            onChange: (e) => updateQuality(e),
                        };
                        const player = new Plyr(video, defaultOptions);
                        
                        // Force play attempt
                        const playPromise = video.play();
                        if (playPromise !== undefined) {
                            playPromise.catch(error => {
                                console.log('Autoplay prevented', error);
                            });
                        }
                    });

                    hls.on(Hls.Events.ERROR, function(event, data) {
                        if (data.fatal) {
                            switch(data.type) {
                                case Hls.ErrorTypes.NETWORK_ERROR:
                                    console.log("Fatal network error encountered, try to recover");
                                    hls.startLoad();
                                    break;
                                case Hls.ErrorTypes.MEDIA_ERROR:
                                    console.log("Fatal media error encountered, try to recover");
                                    hls.recoverMediaError();
                                    break;
                                default:
                                    showError(data.details);
                                    hls.destroy();
                                    break;
                            }
                        }
                    });
                    hls.attachMedia(video);
                    window.hls = hls;
                    
                    function updateQuality(newQuality) {
                        window.hls.levels.forEach((level, levelIndex) => {
                            if (level.height === newQuality) {
                                window.hls.currentLevel = levelIndex;
                            }
                        });
                    }
                } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
                    // Native HLS support (Safari / iOS)
                    loadingMsg.style.display = 'none';
                    const player = new Plyr(video, defaultOptions);
                    video.src = source;
                    video.play().catch(e => console.log('Autoplay prevented', e));
                } else {
                    showError("Your browser doesn't support the required video format.");
                }
            } catch (err) {
                showError(err.message);
            }
        });
    </script>
</body>
</html>
''';
        _controller.loadHtmlString(htmlString, baseUrl: baseUrl);
      } else if (streamUrl != null) {
        _controller.loadRequest(
          Uri.parse(streamUrl),
          headers: {
            'Referer': streamUrl.contains('animelok')
                ? 'https://animelok.site/'
                : 'https://hianime.to/',
            'Origin': streamUrl.contains('animelok')
                ? 'https://animelok.site'
                : 'https://hianime.to',
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _errorMsg != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white54,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Stream Error: $_errorMsg',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMsg = null;
                          });
                          _loadStream();
                        },
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Reload Source',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                child: CircularProgressIndicator(
                  color: Color(0xFF0EA5E9),
                  strokeWidth: 3,
                ),
              ),
            ),

          // Back Button Overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
