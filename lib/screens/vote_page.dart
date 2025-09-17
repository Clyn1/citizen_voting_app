// lib/screens/vote_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VotePage extends StatefulWidget {
  const VotePage({super.key});

  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  String? _selectedCandidateId;
  bool _hasVoted = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkIfVoted();
  }

  Future<void> _checkIfVoted() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_votes')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        setState(() {
          _hasVoted = true;
          _selectedCandidateId = doc.data()?['candidateId'];
        });
      }
    } catch (e) {
      debugPrint('Error checking vote status: $e');
    }
  }

  Future<void> _castVote() async {
    if (_selectedCandidateId == null) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      // Use a transaction to ensure data consistency
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Check if user has already voted
        final userVoteRef = FirebaseFirestore.instance
            .collection('user_votes')
            .doc(user.uid);
        
        final userVoteDoc = await transaction.get(userVoteRef);
        
        if (userVoteDoc.exists) {
          throw Exception('You have already voted!');
        }

        // Record the user's vote
        transaction.set(userVoteRef, {
          'candidateId': _selectedCandidateId,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Update vote count
        final voteRef = FirebaseFirestore.instance
            .collection('votes')
            .doc(_selectedCandidateId);
        
        final voteDoc = await transaction.get(voteRef);
        
        if (voteDoc.exists) {
          transaction.update(voteRef, {
            'count': FieldValue.increment(1),
          });
        } else {
          transaction.set(voteRef, {
            'count': 1,
            'candidateId': _selectedCandidateId,
          });
        }
      });

      setState(() {
        _hasVoted = true;
        _loading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vote cast successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error casting vote: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return const Center(
        child: Text('Please log in to vote'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasVoted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Thank you! Your vote has been recorded.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Current Candidates:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ] else ...[
            const Text(
              'Select Your Candidate:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose one candidate to cast your vote. You can only vote once.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
          const SizedBox(height: 16),
          
          // Candidates list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('candidates')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading candidates...'),
                      ],
                    ),
                  );
                }
                
                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No candidates available yet.',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Please check back later or contact an administrator.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final candidateId = doc.id;
                    final name = data['name'] ?? 'Unknown';
                    final party = data['party'] ?? 'Independent';
                    final photoUrl = data['photoUrl'] as String?;
                    
                    final isSelected = _selectedCandidateId == candidateId;
                    final wasVotedFor = _hasVoted && _selectedCandidateId == candidateId;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: isSelected ? 4 : 1,
                      color: wasVotedFor ? Colors.green.shade50 : null,
                      child: RadioListTile<String>(
                        value: candidateId,
                        groupValue: _selectedCandidateId,
                        onChanged: _hasVoted ? null : (value) {
                          setState(() {
                            _selectedCandidateId = value;
                          });
                        },
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: wasVotedFor ? Colors.green.shade700 : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(party),
                            if (wasVotedFor)
                              const Text(
                                'Your Vote',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        secondary: CircleAvatar(
                          radius: 25,
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null ? const Icon(Icons.person) : null,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        activeColor: Colors.blue.shade700,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Vote button
          if (!_hasVoted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton(
                onPressed: (_selectedCandidateId != null && !_loading) ? _castVote : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _loading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Casting Vote...'),
                        ],
                      )
                    : const Text(
                        'Cast Vote',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
