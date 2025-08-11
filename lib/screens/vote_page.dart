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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: candidatesRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading candidates'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('No candidates available.'));

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data();
              final display = (data['displayName'] as String?)?.trim() ?? doc.id;
              final canonicalName = (data['name'] as String?)?.trim() ?? doc.id;
              final votesCountRaw = data['votesCount'];
              final votes = (votesCountRaw is num) ? votesCountRaw.toInt() : 0;
              final alreadyVoted = _votedCandidateSessionId != null;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: Radio<String>(
                    value: canonicalName,
                    groupValue: _selectedId,
                    onChanged: alreadyVoted ? null : (v) => setState(() => _selectedId = v),
                  ),
                  title: Text(display),
                  subtitle: Text('Votes: $votes'),
                  trailing: ElevatedButton(
                    onPressed: (alreadyVoted || _isSubmitting)
                        ? null
                        : () async {
                            if (_selectedId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a candidate first')));
                              return;
                            }
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to vote')));
                              return;
                            }

                            setState(() => _isSubmitting = true);
                            try {
                              // Prefer to increment by doc id or 'name' field. We'll use doc reference directly:
                              final docRef = FirebaseFirestore.instance.collection('candidates').doc(doc.id);

                              await FirebaseFirestore.instance.runTransaction((tx) async {
                                final snap = await tx.get(docRef);
                                final data = snap.data();
                                final current = (data != null && data['votesCount'] is num) ? (data['votesCount'] as num).toInt() : 0;
                                tx.update(docRef, {'votesCount': current + 1});
                              });

                              // Save that user voted (simple tracking)
                              await FirebaseFirestore.instance.collection('user_votes').doc(user.uid).set({
                                'candidate': _selectedId,
                                'timestamp': FieldValue.serverTimestamp(),
                              });

                              setState(() => _votedCandidateSessionId = _selectedId);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Voted for $display')));
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vote failed: $e')));
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
      ),
    );
  }
}
