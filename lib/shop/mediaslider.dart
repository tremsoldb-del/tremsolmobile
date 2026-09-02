import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

/// Slider video that starts from the network immediately on a first visit,
/// but reuses the persistent file cache on later visits.
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isVideoInitialized = false;
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
      final cachedFile =
          await DefaultCacheManager().getFileFromCache(widget.videoUrl);

      if (!mounted) return;

      if (cachedFile != null && await File(cachedFile.file.path).exists()) {
        _controller = VideoPlayerController.file(cachedFile.file);
      } else {
        // Do not wait for the whole MP4 to download before showing the video.
        _controller = VideoPlayerController.network(widget.videoUrl);
      }

      await _controller!.initialize();
      if (!mounted) return;

      await _controller!.setLooping(true);
      await _controller!.setVolume(0);
      await _controller!.play();

      setState(() {
        _isVideoInitialized = true;
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
      debugPrint('[Slider video] Load error: $error');
      if (!mounted) return;
      setState(() {
        _isVideoInitialized = false;
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
      debugPrint('[Slider video] Background cache failed: $error');
    }
  }

  @override
  void dispose() {
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Icon(Icons.videocam_off_outlined, color: Colors.white70),
        ),
      );
    }

    if (!_isVideoInitialized || _controller == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}

/// Home-page media slider.
///
/// Cache behaviour:
/// 1. Firestore slider metadata is read from the local cache first.
/// 2. The server is then queried in the background to refresh the cache.
/// 3. Image slides use CachedNetworkImage and are also pre-warmed.
/// 4. Video slides reuse the persistent file cache after the first view.
class MediaSliderss extends StatefulWidget {
  const MediaSliderss({super.key});

  @override
  State<MediaSliderss> createState() => _MediaSliderssState();
}

class _MediaSliderssState extends State<MediaSliderss> {
  static const int _maxSlides = 6;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> _items = <String>[];
  bool _isLoading = true;
  Object? _error;

  Query<Map<String, dynamic>> get _sliderQuery => _firestore
      .collection('slider')
      .where('isPublish', isEqualTo: true)
      .limit(_maxSlides);

  @override
  void initState() {
    super.initState();
    _loadSliderCacheFirst();
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') || lower.contains('.mp4?');
  }

  List<String> _urlsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((doc) => (doc.data()['url'] ?? '').toString().trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _loadSliderCacheFirst() async {
    QuerySnapshot<Map<String, dynamic>>? cachedSnapshot;

    try {
      cachedSnapshot = await _sliderQuery.get(
        const GetOptions(source: Source.cache),
      );
      final cachedItems = _urlsFromSnapshot(cachedSnapshot);

      if (mounted && cachedItems.isNotEmpty) {
        setState(() {
          _items = cachedItems;
          _isLoading = false;
          _error = null;
        });
        _precacheImages(cachedItems);
      }
    } catch (error) {
      debugPrint('[Slider] Cache read unavailable: $error');
    }

    try {
      final serverSnapshot = await _sliderQuery.get(
        const GetOptions(source: Source.server),
      );
      final serverItems = _urlsFromSnapshot(serverSnapshot);

      if (!mounted) return;
      setState(() {
        _items = serverItems;
        _isLoading = false;
        _error = null;
      });
      _precacheImages(serverItems);
    } catch (error) {
      debugPrint('[Slider] Server refresh failed: $error');
      if (!mounted) return;

      final hasCachedData =
          cachedSnapshot != null && _urlsFromSnapshot(cachedSnapshot).isNotEmpty;
      if (_items.isEmpty && !hasCachedData) {
        setState(() {
          _isLoading = false;
          _error = error;
        });
      }
    }
  }

  void _precacheImages(List<String> items) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final url in items) {
        if (_isVideoUrl(url)) continue;
        precacheImage(
          CachedNetworkImageProvider(url),
          context,
        ).catchError((_) {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.21;

    if (_isLoading && _items.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }

    if (_error != null && _items.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _loadSliderCacheFirst();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry slider'),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }

    return CarouselSlider.builder(
      itemCount: _items.length,
      itemBuilder: (context, index, realIndex) {
        final item = _items[index];

        if (_isVideoUrl(item)) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              color: Colors.black,
              child: VideoPlayerWidget(videoUrl: item),
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            color: Colors.white,
            child: CachedNetworkImage(
              imageUrl: item,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.image_not_supported_outlined),
            ),
          ),
        );
      },
      options: CarouselOptions(
        height: height,
        autoPlay: true,
        viewportFraction: 0.8,
      ),
    );
  }
}
