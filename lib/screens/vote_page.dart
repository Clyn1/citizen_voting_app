import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VotePage extends StatefulWidget {
  const VotePage({super.key});

  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  String? _selection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cast Your Vote'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.pushNamed(context, '/results');
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('candidates')
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No candidates found.'));
                  }
                  return ListView(
                    children: docs.map((doc) {
                      final id = doc.id;
                      final displayName = doc['name'] as String;
                      return RadioListTile<String>(
                        title: Text(displayName),
                        value: id,
                        groupValue: _selection,
                        onChanged: (v) => setState(() => _selection = v),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selection == null ? null : _submitVote,
                child: const Text('Submit Vote'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitVote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to vote.')),
      );
      return;
    }

    final voteDoc = FirebaseFirestore.instance
        .collection('votes')
        .doc(_selection);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snapshot = await tx.get(voteDoc);
      final current = snapshot.exists ? (snapshot['count'] as int) : 0;
      tx.set(voteDoc, {'count': current + 1});
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vote submitted!')),
    );
    setState(() {
      _selection = null;
    });
  }
}
