import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final TextEditingController _candidateNameController = TextEditingController();

  // Add candidate to Firestore
  Future<void> _addCandidate() async {
    final name = _candidateNameController.text.trim();
    if (name.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection("candidates").add({
        "name": name,
        "votes": 0,
      });
      _candidateNameController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding candidate: $e")),
      );
    }
  }

  // Delete candidate from Firestore
  Future<void> _deleteCandidate(String candidateId) async {
    try {
      await FirebaseFirestore.instance.collection("candidates").doc(candidateId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Candidate deleted")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting candidate: $e")),
      );
    }
  }

  // Confirm deletion dialog
  void _confirmDelete(String candidateId, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Candidate"),
          content: Text("Are you sure you want to delete '$name'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                _deleteCandidate(candidateId);
              },
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Candidate input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _candidateNameController,
                    decoration: const InputDecoration(
                      labelText: "Candidate Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addCandidate,
                  child: const Text("Add"),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Candidate list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection("candidates").snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final candidates = snapshot.data!.docs;

                  if (candidates.isEmpty) {
                    return const Center(child: Text("No candidates yet"));
                  }

                  return ListView.builder(
                    itemCount: candidates.length,
                    itemBuilder: (context, index) {
                      final candidate = candidates[index];
                      final candidateId = candidate.id;
                      final name = candidate["name"];
                      final votes = candidate["votes"];

                      return Card(
                        child: ListTile(
                          title: Text(name),
                          subtitle: Text("Votes: $votes"),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(candidateId, name),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
