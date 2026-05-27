import 'package:flutter/material.dart';

class OneImageCard extends StatelessWidget {
  final String location;
  final String imageLink;
  final double width;
  final double height;

  const OneImageCard({
    super.key,
    required this.location,
    required this.imageLink,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageLink.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image.network(
                imageLink,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _ImageFallback(),
              )
            else
              const _ImageFallback(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.82), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  location,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(
        Icons.landscape_outlined,
        color: Theme.of(context).colorScheme.primary,
        size: 42,
      ),
    );
  }
}
