// lib/screens/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ Use package imports (ensures AdminDashboard is found)
import 'package:citizen_voting_app/screens/results_page.dart';
import 'package:citizen_voting_app/screens/profile_page.dart';
import 'package:citizen_voting_app/screens/vote_page.dart';
import 'package:citizen_voting_app/screens/admin_dashboard.dart';

import '../config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final bool isAdmin;
  StreamSubscription<DocumentSnapshot>? _electionSubscription;
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
    // Add your election listener setup here
    // Example:
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

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Text(message),
    );
  }

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
                ? 'Voting starts: ${startTime.toString()}'
                : 'Voting ended: ${endTime.toString()}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildElectionHeader(Map<String, dynamic> election, bool votingOpen, 
      DateTime startTime, DateTime endTime, DateTime now) {
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            votingOpen ? 'ACTIVE' : (now.isBefore(startTime) ? 'UPCOMING' : 'ENDED'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  List<BottomNavigationBarItem> _buildBottomNavItems() {
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.how_to_vote),
        label: 'Vote',
      ),
    ];

    if (isAdmin) {
      items.addAll([
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart),
          label: 'Results',
        ),
      ]);
    }

    items.add(
      const BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Profile',
      ),
    );

    return items;
  }

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _currentElectionData == null
            ? _buildLoadingState()
            : !_currentElectionData!.exists
                ? _buildErrorState('No election data found')
                : Builder(
                    builder: (context) {
                      try {
                        final election = _currentElectionData!.data()!;
                        final startTime = (election['startTime'] as Timestamp).toDate();
                        final endTime = (election['endTime'] as Timestamp).toDate();
                        final now = DateTime.now();

                        final votingOpen = now.isAfter(startTime) && now.isBefore(endTime);

                        // ✅ Corrected pages list construction
                        final pages = <Widget>[
                          // Vote Tab
                          votingOpen
                              ? const VotePage()
                              : _buildVotingClosedState(startTime, endTime, now),

                          // Admin Dashboard Tab (only if admin)
                          if (isAdmin) const AdminDashboard(),

                          // Results Tab (only if admin)
                          if (isAdmin) const ResultsPage(),

                          // Profile Tab
                          const ProfilePage(),
                        ];

                        return Column(
                          children: [
                            _buildElectionHeader(election, votingOpen, startTime, endTime, now),
                            Expanded(
                              child: IndexedStack(
                                index: _currentIndex,
                                children: pages,
                              ),
                            ),
                          ],
                        );
                      } catch (e) {
                        return _buildErrorState('Error loading election data: $e');
                      }
                    },
                  ),
      ),
      bottomNavigationBar: _currentElectionData?.exists == true
          ? BottomNavigationBar(
              currentIndex: _currentIndex,
              items: _buildBottomNavItems(),
              onTap: _navigateToTab,
              selectedItemColor: Colors.deepPurple,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 8,
            )
          : null,
    );
  }
}