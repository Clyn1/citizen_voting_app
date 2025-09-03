import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<DocumentSnapshot<Map<String, dynamic>>> _getElection() async {
    return await FirebaseFirestore.instance
        .collection('elections')
        .doc('current') // 👈 your doc ID
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Citizen Voting App"),
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _getElection(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("No election data found"));
          }

          final electionData = snapshot.data!.data()!;
          final title = electionData['title'] ?? 'Untitled Election';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                      return const Center(child: Text("No candidates found"));
                    }

                    final candidates = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: candidates.length,
                      itemBuilder: (context, index) {
                        final data = candidates[index].data();
                        final name = data['name'] ?? "Unknown";
                        final party = data['party'] ?? "Independent";
                        final photoUrl = data['photoUrl'] ??
                            "https://via.placeholder.com/150";

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(photoUrl),
                            ),
                            title: Text(name),
                            subtitle: Text("Party: $party"),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
