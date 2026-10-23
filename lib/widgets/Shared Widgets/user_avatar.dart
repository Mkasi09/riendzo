import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:riendzo/services/app_image_cache.dart';

class UserAvatar extends StatelessWidget {
  final double size;
  final String picture;

  const UserAvatar({super.key, required this.size, required this.picture});

  @override
  Widget build(BuildContext context) {
    final hasPicture = picture.trim().isNotEmpty;

    return CircleAvatar(
      radius: size,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: hasPicture
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: picture,
                cacheManager: AppImageCache.instance,
                width: size * 2,
                height: size * 2,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const Icon(Icons.person),
              ),
            )
          : const Icon(Icons.person),
    );
  }
}
