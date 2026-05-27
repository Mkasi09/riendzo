import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:riendzo/views/profile/widgets/stats_label.dart';

class ProfileSummary extends StatefulWidget {
  const ProfileSummary({super.key});

  @override
  State<ProfileSummary> createState() => _ProfileSummaryState();
}

class _ProfileSummaryState extends State<ProfileSummary> {
  int tripLikes = 0;

  @override
  void initState() {
    super.initState();
    _getTripLikes();
  }

  Future<void> _getTripLikes() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final tripsSnapshot = await FirebaseFirestore.instance
        .collection('trips')
        .where('userId', isEqualTo: currentUser.uid)
        .get();

    var totalTripLikes = 0;
    for (final tripDoc in tripsSnapshot.docs) {
      final likesSnapshot = await tripDoc.reference.collection('likes').get();
      totalTripLikes += likesSnapshot.size;
    }

    if (!mounted) return;
    setState(() => tripLikes = totalTripLikes);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(
              "Life is short and the world is wide.",
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ProfileStatsLabel(
                  dataLabel: 'Likes',
                  dataValue: tripLikes.toString(),
                ),
                const ProfileStatsLabel(dataLabel: 'Followers', dataValue: '0'),
                const ProfileStatsLabel(dataLabel: 'Following', dataValue: '0'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
