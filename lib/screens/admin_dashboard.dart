// admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _candidateNameController = TextEditingController();
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Election Status Card
            _buildElectionStatusCard(),
            const SizedBox(height: 20),
            
            // Election Control Panel
            _buildElectionControlPanel(),
            const SizedBox(height: 20),
            
            // Candidates Management
            _buildCandidatesManagement(),
            const SizedBox(height: 20),
            
            // Live Statistics
            _buildLiveStatistics(),
          ],
        ),
      ),
    );
  }

  Widget _buildElectionStatusCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('elections').doc('current').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final election = snapshot.data!.data() as Map<String, dynamic>?;
        if (election == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No election configured'),
            ),
          );
        }

        final startTime = (election['startTime'] as Timestamp?)?.toDate();
        final endTime = (election['endTime'] as Timestamp?)?.toDate();
        final now = DateTime.now();
        
        String status;
        Color statusColor;
        IconData statusIcon;
        
        if (startTime != null && endTime != null) {
          if (now.isBefore(startTime)) {
            status = 'SCHEDULED';
            statusColor = Colors.orange;
            statusIcon = Icons.schedule;
          } else if (now.isAfter(endTime)) {
            status = 'ENDED';
            statusColor = Colors.red;
            statusIcon = Icons.stop;
          } else {
            status = 'ACTIVE';
            statusColor = Colors.green;
            statusIcon = Icons.how_to_vote;
          }
        } else {
          status = 'NOT CONFIGURED';
          statusColor = Colors.grey;
          statusIcon = Icons.error;
        }

        return Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 32),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Election Status',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (startTime != null && endTime != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Time:', style: TextStyle(fontWeight: FontWeight.w500)),
                            Text(_formatDateTime(startTime)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('End Time:', style: TextStyle(fontWeight: FontWeight.w500)),
                            Text(_formatDateTime(endTime)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildElectionControlPanel() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Election Control',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Start Time Picker
            ListTile(
              leading: const Icon(Icons.play_arrow, color: Colors.green),
              title: const Text('Start Time'),
              subtitle: Text(_startTime != null 
                  ? _formatDateTime(_startTime!) 
                  : 'Not set'),
              trailing: const Icon(Icons.edit),
              onTap: () => _selectDateTime(true),
            ),
            
            // End Time Picker
            ListTile(
              leading: const Icon(Icons.stop, color: Colors.red),
              title: const Text('End Time'),
              subtitle: Text(_endTime != null 
                  ? _formatDateTime(_endTime!) 
                  : 'Not set'),
              trailing: const Icon(Icons.edit),
              onTap: () => _selectDateTime(false),
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _updateElectionTimes,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Update Election'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _endElectionNow,
                  icon: const Icon(Icons.stop),
                  label: const Text('End Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidatesManagement() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Candidates Management',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Add New Candidate
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _candidateNameController,
                    decoration: const InputDecoration(
                      labelText: 'Candidate Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _addCandidate,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Candidates List
            StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('elections').doc('current').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                
                final election = snapshot.data!.data() as Map<String, dynamic>?;
                final candidates = election?['candidates'] as List<dynamic>? ?? [];
                
                if (candidates.isEmpty) {
                  return Center(
                    child: Text(
                      'No candidates added yet',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }
                
                return Column(
                  children: candidates.asMap().entries.map((entry) {
                    final index = entry.key;
                    final candidate = entry.value as Map<String, dynamic>;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Text('${index + 1}'),
                      ),
                      title: Text(candidate['name'] ?? 'Unknown'),
                      subtitle: Text('ID: ${candidate['id'] ?? 'N/A'}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeCandidate(index),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStatistics() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Statistics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('Total Votes', '0', Icons.how_to_vote, Colors.blue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard('Candidates', '0', Icons.people, Colors.green),
                ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to detailed results page
                Navigator.pushNamed(context, '/results');
              },
              icon: const Icon(Icons.analytics),
              label: const Text('View Detailed Results'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateTime(bool isStartTime) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      
      if (time != null) {
        final dateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        
        setState(() {
          if (isStartTime) {
            _startTime = dateTime;
          } else {
            _endTime = dateTime;
          }
        });
      }
    }
  }

  Future<void> _updateElectionTimes() async {
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set both start and end times')),
      );
      return;
    }

    if (_endTime!.isBefore(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('elections').doc('current').set({
        'startTime': Timestamp.fromDate(_startTime!),
        'endTime': Timestamp.fromDate(_endTime!),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Election times updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating election times: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _endElectionNow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Election'),
        content: const Text('Are you sure you want to end the election now? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Election'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('elections').doc('current').update({
          'endTime': Timestamp.now(),
          'endedEarly': true,
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Election ended successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ending election: $e')),
        );
      }
    }
  }

  Future<void> _addCandidate() async {
    final name = _candidateNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a candidate name')),
      );
      return;
    }

    try {
      final currentElection = await _firestore.collection('elections').doc('current').get();
      final data = currentElection.data() ?? {};
      final candidates = List<Map<String, dynamic>>.from(data['candidates'] ?? []);
      
      candidates.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': name,
      });

      await _firestore.collection('elections').doc('current').update({
        'candidates': candidates,
      });

      _candidateNameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Candidate added successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding candidate: $e')),
      );
    }
  }

  Future<void> _removeCandidate(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Candidate'),
        content: const Text('Are you sure you want to remove this candidate?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final currentElection = await _firestore.collection('elections').doc('current').get();
        final data = currentElection.data() ?? {};
        final candidates = List<Map<String, dynamic>>.from(data['candidates'] ?? []);
        
        candidates.removeAt(index);

        await _firestore.collection('elections').doc('current').update({
          'candidates': candidates,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Candidate removed successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing candidate: $e')),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }
}