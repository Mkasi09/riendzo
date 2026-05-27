import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final double size;
  final String picture;

  const UserAvatar({super.key, required this.size, required this.picture});

  @override
  Widget build(BuildContext context) {
    final hasPicture = picture.trim().isNotEmpty;

    return CircleAvatar(
      radius: size,
      backgroundImage: hasPicture ? NetworkImage(picture) : null,
      child: hasPicture ? null : const Icon(Icons.person),
    );
  }
}
