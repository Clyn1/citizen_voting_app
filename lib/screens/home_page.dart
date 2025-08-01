// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'vote_page.dart';
import 'results_page.dart';
import 'profile_page.dart';
import '../config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late final bool isAdmin;

  final List<Widget> _pages = [
    const VotePage(),
    // placeholder for results/profile; we'll build list dynamically
  ];

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    isAdmin = uid != null && adminUids.contains(uid);
    // insert ResultsPage only for admins
    if (isAdmin) {
      _pages.insert(1, const ResultsPage());
    }
    _pages.add(const ProfilePage());
  }

  @override
  Widget build(BuildContext context) {
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(icon: Icon(Icons.how_to_vote), label: 'Vote'),
      if (isAdmin)
        const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Results'),
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _currentIndex, children: _pages)),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: items,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
