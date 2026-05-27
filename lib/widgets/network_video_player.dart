import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class NetworkVideoPlayer extends StatefulWidget {
  final String url;
  final double borderRadius;

  const NetworkVideoPlayer({
    super.key,
    required this.url,
    this.borderRadius = 8,
  });

  @override
  State<NetworkVideoPlayer> createState() => _NetworkVideoPlayerState();
}

class _NetworkVideoPlayerState extends State<NetworkVideoPlayer> {
  static final Set<_NetworkVideoPlayerState> _activePlayers = {};

  VideoPlayerController? _controller;
  bool _hasStartedLoading = false;
  bool _isReady = false;
  bool _hasError = false;
  bool _isCaching = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _activePlayers.add(this);
  }

  @override
  void dispose() {
    _activePlayers.remove(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _startVideo() async {
    if (_hasStartedLoading) {
      final controller = _controller;
      if (controller != null && _isReady) {
        setState(() {
          controller.value.isPlaying ? controller.pause() : controller.play();
        });
      }
      return;
    }

    for (final player in _activePlayers.toList()) {
      if (player != this) {
        player._releaseController();
      }
    }

    setState(() {
      _hasStartedLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    await _initializeNetworkVideo();
  }

  void _releaseController() {
    final controller = _controller;
    if (controller == null) return;
    controller.dispose();
    _controller = null;
    if (!mounted) return;
    setState(() {
      _hasStartedLoading = false;
      _isReady = false;
      _hasError = false;
      _isCaching = false;
      _errorMessage = null;
    });
  }

  Future<void> _initializeNetworkVideo() async {
    try {
      await _setController(
        VideoPlayerController.networkUrl(Uri.parse(widget.url)),
      );
    } catch (error) {
      await _initializeCachedVideo(error);
    }
  }

  Future<void> _initializeCachedVideo(Object originalError) async {
    if (mounted) {
      setState(() {
        _isCaching = true;
        _errorMessage = originalError.toString();
      });
    }

    try {
      final cachedFile = await _downloadToCache();
      await _setController(VideoPlayerController.file(cachedFile));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isCaching = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _setController(VideoPlayerController nextController) async {
    final previousController = _controller;
    _controller = nextController;
    previousController?.dispose();

    await nextController.setLooping(false);
    await nextController.initialize();
    await nextController.play();

    if (!mounted) return;
    setState(() {
      _isReady = true;
      _hasError = false;
      _isCaching = false;
      _errorMessage = null;
    });
  }

  Future<File> _downloadToCache() async {
    final safeName = widget.url.hashCode.abs().toString();
    final file = File(
      '${Directory.systemTemp.path}/riendzo_video_$safeName.mp4',
    );

    if (await file.exists() && await file.length() > 0) {
      return file;
    }

    final response = await http.get(Uri.parse(widget.url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Video download failed (${response.statusCode}).');
    }

    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  @override
  Widget build(BuildContext context) {
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
        child: const _VideoFallback(
          icon: Icons.play_circle_outline_rounded,
          text: 'Tap to play',
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

    return GestureDetector(
      onTap: _startVideo,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
            if (!controller.value.isPlaying)
              const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 56,
                ),
              ),
          ],
        ),
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
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
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
