import 'package:flutter/material.dart';

class TripCard extends StatelessWidget {
  final double imageHeight;
  final double radius;
  final String picture;
  final String location;
  final String country;
  final String imagesOfUsersBooked1;
  final String imagesOfUsersBooked2;
  final String imagesOfUsersBooked3;
  final String startDate;
  final String endDate;

  const TripCard({
    super.key,
    required this.radius,
    required this.picture,
    required this.location,
    required this.country,
    required this.startDate,
    required this.endDate,
    required this.imagesOfUsersBooked1,
    required this.imagesOfUsersBooked2,
    required this.imagesOfUsersBooked3,
    required this.imageHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blueAccent,
      child: SizedBox(
        width: 200,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        location,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.blueAccent,
                            size: 15,
                          ),
                          Text(
                            country,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$startDate - $endDate",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      const Text(
                        "10 People Interest",
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
