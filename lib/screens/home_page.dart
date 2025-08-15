// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'results_page.dart';
import 'profile_page.dart';
import 'vote_page.dart';
import '../config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late final bool isAdmin;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    isAdmin = uid != null && adminUids.contains(uid);
  }

  List<BottomNavigationBarItem> _buildBottomNavItems() {
    return [
      const BottomNavigationBarItem(
          icon: Icon(Icons.how_to_vote), label: 'Vote'),
      if (isAdmin)
        const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart), label: 'Results'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.person), label: 'Profile'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('elections')
              .doc('current') // make sure your election doc id is 'current'
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('No election data found'));
            }

            final election = snapshot.data!.data()!;
            final startTime = (election['startTime'] as Timestamp).toDate();
            final endTime = (election['endTime'] as Timestamp).toDate();
            final now = DateTime.now();

            final votingOpen = now.isAfter(startTime) && now.isBefore(endTime);

            // Pages depending on voting status
            final pages = <Widget>[
              votingOpen
                  ? const VotePage()
                  : Center(
                      child: Text(
                        now.isBefore(startTime)
                            ? 'Voting has not started yet'
                            : 'Voting has ended',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
              if (isAdmin) const ResultsPage(),
              const ProfilePage(),
            ];

            return Column(
              children: [
                // Election title + status bar
                Container(
                  width: double.infinity,
                  color: Colors.deepPurple.shade100,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        election['title'] ?? 'Election',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        votingOpen
                            ? 'Voting is OPEN until ${endTime.toLocal()}'
                            : now.isBefore(startTime)
                                ? 'Voting starts at ${startTime.toLocal()}'
                                : 'Voting ended at ${endTime.toLocal()}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),

                // Expanded page content
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: pages,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('elections')
            .doc('current')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();

          return BottomNavigationBar(
            currentIndex: _currentIndex,
            items: _buildBottomNavItems(),
            onTap: (i) => setState(() => _currentIndex = i),
            selectedItemColor: Colors.deepPurple,
            unselectedItemColor: Colors.grey,
          );
        },
      ),
    );
  }
}
