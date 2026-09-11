import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:riendzo/widgets/network_video_player.dart';

class PostMediaCarousel extends StatefulWidget {
  final List<String> mediaPaths;
  final List<String> mediaTypes;

  const PostMediaCarousel({
    super.key,
    required this.mediaPaths,
    required this.mediaTypes,
  });

  @override
  State<PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<PostMediaCarousel> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.mediaPaths.isEmpty) return const SizedBox.shrink();

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: widget.mediaPaths.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) {
              final url = widget.mediaPaths[index];
              if (_isVideo(index)) {
                return NetworkVideoPlayer(url: url, autoPlay: true);
              }
              return CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, _) => ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, _, _) => ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined, size: 38),
                  ),
                ),
              );
            },
          ),
          if (widget.mediaPaths.length > 1)
            Positioned(
              top: 12,
              right: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    '${_page + 1}/${widget.mediaPaths.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          if (widget.mediaPaths.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.mediaPaths.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == _page ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: index == _page ? Colors.white : Colors.white60,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isVideo(int index) {
    final type = index < widget.mediaTypes.length
        ? widget.mediaTypes[index]
        : '';
    if (type == 'video') return true;
    final path = widget.mediaPaths[index].toLowerCase();
    return path.contains('.mp4') ||
        path.contains('.mov') ||
        path.contains('.m4v') ||
        path.contains('video%2f') ||
        path.contains('video/');
  }
}
