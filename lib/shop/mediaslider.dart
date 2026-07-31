import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:carousel_slider/carousel_slider.dart';

// Widget to display a video from a URL
import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadVideoWithCache();
  }

  Future<void> _loadVideoWithCache() async {
    try {
      final file = await DefaultCacheManager().getSingleFile(widget.videoUrl);
      _controller = VideoPlayerController.file(File(file.path));
      await _controller.initialize();
      setState(() {
        _isVideoInitialized = true;
      });
      _controller.play();
    } catch (e) {
      print('Error loading video: $e');
      setState(() {
        _isVideoInitialized = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isVideoInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          )
        : const Center(child: CircularProgressIndicator());
  }
}


// Reusable MediaSlider widget
 
// Reusable MediaSlider widget
class MediaSliderss extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  MediaSliderss({super.key});

  static const int _maxSlides = 6; // limit how many items on home

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') || lower.contains('mp4');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      // 🔹 One-time fetch instead of a live snapshots() stream
      future: _firestore
          .collection('slider')
            .where('isPublish', isEqualTo: true)
          // .orderBy('position') // uncomment if you add an ordering field
          .limit(_maxSlides)
          .get(),
      builder: (context, snapshot) {
        final height = MediaQuery.of(context).size.height * 0.21;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return SizedBox(
            height: height,
            child: Center(
              child: Text(
                'Failed to load slider',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // No slider items configured
          return const SizedBox.shrink();
        }

        final items = snapshot.data!.docs
            .map((doc) => (doc['url'] as String?) ?? '')
            .where((url) => url.isNotEmpty)
            .toList();

        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        return CarouselSlider.builder(
          itemCount: items.length,
          itemBuilder: (context, index, realIndex) {
            final item = items[index];

            // 🔸 INLINE AUTO-PLAY VIDEO (unchanged behaviour)
            if (_isVideoUrl(item)) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  color: Colors.black,
                  child: VideoPlayerWidget(videoUrl: item),
                ),
              );
            }

            // 🔸 IMAGE SLIDE
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3.0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: CachedNetworkImage(
                  imageUrl: item,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.error),
                ),
              ),
            );
          },
          options: CarouselOptions(
            height: height,
            autoPlay: true,
            viewportFraction: 0.8,
            // enlargeCenterPage: true,
          ),
        );
      },
    );
  }
}

