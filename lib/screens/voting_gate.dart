// lib/screens/vote_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VotePage extends StatefulWidget {
  const VotePage({super.key});

  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  String? _selectedId;
  bool _isSubmitting = false;
  String? _votedCandidateSessionId;

  final CollectionReference<Map<String, dynamic>> candidatesRef =
      FirebaseFirestore.instance.collection('candidates').withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (map, _) => map,
          );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vote for Your Candidate')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('elections')
            .doc('current')
            .snapshots(),
        builder: (context, electionSnap) {
          if (electionSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!electionSnap.hasData || !electionSnap.data!.exists) {
            return const Center(child: Text('No election data found.'));
          }

          final election = electionSnap.data!.data()!;
          final startTime = (election['startTime'] as Timestamp).toDate();
          final endTime = (election['endTime'] as Timestamp).toDate();
          final now = DateTime.now();

          final votingOpen = now.isAfter(startTime) && now.isBefore(endTime);

          if (!votingOpen) {
            return Center(
              child: Text(
                now.isBefore(startTime)
                    ? 'Voting has not started yet.\nStarts at: $startTime'
                    : 'Voting has ended.\nEnded at: $endTime',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            );
          }

          // ✅ Voting is open — now load candidates
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: candidatesRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Error loading candidates'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No candidates available.'));
              }

              return ListView.builder(
                itemCount: docs.length,
                padding: const EdgeInsets.all(12),
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final data = doc.data();

                  final display = (data['name'] as String?)?.trim() ?? doc.id;
                  final canonicalName = display;
                  final votesCountRaw = data['votesCount'];
                  final votes = (votesCountRaw is num) ? votesCountRaw.toInt() : 0;
                  final photoUrl = (data['photoUrl'] as String?)?.trim() ?? '';

                  final alreadyVoted = _votedCandidateSessionId != null;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio<String>(
                            value: canonicalName,
                            groupValue: _selectedId,
                            onChanged: alreadyVoted
                                ? null
                                : (v) => setState(() => _selectedId = v),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 25,
                            backgroundImage: photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                        ],
                      ),
                      title: Text(display),
                      subtitle: Text('Votes: $votes'),
                      trailing: ElevatedButton(
                        onPressed: (alreadyVoted || _isSubmitting)
                            ? null
                            : () async {
                                if (_selectedId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Select a candidate first'),
                                    ),
                                  );
                                  return;
                                }
                                final user =
                                    FirebaseAuth.instance.currentUser;
                                if (user == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Sign in to vote'),
                                    ),
                                  );
                                  return;
                                }

                                setState(() => _isSubmitting = true);
                                try {
                                  final docRef = FirebaseFirestore.instance
                                      .collection('candidates')
                                      .doc(doc.id);

                                  await FirebaseFirestore.instance
                                      .runTransaction((tx) async {
                                    final snap = await tx.get(docRef);
                                    final data = snap.data();
                                    final current =
                                        (data != null && data['votesCount'] is num)
                                            ? (data['votesCount'] as num).toInt()
                                            : 0;
                                    tx.update(docRef,
                                        {'votesCount': current + 1});
                                  });

                                  await FirebaseFirestore.instance
                                      .collection('user_votes')
                                      .doc(user.uid)
                                      .set({
                                    'candidate': _selectedId,
                                    'timestamp':
                                        FieldValue.serverTimestamp(),
                                  });

                                  setState(() =>
                                      _votedCandidateSessionId = _selectedId);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Voted for $display'),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Vote failed: $e'),
                                    ),
                                  );
                                } finally {
                                  setState(() => _isSubmitting = false);
                                }
                              },
                        child: const Text('Vote'),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
