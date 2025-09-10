import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chatbot_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? _user;
  bool _isAdmin = false;
  bool _hasVoted = false;
  bool _loadingAdmin = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    setState(() {
      _user = user;
    });

    if (user != null) {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _isAdmin = doc['isAdmin'] ?? false;
        });
      }
      final voteDoc = await _db.collection('user_votes').doc(user.uid).get();
      setState(() {
        _hasVoted = voteDoc.exists;
      });
    }

    setState(() {
      _loadingAdmin = false;
    });
  }

  // ---------------- Voting Tab ----------------
  Widget _buildVotingTab() {
    return const Center(child: Text("Voting Tab UI here..."));
  }

  // ---------------- Results Tab ----------------
  Widget _buildResultsTab() {
    return const Center(child: Text("Results Tab UI here..."));
  }

  // ---------------- Admin Tab ----------------
  Widget _buildAdminTab() {
    if (!_isAdmin) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.admin_panel_settings, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Admin Access Required',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'You need admin privileges to access this section',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Admin UI here (from your original code)
    return const Center(child: Text("Admin Dashboard UI here..."));
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingAdmin) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Citizen Voting App',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                _user?.email?.split('@')[0] ?? 'Guest',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (_isAdmin)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'ADMIN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          IconButton(
            onPressed: () async {
              await _auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.how_to_vote), text: 'Vote'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Results'),
            Tab(icon: Icon(Icons.admin_panel_settings), text: 'Admin'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildVotingTab(), _buildResultsTab(), _buildAdminTab()],
      ),
      bottomNavigationBar: Container(
        height: 50,
        color: Colors.grey.shade100,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _hasVoted ? Icons.check_circle : Icons.circle_outlined,
                color: _hasVoted ? Colors.green : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _hasVoted ? 'You have voted' : 'Vote not cast yet',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _hasVoted ? Colors.green : Colors.grey.shade600,
                ),
              ),
              if (_isAdmin) ...[
                const SizedBox(width: 16),
                const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Admin Mode',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatbotPage()),
          );
        },
        child: const Icon(Icons.chat),
      ),
    );
  }
}

// Extension for Colors.gold
extension CustomColors on Colors {
  static const Color gold = Color(0xFFFFD700);
}
