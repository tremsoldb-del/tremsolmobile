import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class MediaSliderPage extends StatefulWidget {
  const MediaSliderPage({super.key});

  @override
  _MediaSliderPageState createState() => _MediaSliderPageState();
}

class _MediaSliderPageState extends State<MediaSliderPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('slider').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No media found.'));
        }

        // Separate image URLs and video URLs
        List<String> imageUrls = [];
        String? videoUrl;
        for (var doc in snapshot.data!.docs) {
          String url = (doc.data() as Map<String, dynamic>)['url'];
          if (url.toLowerCase().endsWith('.mp4')) {
            videoUrl = url;
          } else {
            imageUrls.add(url);
          }
        }

        return SizedBox(
          height: MediaQuery.of(context).size.height / 1.8,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: imageUrls.length + (videoUrl != null ? 1 : 0),
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  if (index == 0 && videoUrl != null) {
                    // Display video as the first item
                    return SizedBox(
                      height: MediaQuery.of(context).size.height / 3,
                      child: VideoWidget(videoUrl: videoUrl),
                    );
                  } else {
                    // Display images after the video
                    final imageIndex = index - (videoUrl != null ? 1 : 0);
                    return Container(
                      margin: const EdgeInsets.all(2),
                      width: MediaQuery.of(context).size.width / 1.3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(imageUrls[imageIndex]),
                          fit: BoxFit.fill,
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class VideoWidget extends StatefulWidget {
  final String? videoUrl;

  const VideoWidget({this.videoUrl, super.key});

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;

  @override
  void initState() {
    super.initState();
    _videoPlayerController = VideoPlayerController.network(widget.videoUrl!)
      ..initialize().then((_) {
        setState(() {}); // Update UI after initialization
      });

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: false,
      looping: true,
      autoInitialize: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _videoPlayerController.value.isInitialized
        ? Chewie(controller: _chewieController)
        : const Center(
            child: CircularProgressIndicator(),
          );
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController.dispose();
    super.dispose();
  }
}
