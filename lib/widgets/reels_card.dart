import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

class ReelsCard extends StatelessWidget {
  const ReelsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: MediaQuery.of(context).size.width * 1,
                height: MediaQuery.of(context).size.height * 1,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(
                      'https://images.pexels.com/photos/1179156/pexels-photo-1179156.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
                child: const SizedBox(),
              ),
              Positioned(
                width: MediaQuery.of(context).size.width * .90,
                top: 55,
                left: 15,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          backgroundImage: AssetImage(
                              "assets/images/profile/profile_pic.jpg"),
                          radius: 20,
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5,
                          ),
                          child: Text(
                            "Eddie Mkansi",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "2m ago",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Positioned(
                right: 10,
                bottom: 150,
                child: Column(
                  children: [
                    Column(
                      children: [
                        Icon(
                          Icons.thumb_up_alt_outlined,
                          color: Colors.white,
                          size: 35,
                        ),
                        Text(
                          "36.3K",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Icon(
                          Ionicons.heart_outline,
                          color: Colors.white,
                          size: 35,
                        ),
                        Text(
                          "5.3K",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          color: Colors.white,
                          size: 35,
                        ),
                        Text(
                          "36.3K",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 20,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * .92,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(
                              right: 3,
                            ),
                            child: const Icon(
                              Icons.location_on,
                              size: 17,
                              color: Colors.blue,
                            ),
                          ),
                          const Text(
                            "San Francisco",
                            style: TextStyle(
                              fontSize: 17,
                              color: Colors.white,
                            ),
                          )
                        ],
                      ),
                      const Row(
                        children: [
                          Icon(
                            Ionicons.share_social_outline,
                            color: Colors.white,
                            size: 25,
                          ),
                          SizedBox(
                            width: 15,
                          ),
                          Icon(
                            Ionicons.bookmark_outline,
                            color: Colors.white,
                            size: 25,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }
}
