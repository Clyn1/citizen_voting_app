// lib/screens/vote_page.dart
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
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No candidates available.'));
          }

          final candidates = snapshot.data!.docs;

          return ListView.builder(
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final candidate = candidates[index];
              final name = candidate['name'];
              final party = candidate['party'] ?? 'Independent';

              return ListTile(
                title: Text(name),
                subtitle: Text(party),
                trailing: ElevatedButton(
                  child: const Text('Vote'),
                  onPressed: () {
                    // Optional: implement vote logic here
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Voted for $name')),
                    );
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
