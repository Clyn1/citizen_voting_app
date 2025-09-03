import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VotePage extends StatefulWidget {
  const VotePage({super.key});

  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  final user = FirebaseAuth.instance.currentUser;

  Future<void> _castVote(String candidateId) async {
    if (user == null) return;

    final userVoteRef = FirebaseFirestore.instance
        .collection('votes')
        .doc(user!.uid);

    final candidateRef = FirebaseFirestore.instance
        .collection('elections')
        .doc('current')
        .collection('candidates')
        .doc(candidateId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userVoteDoc = await transaction.get(userVoteRef);

        if (userVoteDoc.exists) {
          throw Exception("You have already voted.");
        }

        final candidateDoc = await transaction.get(candidateRef);
        if (!candidateDoc.exists) {
          throw Exception("Candidate does not exist.");
        }

        final currentVotes = candidateDoc['votes'] ?? 0;

        // Record user's vote
        transaction.set(userVoteRef, {
          'candidateId': candidateId,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Increment candidate's votes
        transaction.update(candidateRef, {
          'votes': currentVotes + 1,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vote cast successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vote for Your Candidate")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('elections')
            .doc('current')
            .collection('candidates')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No candidates available"));
          }

          final candidates = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final candidate = candidates[index];
              final candidateId = candidate.id;
              final candidateName = candidate['name'] ?? 'Unnamed';
              final candidateImage = candidate['imageUrl'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        candidateImage.isNotEmpty ? NetworkImage(candidateImage) : null,
                    child: candidateImage.isEmpty ? const Icon(Icons.person) : null,
                  ),
                  title: Text(candidateName),
                  trailing: ElevatedButton(
                    onPressed: () => _castVote(candidateId),
                    child: const Text("Vote"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
