import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VotePage extends StatelessWidget {
  const VotePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vote for Your Candidate')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('candidates').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No candidates available.'));
          }

          final candidates = snapshot.data!.docs;

          // Debug print to check fetched data in console/logs
          for (var doc in candidates) {
            print('Candidate data: ${doc.data()}');
          }

          return ListView.builder(
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final candidate = candidates[index];
              final data = candidate.data() as Map<String, dynamic>;

              final name = data['name'] ?? 'Unnamed Candidate';
              final party = data['party'] ?? 'Independent';

              return ListTile(
                title: Text(name),
                subtitle: Text(party),
                trailing: ElevatedButton(
                  child: const Text('Vote'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Voted for $name')),
                    );
                    // You can add your voting logic here
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
