import 'package:flutter/material.dart';

class BookingHeader extends StatelessWidget {
  final String text;
  final Color color;

  const BookingHeader({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(margin: EdgeInsets.only(top: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back_ios,
              color: color,
            ),
          ),
          Text(
            text,
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: color,
                fontSize: 20),
          ),
          const SizedBox(
            width: 30,
          )
        ],
      ),
    );
  }
}
