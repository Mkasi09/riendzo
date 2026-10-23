import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  bool _tripUpdates = true;
  bool _socialUpdates = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _tripUpdates = data['tripUpdatesEnabled'] as bool? ?? true;
        _socialUpdates = data['socialUpdatesEnabled'] as bool? ?? true;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _saveSetting(String field, bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      field: value,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Trip updates'),
                        subtitle: const Text(
                          'Join requests, invitations, and trip changes',
                        ),
                        value: _tripUpdates,
                        onChanged: (value) {
                          setState(() => _tripUpdates = value);
                          _saveSetting('tripUpdatesEnabled', value);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Social updates'),
                        subtitle: const Text(
                          'Follows, likes, comments, and messages',
                        ),
                        value: _socialUpdates,
                        onChanged: (value) {
                          setState(() => _socialUpdates = value);
                          _saveSetting('socialUpdatesEnabled', value);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
