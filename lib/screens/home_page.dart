import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Use your project package name
import 'package:citizen_voting_app_new/screens/results_page.dart';
import 'package:citizen_voting_app_new/screens/profile_page.dart';
import 'package:citizen_voting_app_new/screens/vote_page.dart';
import 'package:citizen_voting_app_new/screens/admin_dashboard.dart';

import '../config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool isAdmin = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _electionSubscription;
  DocumentSnapshot<Map<String, dynamic>>? _currentElectionData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeUser();
    _setupElectionListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _electionSubscription?.cancel();
    super.dispose();
  }

  void _initializeUser() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    isAdmin = uid != null && adminUids.contains(uid);
  }

  void _setupElectionListener() {
    _electionSubscription = FirebaseFirestore.instance
        .collection('elections')
        .doc('your_election_id') // Replace with actual election ID
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _currentElectionData = snapshot;
      });
    });
  }

  Widget _buildLoadingState() => const Center(child: CircularProgressIndicator());

  Widget _buildErrorState(String message) => Center(child: Text(message));

  Widget _buildVotingClosedState(DateTime startTime, DateTime endTime, DateTime now) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.how_to_vote, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            now.isBefore(startTime) ? 'Voting has not started yet' : 'Voting has ended',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            now.isBefore(startTime)
                ? 'Voting starts: ${startTime.toLocal()}'
                : 'Voting ended: ${endTime.toLocal()}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildElectionHeader(
      Map<String, dynamic> election, bool votingOpen, DateTime startTime, DateTime endTime, DateTime now) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: votingOpen ? Colors.green : Colors.red,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          Text(
            election['title'] ?? 'Election',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            votingOpen ? 'ACTIVE' : (now.isBefore(startTime) ? 'UPCOMING' : 'ENDED'),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  List<BottomNavigationBarItem> _buildBottomNavItems() {
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(icon: Icon(Icons.how_to_vote), label: 'Vote'),
    ];
    if (isAdmin) {
      items.addAll([
        const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
        const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Results'),
      ]);
    }
    items.add(const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'));
    return items;
  }

  void _navigateToTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    if (_currentElectionData == null) return Scaffold(body: _buildLoadingState());
    if (!_currentElectionData!.exists) return Scaffold(body: _buildErrorState('No election data found'));

    try {
      final election = _currentElectionData!.data()!;
      final startTime = (election['startTime'] as Timestamp).toDate();
      final endTime = (election['endTime'] as Timestamp).toDate();
      final now = DateTime.now();
      final votingOpen = now.isAfter(startTime) && now.isBefore(endTime);

      final pages = <Widget>[
        votingOpen ? const VotePage() : _buildVotingClosedState(startTime, endTime, now),
        if (isAdmin) const AdminDashboard(),
        if (isAdmin) const ResultsPage(),
        const ProfilePage(),
      ];

      return Scaffold(
        body: Column(
          children: [
            _buildElectionHeader(election, votingOpen, startTime, endTime, now),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: pages),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          items: _buildBottomNavItems(),
          onTap: _navigateToTab,
          selectedItemColor: Colors.deepPurple,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
      );
    } catch (e) {
      return Scaffold(body: _buildErrorState('Error loading election data: $e'));
    }
  }
}
