// lib/screens/vote_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VotePage extends StatefulWidget {
  const VotePage({super.key});

  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  StreamSubscription<QuerySnapshot>? _candidatesSubscription;
  StreamSubscription<QuerySnapshot>? _votesSubscription;
  
  List<QueryDocumentSnapshot> _candidates = [];
  String? _selectedCandidateId;
  bool _hasVoted = false;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
    _checkVotingStatus();
  }

  @override
  void dispose() {
    _candidatesSubscription?.cancel();
    _votesSubscription?.cancel();
    super.dispose();
  }

  void _loadCandidates() {
    _candidatesSubscription = _firestore
        .collection('elections')
        .doc('current')
        .collection('candidates')
        .orderBy('name')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _candidates = snapshot.docs;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading candidates: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  void _checkVotingStatus() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _votesSubscription = _firestore
        .collection('votes')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _hasVoted = snapshot.docs.isNotEmpty;
          if (_hasVoted) {
            final voteData = snapshot.docs.first.data();
            _selectedCandidateId = voteData['candidateId'] as String?;
          }
        });
      }
    });
  }

  Future<void> _submitVote() async {
    if (_selectedCandidateId == null || _hasVoted) return;

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to vote'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Check if user has already voted (double-check)
      final existingVote = await _firestore
          .collection('votes')
          .where('userId', isEqualTo: userId)
          .get();

      if (existingVote.docs.isNotEmpty) {
        setState(() {
          _hasVoted = true;
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already voted'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Submit the vote
      await _firestore.collection('votes').add({
        'userId': userId,
        'candidateId': _selectedCandidateId,
        'timestamp': FieldValue.serverTimestamp(),
        'userEmail': _auth.currentUser?.email,
      });

      setState(() {
        _hasVoted = true;
        _isSubmitting = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vote submitted successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Show confirmation dialog
      _showVoteConfirmationDialog();

    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting vote: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showVoteConfirmationDialog() {
    final candidate = _candidates.firstWhere(
      (c) => c.id == _selectedCandidateId,
      orElse: () => throw StateError('Candidate not found'),
    );
    final candidateData = candidate.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Vote Confirmed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your vote has been successfully recorded for:'),
            const SizedBox(height: 16),
            _buildCandidateImage(candidateData, size: 60),
            const SizedBox(height: 8),
            Text(
              candidateData['name'] ?? 'Unknown',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              candidateData['party'] ?? '',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Text(
                'Thank you for participating in this election!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateImage(Map<String, dynamic> candidateData, {double size = 80}) {
    final imageUrl = candidateData['imageUrl'] as String?;
    
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / 
                        loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultAvatar(candidateData, size);
          },
        ),
      );
    } else {
      return _buildDefaultAvatar(candidateData, size);
    }
  }

  Widget _buildDefaultAvatar(Map<String, dynamic> candidateData, double size) {
    final name = candidateData['name'] as String? ?? 'Unknown';
    final initials = name
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
        .take(2)
        .join();
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.deepPurple.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
      ),
    );
  }

  Widget _buildCandidateCard(QueryDocumentSnapshot candidate) {
    final candidateData = candidate.data() as Map<String, dynamic>;
    final isSelected = _selectedCandidateId == candidate.id;
    final name = candidateData['name'] as String? ?? 'Unknown';
    final party = candidateData['party'] as String? ?? '';
    final description = candidateData['description'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isSelected ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.deepPurple : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _hasVoted ? null : () {
          setState(() {
            _selectedCandidateId = isSelected ? null : candidate.id;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Candidate Image/Avatar
              _buildCandidateImage(candidateData),
              const SizedBox(width: 16),
              
              // Candidate Information
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
                    if (party.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        party,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              // Selection Indicator
              if (_hasVoted && _selectedCandidateId == candidate.id)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 20,
                  ),
                )
              else if (isSelected)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.radio_button_checked,
                    color: Colors.white,
                    size: 20,
                  ),
                )
              else if (!_hasVoted)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.radio_button_unchecked,
                    color: Colors.grey,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoteButton() {
    if (_hasVoted) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text(
              'You have already voted',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _selectedCandidateId != null && !_isSubmitting
            ? _submitVote
            : null,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.how_to_vote),
        label: Text(
          _isSubmitting ? 'Submitting Vote...' : 'Submit Vote',
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No candidates available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Candidates will appear here when added by administrators.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    if (_hasVoted) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'How to Vote',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '1. Select your preferred candidate by tapping their card\n'
            '2. Review your selection\n'
            '3. Tap "Submit Vote" to cast your ballot\n'
            '4. Your vote will be recorded and cannot be changed',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_candidates.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Instructions (only shown if not voted)
        _buildInstructions(),
        
        // Candidates List
        Expanded(
          child: ListView.builder(
            itemCount: _candidates.length,
            itemBuilder: (context, index) {
              return _buildCandidateCard(_candidates[index]);
            },
          ),
        ),
        
        // Vote Button
        _buildVoteButton(),
      ],
    );
  }
}