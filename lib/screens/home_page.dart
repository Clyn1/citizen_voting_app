// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'results_page.dart';
import 'profile_page.dart';
import 'vote_page.dart';
import 'admin_dashboard.dart'; // Add this import
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
            icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
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

            // Pages depending on voting status and admin role
            final pages = <Widget>[
              // Vote Tab
              votingOpen
                  ? const VotePage()
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            now.isBefore(startTime) ? Icons.schedule : Icons.how_to_vote_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            now.isBefore(startTime)
                                ? 'Voting has not started yet'
                                : 'Voting has ended',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            now.isBefore(startTime)
                                ? 'Starts: ${_formatDateTime(startTime)}'
                                : 'Ended: ${_formatDateTime(endTime)}',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                          if (isAdmin && now.isBefore(startTime)) ...[
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => setState(() => _currentIndex = 1), // Switch to admin tab
                              icon: const Icon(Icons.settings),
                              label: const Text('Manage Election'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
              
              // Admin Dashboard Tab (only if admin)
              if (isAdmin) const AdminDashboard(),
              
              // Results Tab (only if admin)
              if (isAdmin) const ResultsPage(),
              
              // Profile Tab
              const ProfilePage(),
            ];

            return Column(
              children: [
                // Election title + status bar with enhanced styling
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.deepPurple.shade200, Colors.deepPurple.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              election['title'] ?? 'Election',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ),
                          // Status indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: votingOpen ? Colors.green : (now.isBefore(startTime) ? Colors.orange : Colors.red),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              votingOpen ? 'ACTIVE' : (now.isBefore(startTime) ? 'SCHEDULED' : 'ENDED'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            votingOpen ? Icons.access_time : (now.isBefore(startTime) ? Icons.schedule : Icons.event_busy),
                            size: 16,
                            color: Colors.deepPurple[700],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              votingOpen
                                  ? 'Voting closes: ${_formatDateTime(endTime)}'
                                  : now.isBefore(startTime)
                                      ? 'Voting starts: ${_formatDateTime(startTime)}'
                                      : 'Voting ended: ${_formatDateTime(endTime)}',
                              style: TextStyle(fontSize: 14, color: Colors.deepPurple[700]),
                            ),
                          ),
                        ],
                      ),
                      // Admin quick actions
                      if (isAdmin && votingOpen) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => setState(() => _currentIndex = 1), // Switch to admin tab
                                icon: const Icon(Icons.dashboard, size: 16),
                                label: const Text('Admin Panel', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple[600],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => setState(() => _currentIndex = 2), // Switch to results tab
                                icon: const Icon(Icons.analytics, size: 16),
                                label: const Text('Live Results', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[600],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
            type: BottomNavigationBarType.fixed, // Important for 4+ tabs
            backgroundColor: Colors.white,
            elevation: 8,
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}, '
           '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}