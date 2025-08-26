import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Election Results')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('candidates').snapshots(),
        builder: (context, candidateSnap) {
          if (candidateSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!candidateSnap.hasData || candidateSnap.data!.docs.isEmpty) {
            return const Center(child: Text('No candidates available.'));
          }

          // Create map of candidate data
          final candidateMap = {
            for (var doc in candidateSnap.data!.docs)
              doc.id.toUpperCase(): {
                'name': (doc.data() as Map<String, dynamic>)['name'] ?? '',
                // Check both 'url' and 'imageUrl'
                'imageUrl': (doc.data() as Map<String, dynamic>).containsKey('url')
                    ? (doc.data() as Map<String, dynamic>)['url']
                    : ((doc.data() as Map<String, dynamic>).containsKey('imageUrl')
                        ? (doc.data() as Map<String, dynamic>)['imageUrl']
                        : ''),
              }
          };

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('votes').snapshots(),
            builder: (context, voteSnap) {
              if (voteSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!voteSnap.hasData || voteSnap.data!.docs.isEmpty) {
                return const Center(child: Text('No votes cast yet.'));
              }

              final votes = voteSnap.data!.docs;
              final counts = votes.map((d) => (d['count'] ?? 0) as int);
              final maxCount = counts.isEmpty ? 1 : counts.reduce((a, b) => a > b ? a : b);

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: votes.length,
                itemBuilder: (context, i) {
                  final voteDoc = votes[i];
                  final candidateId = voteDoc.id.toUpperCase();
                  final count = (voteDoc['count'] ?? 0) as int;
                  final percent = count / maxCount;

                  final candidateData = candidateMap[candidateId];
                  final candidateName = candidateData?['name'] ?? candidateId;
                  final imageUrl = candidateData?['imageUrl'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundImage: imageUrl.isNotEmpty
                              ? NetworkImage(imageUrl)
                              : null,
                          radius: 24,
                          child: imageUrl.isEmpty ? const Icon(Icons.person) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                candidateName.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Stack(
                                children: [
                                  Container(
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: percent,
                                    child: Container(
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Votes: $count'),
                            ],
                          ),
                        ),
                      ],
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
