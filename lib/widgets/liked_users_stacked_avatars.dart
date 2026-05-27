import 'package:flutter/material.dart';
import 'package:riendzo/widgets/Shared%20Widgets/user_avatar.dart';

class StackedAvatars extends StatelessWidget {
  final dynamic usersLikedAvatar1, usersLikedAvatar2, usersLikedAvatar3;

  const StackedAvatars(
      {super.key,
      this.usersLikedAvatar1,
      this.usersLikedAvatar2,
      this.usersLikedAvatar3});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                child: UserAvatar(
                  size: 10,
                  picture: usersLikedAvatar1,
                ),
              ),
              Positioned(
                left: -9,
                child: UserAvatar(
                  size: 10,
                  picture: usersLikedAvatar2,
                ),
              ),
              Positioned(
                left: -18,
                child: UserAvatar(
                  size: 10,
                  picture: usersLikedAvatar2,
                ),
              )
            ],
          ),
        )
      ],
    );
  }
}
