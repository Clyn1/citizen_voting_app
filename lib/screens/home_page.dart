import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_dashboard.dart'; // Import your actual AdminDashboard widget

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? _user;
  bool _isAdmin = false;
  bool _loadingAdmin = true;
  bool _hasVoted = false;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    // Initialize with 2 tabs first, will recreate after admin check
    _tabController = TabController(length: 2, vsync: this);
    _initUserState();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _initUserState() async {
    if (_user != null) {
      await _checkAdminStatus();
      await _checkVotingStatus();
    }
    if (mounted) {
      setState(() {
        _loadingAdmin = false;
      });
    }
  }

  Future<void> _checkAdminStatus() async {
    try {
      if (_user != null) {
        DocumentSnapshot userDoc = await _db.collection('users').doc(_user!.uid).get();
        if (userDoc.exists && mounted) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          bool wasAdmin = _isAdmin;
          bool newIsAdmin = userData['isAdmin'] == true;
          
          setState(() {
            _isAdmin = newIsAdmin;
          });
          
          // Recreate TabController if admin status changed
          if (wasAdmin != newIsAdmin) {
            _tabController?.dispose();
            _tabController = TabController(
              length: _isAdmin ? 3 : 2,
              vsync: this,
            );
          }
          
          debugPrint('Admin status checked: $_isAdmin'); // Debug log
        }
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      if (mounted) {
        setState(() {
          _isAdmin = false; // Default to false on error
        });
        // Ensure TabController is set for non-admin
        _tabController?.dispose();
        _tabController = TabController(length: 2, vsync: this);
      }
    }
  }

  Future<void> _checkVotingStatus() async {
    try {
      if (_user != null) {
        DocumentSnapshot voteDoc = await _db.collection('user_votes').doc(_user!.uid).get();
        if (voteDoc.exists && mounted) {
          setState(() {
            _hasVoted = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking voting status: $e');
    }
  }

  // Method to handle user logout
  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while checking admin status
    if (_loadingAdmin) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If user is not authenticated, redirect to login
    if (_user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Main UI logic
    return Scaffold(
      appBar: AppBar(
        title: const Text('Citizen Voting App'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Show admin indicator if user is admin
          if (_isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'ADMIN',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: _isAdmin ? [
            const Tab(icon: Icon(Icons.how_to_vote), text: 'Vote'),
            const Tab(icon: Icon(Icons.bar_chart), text: 'Results'),
            const Tab(icon: Icon(Icons.admin_panel_settings), text: 'Admin'),
          ] : [
            const Tab(icon: Icon(Icons.how_to_vote), text: 'Vote'),
            const Tab(icon: Icon(Icons.bar_chart), text: 'Results'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _isAdmin ? [
          // Vote Tab - Always show for authenticated users
          _buildVoteTab(),
          // Results Tab
          _buildResultsTab(),
          // Admin Tab - Only show if user is admin
          _buildAdminTab(),
        ] : [
          // Vote Tab - Always show for authenticated users
          _buildVoteTab(),
          // Results Tab
          _buildResultsTab(),
        ],
      ),
    );
  }

  Widget _buildVoteTab() {
    if (_hasVoted) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Thank you for voting!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Your vote has been recorded.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Replace this with your actual voting interface widget
    return const Center(
      child: Text(
        'Your Voting Interface Goes Here',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildResultsTab() {
    // Replace this with your actual results widget
    return const Center(
      child: Text(
        'Your Results Page Goes Here',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildAdminTab() {
    // Use your actual AdminDashboard widget here
    return const AdminDashboard();
  }
}
