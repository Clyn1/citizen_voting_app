import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddCandidatePage extends StatefulWidget {
  @override
  _AddCandidatePageState createState() => _AddCandidatePageState();
}

class _AddCandidatePageState extends State<AddCandidatePage> {
  final TextEditingController _nameController = TextEditingController();

  void addCandidate(String name) async {
    try {
      await FirebaseFirestore.instance.collection('candidates').add({
        'name': name,
        'votes': 0,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Candidate "$name" added!')),
      );
      _nameController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add candidate: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Candidate')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Candidate Name'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                String name = _nameController.text.trim();
                if (name.isNotEmpty) {
                  addCandidate(name);
                }
              },
              child: Text('Add'),
            )
          ],
        ),
      ),
    );
  }
}
