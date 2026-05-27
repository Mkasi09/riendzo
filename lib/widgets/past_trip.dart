import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:riendzo/widgets/custom_icon.dart';
import 'package:riendzo/widgets/liked_users_stacked_avatars.dart';

class PastTripCard extends StatelessWidget {
  final String image1;
  final String image2;
  final String image3;
  final String image4;
  final String location;
  final String year;
  final String country;
  final String price;
  final String noOfDays;
  final String imagesOfUsersBooked1;
  final String imagesOfUsersBooked2;
  final String imagesOfUsersBooked3;
  final String imagesOfUsersLiked1;
  final String imagesOfUsersLiked2;
  final String imagesOfUsersLiked3;
  final String topUserLiked;
  final String noOfLikes;

  const PastTripCard({
    super.key,
    required this.image1,
    required this.image2,
    required this.image3,
    required this.image4,
    required this.location,
    required this.year,
    required this.country,
    required this.price,
    required this.noOfDays,
    required this.imagesOfUsersBooked1,
    required this.imagesOfUsersBooked2,
    required this.imagesOfUsersBooked3,
    required this.imagesOfUsersLiked1,
    required this.imagesOfUsersLiked2,
    required this.imagesOfUsersLiked3,
    required this.topUserLiked,
    required this.noOfLikes,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 205,
                width: 145,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(5),
                    bottomLeft: Radius.circular(5),
                  ),
                  image: DecorationImage(
                    fit: BoxFit.fill,
                    image: NetworkImage(image1),
                  ),
                ),
              ),
              Column(
                children: [
                  Container(
                    height: 110,
                    width: 185,
                    margin: const EdgeInsets.only(left: 3, bottom: 3),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(5),
                      ),
                      image: DecorationImage(
                        fit: BoxFit.fill,
                        image: NetworkImage(image2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        height: 90,
                        width: 90,
                        margin: const EdgeInsets.only(left: 3, top: 3),
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            fit: BoxFit.fill,
                            image: NetworkImage(image3),
                          ),
                        ),
                      ),
                      Container(
                        height: 90,
                        width: 90,
                        margin: const EdgeInsets.only(left: 6, top: 3),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(5),
                          ),
                          image: DecorationImage(
                            fit: BoxFit.fill,
                            image: NetworkImage(image4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.all(10),
            width: 310,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "In $location , $year",
                      style: const TextStyle(fontSize: 15),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.blueAccent,
                          size: 15,
                        ),
                        Text(country, style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                  ],
                ),
                Container(
                  color: Colors.grey,
                  height: 1,
                  width: 300,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                ),
                Row(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CustomIcon(
                              color: Colors.grey,
                              icon: Ionicons.heart_outline,
                            ),
                            CustomIcon(
                              color: Colors.grey,
                              icon: Icons.comment_outlined,
                            ),
                            CustomIcon(
                              color: Colors.grey,
                              icon: Icons.send_outlined,
                            ),
                          ],
                        ),
                        Text(
                          topUserLiked,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Text('and '),
                        Text(
                          noOfLikes,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Text(' others'),
                        StackedAvatars(
                          usersLikedAvatar1:
                              "https://images.pexels.com/photos/5615665/pexels-photo-5615665.jpeg?auto=compress&cs=tinysrgb&w=1600",
                          usersLikedAvatar2:
                              "https://images.pexels.com/photos/7275385/pexels-photo-7275385.jpeg?auto=compress&cs=tinysrgb&w=1600",
                          usersLikedAvatar3:
                              "https://images.pexels.com/photos/5792641/pexels-photo-5792641.jpeg?auto=compress&cs=tinysrgb&w=1600",
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
