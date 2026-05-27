import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../views/my_trips/booking/widgets/custom_button.dart';

class FriendsSelectionPage extends StatefulWidget {
  const FriendsSelectionPage({super.key});

  @override
  State<FriendsSelectionPage> createState() => _FriendsSelectionPageState();
}

class _FriendsSelectionPageState extends State<FriendsSelectionPage> {
  final Map<String, bool> _selectedFriends = {};

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Select Friends')),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('users').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = _usersFromSnapshot(snapshot.data, currentUserId);

          if (users.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No friends are available yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: users.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final id = user['id']!;
                    final isSelected = _selectedFriends[id] ?? false;

                    return CheckboxListTile(
                      value: isSelected,
                      secondary: CircleAvatar(
                        backgroundImage:
                            (user['profilePicture'] ?? '').isNotEmpty
                            ? NetworkImage(user['profilePicture']!)
                            : null,
                        child: (user['profilePicture'] ?? '').isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(
                        user['name'] ?? 'Unknown user',
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        user['email'] ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedFriends[id] = value ?? false;
                        });
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    horizontalPadding: 10,
                    cardColor: Colors.blueAccent,
                    onPressed: () {
                      final selected = users
                          .where((user) => _selectedFriends[user['id']] == true)
                          .toList();
                      Navigator.pop(context, selected);
                    },
                    text: "Invite",
                    textColor: Colors.white,
                    TextSize: 16,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Map<String, String>> _usersFromSnapshot(
    DatabaseEvent? event,
    String? currentUserId,
  ) {
    final value = event?.snapshot.value;
    if (value is! Map) return [];

    return value.entries
        .where((entry) => entry.key != currentUserId && entry.value is Map)
        .map((entry) {
          final data = Map<dynamic, dynamic>.from(entry.value as Map);
          return {
            'id': entry.key.toString(),
            'name': (data['name'] ?? 'Unknown user').toString(),
            'email': (data['email'] ?? '').toString(),
            'profilePicture': (data['profilePicture'] ?? '').toString(),
          };
        })
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
  }
}
