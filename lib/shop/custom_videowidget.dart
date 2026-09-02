import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

class VideoWidget extends StatefulWidget {
  final String videoUrl;
  final String? posterUrl;

  const VideoWidget({
    super.key,
    required this.videoUrl,
    this.posterUrl,
  });

  @override
  State<VideoWidget> createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  VideoPlayerController? _controller;
  bool _isMuted = true;
  bool _isLoading = true;
  bool _hasError = false;
  bool _cacheAfterFirstPlayback = false;
  bool _cacheStarted = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // Fast path: use the persistent video file when this product video has
      // already been viewed before.
      final cachedFile =
          await DefaultCacheManager().getFileFromCache(widget.videoUrl);

      if (!mounted) return;

      if (cachedFile != null && await File(cachedFile.file.path).exists()) {
        _controller = VideoPlayerController.file(cachedFile.file);
      } else {
        // First visit: start streaming immediately. Do NOT wait for the whole
        // MP4 to download before initializing the player.
        _controller = VideoPlayerController.network(widget.videoUrl);
      }

      await _controller!.initialize();
      if (!mounted) return;

      await _controller!.setLooping(true);
      await _controller!.setVolume(_isMuted ? 0.0 : 1.0);
      await _controller!.play();

      setState(() {
        _isLoading = false;
        _hasError = false;
      });

      // On a cache miss, prioritize playback speed. Cache only after the
      // first full playback so we do not run a second download alongside
      // the stream while the user is waiting for the video to start.
      if (cachedFile == null) {
        _cacheAfterFirstPlayback = true;
        _controller!.addListener(_maybeCacheAfterPlayback);
      }
    } catch (error) {
      debugPrint('[Product video] Load error: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _maybeCacheAfterPlayback() {
    if (!_cacheAfterFirstPlayback || _cacheStarted) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final duration = controller.value.duration;
    final position = controller.value.position;
    if (duration <= Duration.zero) return;

    if (position >= duration - const Duration(milliseconds: 600)) {
      _cacheStarted = true;
      _cacheAfterFirstPlayback = false;
      controller.removeListener(_maybeCacheAfterPlayback);
      _cacheVideoInBackground();
    }
  }

  Future<void> _cacheVideoInBackground() async {
    try {
      await DefaultCacheManager().downloadFile(widget.videoUrl);
    } catch (error) {
      debugPrint('[Product video] Background cache failed: $error');
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller?.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  @override
  void dispose() {
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildLoadingBackground() {
    final poster = widget.posterUrl?.trim() ?? '';

    if (poster.isEmpty) {
      return const ColoredBox(color: Colors.black);
    }

    return Positioned.fill(
      child: CachedNetworkImage(
        imageUrl: poster,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) =>
            const ColoredBox(color: Colors.black),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isLoading || !ready) _buildLoadingBackground(),
          if (ready)
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          if (_isLoading)
            const Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            ),
          if (_hasError)
            const Center(
              child: Icon(
                Icons.videocam_off_outlined,
                color: Colors.white,
                size: 38,
              ),
            ),
          if (ready) ...[
            Positioned(
              bottom: 80,
              right: 20,
              child: FloatingActionButton(
                heroTag: null,
                mini: true,
                backgroundColor: Colors.black.withOpacity(0.7),
                onPressed: _togglePlayback,
                child: Icon(
                  controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                heroTag: null,
                mini: true,
                backgroundColor: Colors.black.withOpacity(0.7),
                onPressed: _toggleMute,
                child: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
