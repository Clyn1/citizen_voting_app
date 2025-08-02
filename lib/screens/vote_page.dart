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
          // 1. Show error message if there is an error
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong!'));
          }

          // 2. Show loading indicator while waiting for data
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 3. Show message if no candidates are found
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No candidates available.'));
          }

          // 4. Data loaded, build list of candidates
          final candidates = snapshot.data!.docs;

          // Optional debug: print candidate data to console
          for (var doc in candidates) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            print('Candidate data: $data');
          }

          return ListView.builder(
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final doc = candidates[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};

              final name = (data['name'] as String?)?.trim() ?? 'Unnamed Candidate';
              final party = (data['party'] as String?)?.trim() ?? 'Independent';

              return ListTile(
                title: Text(name),
                subtitle: Text(party),
                trailing: ElevatedButton(
                  child: const Text('Vote'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Voted for $name')),
                    );
                    // TODO: Add your voting logic here.
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
