import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:riendzo/widgets/Shared%20Widgets/icon_text_row.dart';
import 'package:riendzo/widgets/Shared%20Widgets/user_avatar.dart';

class UserPost extends StatelessWidget {
  int likes, noComments, profilePicSize, noPost;
  double imageHeight;
  String picture, profilePicture, comments, caption, timePosted, name, lastName;

  UserPost({
    super.key,
    required this.picture,
    required this.comments,
    required this.caption,
    required this.noPost,
    required this.name,
    required this.lastName,
    required this.likes,
    required this.noComments,
    required this.timePosted,
    required this.imageHeight,
    required this.profilePicture,
    required this.profilePicSize,
  });
  static const iconSize = 17;
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: noPost,
      shrinkWrap: true,
      scrollDirection: Axis.vertical,
      itemBuilder: (context, index) {
        return Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 3,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            UserAvatar(
                              size: profilePicSize * 1.0,
                              picture: profilePicture,
                            ),
                            Text(
                              "   $name $lastName",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          "...",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 30,
                          ),
                        ),
                      ],
                    ),
                    Text(caption, textAlign: TextAlign.justify),
                  ],
                ),
              ),
              Container(
                height: imageHeight,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    fit: BoxFit.fill,
                    image: NetworkImage(picture),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 6,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconTextRow(
                      icon: Ionicons.heart,
                      iconSize: iconSize,
                      text: "$likes Likes",
                      color: Colors.red,
                    ),
                    IconTextRow(
                      icon: Icons.messenger_outlined,
                      iconSize: iconSize,
                      text: "$noComments Comments",
                      color: Colors.grey,
                    ),
                    IconTextRow(
                      icon: Ionicons.share,
                      iconSize: iconSize,
                      text: "Share",
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
