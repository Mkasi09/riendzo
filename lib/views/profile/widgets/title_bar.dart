import 'package:flutter/material.dart';
import 'package:riendzo/views/home/home.dart';

import '../../../widgets/screen_sections.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (e) => const Home(),
              ),
            );
          },
          icon: const Icon(
            Icons.chevron_left_outlined,
            size: 35,
            weight: 900,
          ),
        ),
        Sections(
          sectionName: 'Profile',
          trailingText: '',
          veritcalMargin: 10,
        ),
        const SizedBox(
          height: 5,
          width: 5,
        ),
      ],
    );
  }
}
