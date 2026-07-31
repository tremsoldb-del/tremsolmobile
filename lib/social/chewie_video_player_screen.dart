import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

class ChewieVideoPlayerScreen extends StatefulWidget {
  final String trailerUrl;
  final String movietitle;

  const ChewieVideoPlayerScreen({
    super.key,
    required this.trailerUrl,
    required this.movietitle,
  });

  @override
  _ChewieVideoPlayerScreenState createState() =>
      _ChewieVideoPlayerScreenState();
}

class _ChewieVideoPlayerScreenState extends State<ChewieVideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;

  @override
  void initState() {
    super.initState();
    _videoPlayerController = VideoPlayerController.network(widget.trailerUrl);
    _videoPlayerController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    _videoPlayerController.initialize().then((_) {
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController,
          autoPlay: true,
          looping: false,
          aspectRatio: _videoPlayerController.value.aspectRatio,
        );
      });
    });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.movietitle), // Display the movie title
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: _videoPlayerController.value.isInitialized
            ? Chewie(controller: _chewieController)
            : const CircularProgressIndicator(), // Show a loader while initializing
      ),
    );
  }
}
