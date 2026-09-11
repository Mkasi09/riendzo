import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class NetworkVideoPlayer extends StatefulWidget {
  final String url;
  final double borderRadius;
  final bool autoPlay;

  const NetworkVideoPlayer({
    super.key,
    required this.url,
    this.borderRadius = 8,
    this.autoPlay = false,
  });

  @override
  State<NetworkVideoPlayer> createState() => _NetworkVideoPlayerState();
}

class _NetworkVideoPlayerState extends State<NetworkVideoPlayer>
    with WidgetsBindingObserver {
  static final Set<_NetworkVideoPlayerState> _activePlayers = {};
  static Future<void> _initializationQueue = Future<void>.value();
  static _NetworkVideoPlayerState? _playbackOwner;
  static _NetworkVideoPlayerState? _autoPlayCandidate;
  static Timer? _autoPlayTimer;

  VideoPlayerController? _controller;
  bool _hasStartedLoading = false;
  bool _isReady = false;
  bool _hasError = false;
  bool _isCaching = false;
  bool _isMuted = true;
  bool _isVisible = false;
  bool _wasPlaying = false;
  bool _wasBuffering = false;
  int _generation = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activePlayers.add(this);
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 50,
    );
  }

  @override
  void didUpdateWidget(covariant NetworkVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      unawaited(_resetForNewUrl());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller?.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activePlayers.remove(this);
    if (_playbackOwner == this) _playbackOwner = null;
    if (_autoPlayCandidate == this) {
      _autoPlayCandidate = null;
      _autoPlayTimer?.cancel();
    }
    _generation++;
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _startVideo() async {
    if (_hasStartedLoading) {
      final controller = _controller;
      if (controller != null && _isReady) {
        if (controller.value.isPlaying) {
          await controller.pause();
        } else {
          await _claimPlayback();
          if (!mounted || _playbackOwner != this) return;
          await controller.play();
        }
      }
      return;
    }

    await _claimPlayback();
    if (!mounted || _playbackOwner != this) return;
    final generation = ++_generation;
    setState(() {
      _hasStartedLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
    final queued = _initializationQueue.then((_) async {
      if (!_isCurrentRequest(generation)) return;
      await _initializeNetworkVideo(generation);
    });
    _initializationQueue = queued.catchError((_) {});
    await queued;
  }

  Future<void> _resetForNewUrl() async {
    await _releaseController();
    if (_isVisible && widget.autoPlay) await _startVideo();
  }

  Future<void> _claimPlayback() async {
    _playbackOwner = this;
    await Future.wait(
      _activePlayers
          .where((player) => player != this)
          .map((player) => player._releaseController()),
    );
    // Some MediaTek codecs release their hardware slot just after dispose.
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  Future<void> _releaseController() async {
    _generation++;
    if (_playbackOwner == this) _playbackOwner = null;
    final controller = _controller;
    controller?.removeListener(_onControllerChanged);
    await controller?.dispose();
    _controller = null;
    if (!mounted) return;
    setState(() {
      _hasStartedLoading = false;
      _isReady = false;
      _hasError = false;
      _isCaching = false;
      _wasPlaying = false;
      _wasBuffering = false;
      _errorMessage = null;
    });
  }

  bool _isCurrentRequest(int generation) {
    return mounted &&
        generation == _generation &&
        _playbackOwner == this &&
        _hasStartedLoading;
  }

  Future<void> _initializeNetworkVideo(int generation) async {
    try {
      if (!kIsWeb) {
        final cached = await DefaultCacheManager().getFileFromCache(widget.url);
        if (cached != null && await cached.file.exists()) {
          await _setController(
            VideoPlayerController.file(cached.file, viewType: _videoViewType),
            generation,
          );
          return;
        }
      }
      await _setController(
        VideoPlayerController.networkUrl(
          Uri.parse(widget.url),
          viewType: _videoViewType,
        ),
        generation,
      );
      if (!kIsWeb && _isCurrentRequest(generation)) {
        unawaited(_warmVideoCache());
      }
    } catch (error) {
      if (!_isCurrentRequest(generation)) return;
      if (kIsWeb) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _errorMessage = error.toString();
        });
        return;
      }
      await _initializeCachedVideo(error, generation);
    }
  }

  Future<void> _initializeCachedVideo(
    Object originalError,
    int generation,
  ) async {
    if (mounted) {
      setState(() {
        _isCaching = true;
        _errorMessage = originalError.toString();
      });
    }

    try {
      final cachedFile = await _downloadToCache();
      if (!_isCurrentRequest(generation)) return;
      await _setController(
        VideoPlayerController.file(cachedFile, viewType: _videoViewType),
        generation,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isCaching = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _setController(
    VideoPlayerController nextController,
    int generation,
  ) async {
    if (!_isCurrentRequest(generation)) {
      await nextController.dispose();
      return;
    }
    final previousController = _controller;
    previousController?.removeListener(_onControllerChanged);
    _controller = nextController;
    await previousController?.dispose();

    await nextController.setLooping(true);
    await nextController.initialize();
    await nextController.setVolume(_isMuted ? 0 : 1);
    nextController.addListener(_onControllerChanged);

    if (!_isCurrentRequest(generation) || _controller != nextController) {
      await nextController.dispose();
      return;
    }
    setState(() {
      _isReady = true;
      _hasError = false;
      _isCaching = false;
      _errorMessage = null;
    });
    if (_isVisible || !widget.autoPlay) {
      await nextController.play();
    }
  }

  void _onControllerChanged() {
    final value = _controller?.value;
    if (!mounted || value == null) return;
    if (_wasPlaying == value.isPlaying && _wasBuffering == value.isBuffering) {
      return;
    }
    _wasPlaying = value.isPlaying;
    _wasBuffering = value.isBuffering;
    setState(() {});
  }

  void _handleVisibility(VisibilityInfo info) {
    final visible = info.visibleFraction >= 0.42;
    _isVisible = visible;
    if (!widget.autoPlay) {
      if (info.visibleFraction < 0.15) _controller?.pause();
      return;
    }
    if (visible) {
      if (!(_controller?.value.isPlaying ?? false)) _scheduleAutoPlay();
    } else if (info.visibleFraction < 0.12) {
      if (_autoPlayCandidate == this) {
        _autoPlayCandidate = null;
        _autoPlayTimer?.cancel();
      }
      unawaited(_releaseController());
    } else if (info.visibleFraction < 0.35) {
      _controller?.pause();
    }
  }

  void _scheduleAutoPlay() {
    _autoPlayCandidate = this;
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer(const Duration(milliseconds: 60), () {
      final candidate = _autoPlayCandidate;
      if (candidate == null || !candidate.mounted || !candidate._isVisible) {
        return;
      }
      if (!candidate._hasStartedLoading) {
        unawaited(candidate._startVideo());
      } else if (candidate._isReady &&
          !(candidate._controller?.value.isPlaying ?? false)) {
        unawaited(candidate._resumePlayback());
      }
    });
  }

  Future<void> _resumePlayback() async {
    await _claimPlayback();
    if (!mounted || _playbackOwner != this) return;
    await _controller?.play();
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _isMuted = !_isMuted);
    await controller.setVolume(_isMuted ? 0 : 1);
  }

  VideoViewType get _videoViewType {
    if (!kIsWeb && Platform.isAndroid) return VideoViewType.platformView;
    return VideoViewType.textureView;
  }

  Future<File> _downloadToCache() async {
    return DefaultCacheManager().getSingleFile(widget.url);
  }

  Future<void> _warmVideoCache() async {
    try {
      await DefaultCacheManager().downloadFile(widget.url, key: widget.url);
    } catch (_) {
      // Streaming playback continues even if background caching fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey('video-${widget.url}'),
      onVisibilityChanged: _handleVisibility,
      child: _buildPlayer(context),
    );
  }

  Widget _buildPlayer(BuildContext context) {
    if (_hasError) {
      return GestureDetector(
        onTap: _startVideo,
        child: _VideoFallback(
          icon: Icons.refresh_rounded,
          text: 'Tap to retry video',
          detail: _errorMessage,
        ),
      );
    }
    if (!_hasStartedLoading) {
      return GestureDetector(
        onTap: _startVideo,
        child: _VideoFallback(
          icon: Icons.play_circle_fill_rounded,
          text: widget.autoPlay ? 'Video ready to play' : 'Tap to play',
        ),
      );
    }
    if (!_isReady) {
      return _VideoFallback(
        icon: Icons.downloading_rounded,
        text: _isCaching ? 'Preparing video' : 'Loading video',
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const _VideoFallback(
        icon: Icons.play_circle_outline_rounded,
        text: 'Loading video',
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _startVideo,
            child: ColoredBox(
              color: Colors.black,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          ),
          if (!controller.value.isPlaying)
            Center(
              child: IconButton.filled(
                onPressed: _startVideo,
                iconSize: 38,
                icon: const Icon(Icons.play_arrow_rounded),
              ),
            ),
          if (controller.value.isBuffering)
            const Center(child: CircularProgressIndicator()),
          Positioned(
            left: 10,
            right: 6,
            bottom: 6,
            child: Row(
              children: [
                Expanded(
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    colors: VideoProgressColors(
                      playedColor: Theme.of(context).colorScheme.primary,
                      bufferedColor: Colors.white54,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _isMuted ? 'Unmute video' : 'Mute video',
                  onPressed: _toggleMute,
                  icon: Icon(
                    _isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoFallback extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? detail;

  const _VideoFallback({required this.icon, required this.text, this.detail});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(text, style: Theme.of(context).textTheme.bodyMedium),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  detail!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
