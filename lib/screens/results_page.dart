import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Election Results')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('votes').snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No votes cast yet.'));
          }
          // find max to scale bars
          final counts = docs.map((d) => (d['count'] ?? 0) as int);
          final maxCount = counts.isEmpty ? 1 : counts.reduce((a, b) => a > b ? a : b);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final id = doc.id.replaceAll('_', ' ').toUpperCase();
              final count = (doc['count'] ?? 0) as int;
              final percent = count / maxCount;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(id, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Stack(children: [
                      Container(height: 20, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                      FractionallySizedBox(
                        widthFactor: percent,
                        child: Container(height: 20, decoration: BoxDecoration(color: Colors.deepPurple, borderRadius: BorderRadius.circular(4))),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text('Votes: $count'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
