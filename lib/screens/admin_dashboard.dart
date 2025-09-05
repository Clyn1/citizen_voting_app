import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _nameCtrl = TextEditingController();
  final _partyCtrl = TextEditingController();
  bool _checkedAdmin = false;
  bool _isAdmin = false;
  String? uid;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    uid = user?.uid;
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() {
      _isAdmin = doc.exists && (doc.data()?['isAdmin'] == true);
      _checkedAdmin = true;
    });
  }

  Future<void> _addCandidate() async {
    final name = _nameCtrl.text.trim();
    final party = _partyCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('candidates').add({
        'name': name,
        'party': party,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _nameCtrl.clear();
      _partyCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Candidate added')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedAdmin) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_isAdmin) ...[
              // Add candidate form
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Candidate name')),
              const SizedBox(height: 8),
              TextField(controller: _partyCtrl, decoration: const InputDecoration(labelText: 'Party (optional)')),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _addCandidate, child: const Text('Add Candidate')),
            ] else ...[
              const Text('You are not an admin. You can only view candidates.'),
            ],
            const SizedBox(height: 24),
            const Text('Current Candidates', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('candidates').orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text('Error: ${snapshot.error}');
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text('No candidates yet'));
                  return ListView(
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return ListTile(title: Text(data['name'] ?? ''), subtitle: Text(data['party'] ?? ''));
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}