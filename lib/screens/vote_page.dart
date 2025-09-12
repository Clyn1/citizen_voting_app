// lib/screens/vote_page.dart - Fixed version
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VotePage extends StatefulWidget {
  const VotePage({super.key});

  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _hasVoted = false;
  bool _isLoading = true;
  String? _votedCandidateId;

  @override
  void initState() {
    super.initState();
    _checkVotingStatus();
  }

  Future<void> _checkVotingStatus() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final voteDoc = await _firestore
            .collection('votes')
            .doc(user.uid)
            .get();

        if (mounted) {
          setState(() {
            _hasVoted = voteDoc.exists;
            _votedCandidateId = voteDoc.data()?['candidateId'];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error checking voting status: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _castVote(String candidateId, String candidateName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showMessage('Please log in to vote', Colors.red);
        return;
      }

      if (_hasVoted) {
        _showMessage('You have already voted', Colors.orange);
        return;
      }

      // Show confirmation dialog
      bool? confirmed = await _showConfirmationDialog(candidateName);
      if (confirmed != true) return;

      // Show loading
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      // Use a batch write to ensure consistency
      WriteBatch batch = _firestore.batch();

      // Add vote record
      DocumentReference voteRef = _firestore.collection('votes').doc(user.uid);
      batch.set(voteRef, {
        'candidateId': candidateId,
        'candidateName': candidateName,
        'userId': user.uid,
        'userEmail': user.email,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update candidate vote count
      DocumentReference candidateRef = _firestore.collection('candidates').doc(candidateId);
      batch.update(candidateRef, {
        'voteCount': FieldValue.increment(1),
      });

      // Commit the batch
      await batch.commit();

      if (mounted) {
        setState(() {
          _hasVoted = true;
          _votedCandidateId = candidateId;
          _isLoading = false;
        });
        _showMessage('Vote cast successfully!', Colors.green);
      }

    } catch (e) {
      print('Error casting vote: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showMessage('Error casting vote: ${e.toString()}', Colors.red);
      }
    }
  }

  Future<bool?> _showConfirmationDialog(String candidateName) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Vote'),
          content: Text('Are you sure you want to vote for $candidateName?\n\nThis action cannot be undone.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Vote'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildCandidateCard(QueryDocumentSnapshot candidate) {
    final candidateData = candidate.data() as Map<String, dynamic>;
    final candidateId = candidate.id;
    final candidateName = candidateData['name'] ?? 'Unknown';
    final candidateParty = candidateData['party'] ?? '';
    final candidateImage = candidateData['imageUrl'];
    final voteCount = candidateData['voteCount'] ?? 0;
    final hasVotedForThis = _votedCandidateId == candidateId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasVotedForThis 
            ? BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Candidate Image
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: candidateImage != null 
                  ? NetworkImage(candidateImage)
                  : null,
              child: candidateImage == null
                  ? Icon(Icons.person, size: 30, color: Colors.grey.shade600)
                  : null,
            ),
            const SizedBox(width: 16),
            
            // Candidate Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidateName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (candidateParty.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      candidateParty,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Votes: $voteCount',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  if (hasVotedForThis) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Your Vote',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Vote Button
            ElevatedButton(
              onPressed: (_hasVoted || _isLoading) 
                  ? null 
                  : () => _castVote(candidateId, candidateName),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasVotedForThis 
                    ? Colors.green 
                    : Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                hasVotedForThis ? 'Voted' : 'Vote',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                const Text(
                  'Vote for Your Candidate',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_hasVoted) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'You have already voted',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Loading or Candidates List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading candidates...'),
                      ],
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: _firestore
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
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isLoading = true;
                                  });
                                  _checkVotingStatus();
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final candidates = snapshot.data?.docs ?? [];

                      if (candidates.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.how_to_vote, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No candidates available',
                                style: TextStyle(fontSize: 18),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Please check back later or contact admin',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          return _buildCandidateCard(candidates[index]);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}