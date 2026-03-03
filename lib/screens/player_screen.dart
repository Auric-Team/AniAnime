import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
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
              final hindiServers = servers.where((s) => 
                s['language'] == 'Hindi' || 
                s['name'] == 'Hindi' || 
                s['tip'] == 'Multi' || 
                s['name'] == 'Multi'
              ).toList();
              
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
                
                bestRes = {
                  'server': selectedServer,
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
          if (streamUrl != null && streamUrl.contains('localhost:4000')) {
            streamUrl = streamUrl.replaceFirst('http://localhost:4000', 'https://api.tatakai.me');
          }
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
        @import url('https://fonts.googleapis.com/css2?family=Montserrat:wght@400;600;700&display=swap');
        body, html { 
            margin: 0; padding: 0; width: 100%; height: 100%; 
            background: #000; overflow: hidden; 
            display: flex; align-items: center; justify-content: center; 
            font-family: 'Montserrat', sans-serif;
            -webkit-font-smoothing: antialiased;
        }
        .plyr--video { width: 100%; height: 100%; background: #000; }
        :root { 
            --plyr-color-main: #E11D48;
            --plyr-video-control-color-hover: #fff;
            --plyr-video-control-background-hover: rgba(225, 29, 72, 0.9);
            --plyr-menu-background: rgba(15, 23, 42, 0.95);
            --plyr-menu-color: #fff;
            --plyr-font-family: 'Montserrat', sans-serif;
            --plyr-video-controls-background: linear-gradient(to top, rgba(0,0,0,0.9) 0%, rgba(0,0,0,0) 100%);
            --plyr-range-track-height: 6px;
            --plyr-range-thumb-height: 16px;
        }
        
        .plyr__control--overlaid {
            background: rgba(225, 29, 72, 0.85);
            box-shadow: 0 8px 25px rgba(225, 29, 72, 0.5);
            transition: all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275);
            padding: 24px;
        }
        .plyr__control--overlaid:hover {
            transform: scale(1.15);
            background: rgba(225, 29, 72, 1);
            box-shadow: 0 10px 30px rgba(225, 29, 72, 0.6);
        }
        
        .plyr__controls {
            padding-bottom: 25px !important;
            padding-left: 20px !important;
            padding-right: 20px !important;
        }

        #error-msg { 
            position: absolute; color: white; z-index: 10; 
            text-align: center; padding: 40px; display: none; 
            background: rgba(15, 23, 42, 0.85); 
            border-radius: 24px; border: 1px solid rgba(255,255,255,0.05);
            backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px);
            box-shadow: 0 25px 50px rgba(0,0,0,0.6);
            max-width: 85%;
            animation: fadeIn 0.5s ease;
        }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(20px); } to { opacity: 1; transform: translateY(0); } }
        
        #error-msg h3 { margin: 0 0 15px 0; color: #f43f5e; font-size: 1.5rem; font-weight: 700; letter-spacing: -0.5px;}
        #error-msg p { margin: 0 0 25px 0; color: #cbd5e1; font-size: 1rem; line-height: 1.6; }
        #error-msg button {
            padding: 12px 32px; background: linear-gradient(135deg, #E11D48, #BE123C);
            color: #fff; border: none; border-radius: 12px; font-weight: 600; font-size: 1rem;
            cursor: pointer; font-family: 'Montserrat', sans-serif; transition: all 0.3s ease;
            box-shadow: 0 10px 20px rgba(225, 29, 72, 0.3);
        }
        #error-msg button:hover { transform: translateY(-3px); box-shadow: 0 15px 25px rgba(225, 29, 72, 0.4); }
        
        #loading { 
            position: absolute; z-index: 5; 
            display: flex; flex-direction: column; align-items: center; justify-content: center;
            background: #000; width: 100%; height: 100%;
        }
        .loader {
            width: 60px; height: 60px;
            border: 4px solid rgba(255,255,255,0.1);
            border-radius: 50%;
            border-top-color: #E11D48;
            animation: spin 1s cubic-bezier(0.68, -0.55, 0.265, 1.55) infinite;
        }
        .loading-text {
            margin-top: 20px; color: #fff; font-weight: 600; letter-spacing: 2px;
            text-transform: uppercase; font-size: 0.85rem; opacity: 0.8;
            animation: pulse 1.5s ease-in-out infinite;
        }
        @keyframes spin { 100% { transform: rotate(360deg); } }
        @keyframes pulse { 0%, 100% { opacity: 0.5; } 50% { opacity: 1; } }
    </style>
</head>
<body>
    <div id="loading">
        <div class="loader"></div>
        <div class="loading-text">Loading Stream</div>
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
                errorMsg.innerHTML = '<h3>Stream Unavailable</h3><p>' + msg + '</p><button onclick="location.reload()">Retry Connection</button>';
            }

            let player;
            
            function initPlayer(startTime = 0) {
                loadingMsg.style.display = 'flex';
                errorMsg.style.display = 'none';

                if (typeof Hls !== 'undefined' && Hls.isSupported()) {
                    const hls = new Hls({
                        maxBufferLength: 60,
                        maxMaxBufferLength: 120,
                        maxBufferSize: 120 * 1000 * 1000,
                        maxBufferHole: 0.3,
                        enableWorker: true,
                        lowLatencyMode: false,
                        backBufferLength: 60,
                        manifestLoadingMaxRetry: 10,
                        levelLoadingMaxRetry: 10,
                        fragLoadingMaxRetry: 10,
                        startLevel: -1
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
                            onChange: (e) => {
                                window.hls.levels.forEach((level, levelIndex) => {
                                    if (level.height === e) {
                                        window.hls.currentLevel = levelIndex;
                                    }
                                });
                            },
                        };
                        
                        if (!player) {
                            player = new Plyr(video, defaultOptions);
                        }
                        
                        if (startTime > 0) {
                            video.currentTime = startTime;
                        }
                        
                        const playPromise = video.play();
                        if (playPromise !== undefined) {
                            playPromise.catch(error => {
                                console.log('Autoplay prevented', error);
                            });
                        }
                    });

                    let recoverDecodingErrorDate = null;
                    let recoverSwapAudioCodecDate = null;

                    hls.on(Hls.Events.ERROR, function(event, data) {
                        if (data.fatal) {
                            loadingMsg.style.display = 'flex';
                            switch(data.type) {
                                case Hls.ErrorTypes.NETWORK_ERROR:
                                    console.log("Fatal network error encountered, try to recover");
                                    hls.startLoad();
                                    break;
                                case Hls.ErrorTypes.MEDIA_ERROR:
                                    console.log("Fatal media error encountered, try to recover");
                                    const now = performance.now();
                                    if (!recoverDecodingErrorDate || now - recoverDecodingErrorDate > 3000) {
                                        recoverDecodingErrorDate = now;
                                        hls.recoverMediaError();
                                    } else if (!recoverSwapAudioCodecDate || now - recoverSwapAudioCodecDate > 3000) {
                                        recoverSwapAudioCodecDate = now;
                                        hls.swapAudioCodec();
                                        hls.recoverMediaError();
                                    } else {
                                        // Hard reset and resume seamlessly
                                        console.log("Hard resetting player to recover...");
                                        const cTime = video.currentTime;
                                        hls.destroy();
                                        initPlayer(cTime);
                                    }
                                    break;
                                default:
                                    // Auto reconnect on other fatal errors
                                    console.log("Unrecoverable error, auto-reconnecting...");
                                    const cTime2 = video.currentTime;
                                    hls.destroy();
                                    initPlayer(cTime2);
                                    break;
                            }
                        } else {
                            // Non-fatal, just hide error if stream is ready
                            if (video.readyState >= 3) {
                                loadingMsg.style.display = 'none';
                            }
                        }
                    });

                    hls.on(Hls.Events.FRAG_BUFFERED, () => {
                         loadingMsg.style.display = 'none';
                    });

                    hls.attachMedia(video);
                    window.hls = hls;

                } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
                    loadingMsg.style.display = 'none';
                    if (!player) {
                        player = new Plyr(video, defaultOptions);
                    }
                    video.src = source;
                    if (startTime > 0) video.currentTime = startTime;
                    video.play().catch(e => console.log('Autoplay prevented', e));
                } else {
                    loadingMsg.style.display = 'none';
                    showError("Your browser doesn't support the required video format.");
                }
            }

            try {
                initPlayer();
                
                // Show loading spinner on buffering
                video.addEventListener('waiting', () => {
                    loadingMsg.style.display = 'flex';
                });
                video.addEventListener('playing', () => {
                    loadingMsg.style.display = 'none';
                });
                video.addEventListener('seeking', () => {
                    loadingMsg.style.display = 'flex';
                });
                video.addEventListener('seeked', () => {
                    loadingMsg.style.display = 'none';
                });

            } catch (err) {
                showError("An unexpected error occurred while loading the player.");
            }
        });
    </script>
</body>
</html>
''';
        _controller.loadHtmlString(htmlString, baseUrl: baseUrl);
      } else if (streamUrl != null) {
        bool isAnimelok = widget.selectedType == 'hindi' || streamUrl.contains('animelok');
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
          String errorText = e.toString();
          if (errorText.contains('400') || errorText.contains('404')) {
            _errorMsg = "Episode unavailable. The server might have removed it or it's temporarily down.";
          } else if (errorText.contains('timeout') || errorText.contains('522')) {
            _errorMsg = "Connection timed out. The streaming server is taking too long to respond.";
          } else {
            _errorMsg = "Failed to load stream. Please try a different language or check your connection.";
          }
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
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
