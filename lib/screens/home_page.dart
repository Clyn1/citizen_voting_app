// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  String? _votedCandidateId;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _tabController = TabController(length: 3, vsync: this);
    _initUserState();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _initUserState() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isAdmin = false;
        _loadingAdmin = false;
      });
      return;
    }

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final isAdmin = userDoc.exists && (userDoc.data()?['isAdmin'] == true);

      final voteDoc = await _db.collection('user_votes').doc(user.uid).get();
      final hasVoted = voteDoc.exists;
      final votedCandidateId = hasVoted ? (voteDoc.data()?['candidateId'] as String?) : null;

      setState(() {
        _isAdmin = isAdmin;
        _loadingAdmin = false;
        _hasVoted = hasVoted;
        _votedCandidateId = votedCandidateId;
      });
    } catch (e) {
      setState(() {
        _isAdmin = false;
        _loadingAdmin = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading user state: $e')),
        );
      }
    }
  }

  Future<void> _castVote(String candidateId, String candidateName) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to vote')),
      );
      return;
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Vote'),
        content: Text('Are you sure you want to vote for $candidateName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Vote'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final userVoteRef = _db.collection('user_votes').doc(user.uid);
    final candidateRef = _db.collection('candidates').doc(candidateId);

    try {
      await _db.runTransaction((tx) async {
        final userVoteSnap = await tx.get(userVoteRef);
        if (userVoteSnap.exists) {
          throw 'You have already voted.';
        }

        final candidateSnap = await tx.get(candidateRef);
        if (!candidateSnap.exists) {
          throw 'Candidate not found.';
        }

        final currentVotes = (candidateSnap.data()?['votes'] ?? 0) as int;

        tx.set(userVoteRef, {
          'candidateId': candidateId,
          'candidateName': candidateName,
          'timestamp': FieldValue.serverTimestamp(),
          'userEmail': user.email,
        });

        tx.update(candidateRef, {
          'votes': currentVotes + 1,
        });
      });

      setState(() {
        _hasVoted = true;
        _votedCandidateId = candidateId;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vote for $candidateName submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vote failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCandidate(String candidateId, String candidateName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Candidate'),
        content: Text('Are you sure you want to delete $candidateName? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _db.collection('candidates').doc(candidateId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$candidateName deleted successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddCandidateDialog() async {
    final nameCtrl = TextEditingController();
    final partyCtrl = TextEditingController();
    final photoCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Candidate'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: partyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Political Party',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.groups),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: photoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Photo URL',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.image),
                    hintText: 'https://example.com/photo.jpg',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Add Candidate'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name is required')),
        );
      }
      return;
    }

    final data = {
      'name': name,
      'party': partyCtrl.text.trim().isEmpty ? 'Independent' : partyCtrl.text.trim(),
      'photoUrl': photoCtrl.text.trim(),
      'votes': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _user?.email ?? 'admin',
    };

    try {
      await _db.collection('candidates').add(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add candidate: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    nameCtrl.dispose();
    partyCtrl.dispose();
    photoCtrl.dispose();
  }

  Future<void> _editCandidate(String candidateId, Map<String, dynamic> currentData) async {
    final nameCtrl = TextEditingController(text: currentData['name'] ?? '');
    final partyCtrl = TextEditingController(text: currentData['party'] ?? '');
    final photoCtrl = TextEditingController(text: currentData['photoUrl'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Candidate'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: partyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Political Party',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.groups),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: photoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Photo URL',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.image),
                    hintText: 'https://example.com/photo.jpg',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name is required')),
        );
      }
      return;
    }

    try {
      await _db.collection('candidates').doc(candidateId).update({
        'name': name,
        'party': partyCtrl.text.trim().isEmpty ? 'Independent' : partyCtrl.text.trim(),
        'photoUrl': photoCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    nameCtrl.dispose();
    partyCtrl.dispose();
    photoCtrl.dispose();
  }

  // Enhanced method to reset a user's vote (admin-only feature)
  Future<void> _resetUserVote(String userId, String userEmail) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset User Vote'),
        content: Text('Are you sure you want to reset the vote for $userEmail? This will allow them to vote again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset Vote'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Get the user's vote to decrement the candidate's vote count
      final userVoteDoc = await _db.collection('user_votes').doc(userId).get();
      if (userVoteDoc.exists) {
        final candidateId = userVoteDoc.data()?['candidateId'];
        if (candidateId != null) {
          // Decrement the candidate's vote count
          final candidateRef = _db.collection('candidates').doc(candidateId);
          await _db.runTransaction((tx) async {
            final candidateSnap = await tx.get(candidateRef);
            if (candidateSnap.exists) {
              final currentVotes = (candidateSnap.data()?['votes'] ?? 0) as int;
              tx.update(candidateRef, {
                'votes': (currentVotes - 1).clamp(0, double.infinity).toInt(),
              });
            }
          });
        }
        
        // Delete the user's vote record
        await _db.collection('user_votes').doc(userId).delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vote reset successfully for $userEmail'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset vote: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCandidateCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final id = doc.id;
    final name = (data['name'] ?? 'Unknown') as String;
    final party = (data['party'] ?? 'Independent') as String;
    final photoUrl = (data['photoUrl'] ?? '') as String;
    final votes = (data['votes'] ?? 0) as int;

    final isVotedCandidate = _hasVoted && _votedCandidateId == id;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isVotedCandidate 
            ? LinearGradient(colors: [Colors.green.shade50, Colors.green.shade100])
            : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Candidate Photo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isVotedCandidate ? Colors.green : Colors.grey.shade300,
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 37,
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty
                    ? Text(
                        name.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase(),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      )
                    : null,
                ),
              ),
              const SizedBox(width: 16),
              
              // Candidate Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Party: $party',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$votes votes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Action Buttons
              Column(
                children: [
                  // Vote Button
                  if (!_hasVoted)
                    ElevatedButton.icon(
                      onPressed: () => _castVote(id, name),
                      icon: const Icon(Icons.how_to_vote, size: 16),
                      label: const Text('Vote'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    )
                  else if (isVotedCandidate)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('Voted', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Vote Cast',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  
                  // Admin Buttons
                  if (_isAdmin) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _editCandidate(id, data),
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit Candidate',
                          color: Colors.orange,
                        ),
                        IconButton(
                          onPressed: () => _deleteCandidate(id, name),
                          icon: const Icon(Icons.delete),
                          tooltip: 'Delete Candidate',
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVotingTab() {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade800],
            ),
          ),
          child: Column(
            children: [
              const Text(
                'National Election 2027',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _hasVoted 
                  ? 'Thank you for voting! Your vote has been recorded.'
                  : 'Choose your preferred candidate below',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              // Admin indicator in voting tab
              if (_isAdmin) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    'Admin Mode: You can edit/delete candidates',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Quick Actions for Admin (in voting tab)
        if (_isAdmin) ...[
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings, color: Colors.orange),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Admin Quick Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddCandidateDialog,
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Add Candidate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // Candidates List
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _db.collection('candidates').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No candidates available yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      if (_isAdmin) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showAddCandidateDialog,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add First Candidate'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) => _buildCandidateCard(docs[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('candidates').orderBy('votes', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No voting results available yet'),
          );
        }

        final docs = snapshot.data!.docs;
        final totalVotes = docs.fold(0, (sum, doc) => sum + ((doc.data()['votes'] ?? 0) as int));

        return Column(
          children: [
            // Results Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade600, Colors.green.shade800],
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Election Results',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Votes Cast: $totalVotes',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  // Admin indicator
                  if (_isAdmin) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Text(
                        'Admin View: Real-time results',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Results List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final name = data['name'] ?? 'Unknown';
                  final party = data['party'] ?? 'Independent';
                  final votes = data['votes'] ?? 0;
                  final photoUrl = data['photoUrl'] ?? '';
                  final percentage = totalVotes > 0 ? (votes / totalVotes * 100) : 0.0;

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Rank
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: index == 0 ? const Color(0xFFFFD700) : Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: index == 0 ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          // Photo
                          CircleAvatar(
                            radius: 25,
                            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                            child: photoUrl.isEmpty
                              ? Text(
                                  name.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase(),
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                          ),
                          const SizedBox(width: 16),
                          
                          // Candidate Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  party,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Progress Bar
                                LinearProgressIndicator(
                                  value: percentage / 100,
                                  backgroundColor: Colors.grey.shade200,
                                  color: Colors.blue,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          // Vote Count and Percentage
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$votes',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

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

    return Column(
      children: [
        // Admin Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade600, Colors.purple.shade800],
            ),
          ),
          child: Column(
            children: [
              const Text(
                'Admin Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage candidates, users, and election settings',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        
        // Admin Stats Section
        Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('candidates').snapshots(),
            builder: (context, candidateSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: _db.collection('user_votes').snapshots(),
                builder: (context, votesSnapshot) {
                  final candidateCount = candidateSnapshot.hasData ? candidateSnapshot.data!.docs.length : 0;
                  final totalVotes = votesSnapshot.hasData ? votesSnapshot.data!.docs.length : 0;
                  
                  return Row(
                    children: [
                      Expanded(
                        child: Card(
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Icon(Icons.people, size: 32, color: Colors.blue.shade700),
                                const SizedBox(height: 8),
                                Text(
                                  '$candidateCount',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                const Text('Candidates'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Card(
                          color: Colors.green.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Icon(Icons.how_to_vote, size: 32, color: Colors.green.shade700),
                                const SizedBox(height: 8),
                                Text(
                                  '$totalVotes',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                const Text('Total Votes'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        
        // Action Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showAddCandidateDialog,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add New Candidate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('User Vote Management'),
                        content: const Text('View and manage user votes'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showUserVotesDialog();
                            },
                            child: const Text('View Votes'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.manage_accounts),
                  label: const Text('Manage User Votes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Candidate Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        // Candidates Management List
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _db.collection('candidates').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('No candidates to manage'),
                );
              }

              final docs = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final name = data['name'] ?? 'Unknown';
                  final party = data['party'] ?? 'Independent';
                  final votes = data['votes'] ?? 0;
                  final photoUrl = data['photoUrl'] ?? '';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: photoUrl.isEmpty
                          ? Text(name.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase())
                          : null,
                      ),
                      title: Text(name),
                      subtitle: Text('$party • $votes votes'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _editCandidate(doc.id, data),
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            onPressed: () => _deleteCandidate(doc.id, name),
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // New method to show user votes management dialog
  void _showUserVotesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          width: 600,
          height: 500,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'User Votes Management',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _db.collection('user_votes').orderBy('timestamp', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('No votes cast yet'),
                      );
                    }

                    final docs = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final userEmail = data['userEmail'] ?? 'Unknown';
                        final candidateName = data['candidateName'] ?? 'Unknown';
                        final timestamp = data['timestamp']?.toDate();

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(userEmail),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Voted for: $candidateName'),
                                if (timestamp != null)
                                  Text(
                                    'Time: ${timestamp.toString().substring(0, 19)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              onPressed: () => _resetUserVote(doc.id, userEmail),
                              icon: const Icon(Icons.refresh, color: Colors.orange),
                              tooltip: 'Reset Vote',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
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
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
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
          // User Info
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
          // Admin Badge
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
          // Logout Button
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
            Tab(
              icon: Icon(Icons.how_to_vote),
              text: 'Vote',
            ),
            Tab(
              icon: Icon(Icons.bar_chart),
              text: 'Results',
            ),
            Tab(
              icon: Icon(Icons.admin_panel_settings),
              text: 'Admin',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVotingTab(),
          _buildResultsTab(),
          _buildAdminTab(),
        ],
      ),
      // Enhanced Status Bar
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
                const Icon(Icons.admin_panel_settings, color: Colors.orange, size: 16),
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
    );
  }
}

// Extension for Colors.gold
extension CustomColors on Colors {
  static const Color gold = Color(0xFFFFD700);
}