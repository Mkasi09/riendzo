import 'package:flutter/material.dart';
import 'package:riendzo/widgets/trip_card.dart';

class ongoing_trips_settings extends StatelessWidget {
  const ongoing_trips_settings({super.key});

  @override
  Widget build(BuildContext context) {
    return TripCard(
      imageHeight: 200.0,
      radius: 10.0,
      country: "South Africa",
      location: "Graskop",
      startDate: "12 FEB",
      endDate: "14 FEB",
      imagesOfUsersBooked1:
          "https://images.pexels.com/photos/8974087/pexels-photo-8974087.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
      imagesOfUsersBooked2:
          "https://images.pexels.com/photos/8974087/pexels-photo-8974087.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
      imagesOfUsersBooked3:
          "https://images.pexels.com/photos/8974087/pexels-photo-8974087.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
      picture:
          "https://images.pexels.com/photos/8974087/pexels-photo-8974087.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
    );
  }
}
