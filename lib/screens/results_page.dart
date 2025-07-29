import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voting Results')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('votes').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No votes cast yet.'));
          }
          return ListView(
            children: docs.map((doc) {
              final candidateId = doc.id;
              final count = doc['count'] as int;
              return ListTile(
                title: Text(candidateId.replaceAll('_', ' ').toUpperCase()),
                trailing: Text('Votes: $count'),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
