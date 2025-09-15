import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _nameCtrl = TextEditingController();
  final _partyCtrl = TextEditingController();
  bool _checkedAdmin = false;
  bool _isAdmin = false;
  bool _uploading = false;
  String? uid;
  Uint8List? _selectedPhotoBytes;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    uid = user?.uid;
    _checkAdmin();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _partyCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() {
      _isAdmin = doc.exists && (doc.data()?['isAdmin'] == true);
      _checkedAdmin = true;
    });
  }

  Future<void> _pickPhoto() async {
    if (!_isAdmin) return;

    setState(() => _uploading = true);

    try {
      Uint8List? fileBytes;
      if (kIsWeb) {
        // Web: Use FilePicker
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result == null || result.files.isEmpty) {
          setState(() => _uploading = false);
          return;
        }
        fileBytes = result.files.first.bytes;
      } else {
        // Mobile: Use ImagePicker
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 75,
          maxWidth: 500,
          maxHeight: 500,
        );
        if (pickedFile == null) {
          setState(() => _uploading = false);
          return;
        }
        fileBytes = await File(pickedFile.path).readAsBytes();
      }

      setState(() {
        _selectedPhotoBytes = fileBytes;
        _uploading = false;
      });
    } catch (e) {
      setState(() => _uploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo selection failed: $e')),
        );
      }
    }
  }

  Future<String?> _uploadPhotoToStorage(String candidateName) async {
    if (_selectedPhotoBytes == null) return null;

    try {
      // Create a unique filename using timestamp and candidate name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = candidateName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final fileName = 'candidate_${sanitizedName}_$timestamp.jpg';
      
      final ref = FirebaseStorage.instance.ref('candidates/$fileName');
      await ref.putData(_selectedPhotoBytes!);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Photo upload failed: $e');
    }
  }

  Future<void> _addCandidate() async {
    final name = _nameCtrl.text.trim();
    final party = _partyCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _uploading = true);

    try {
      String? photoUrl;
      if (_selectedPhotoBytes != null) {
        photoUrl = await _uploadPhotoToStorage(name);
      }

      await FirebaseFirestore.instance.collection('candidates').add({
        'name': name,
        'party': party,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Clear form
      _nameCtrl.clear();
      _partyCtrl.clear();
      setState(() {
        _selectedPhotoBytes = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Candidate added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _updateCandidatePhoto(String candidateId, String candidateName) async {
    setState(() => _uploading = true);

    try {
      Uint8List? fileBytes;
      if (kIsWeb) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result == null || result.files.isEmpty) {
          setState(() => _uploading = false);
          return;
        }
        fileBytes = result.files.first.bytes;
      } else {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 75,
          maxWidth: 500,
          maxHeight: 500,
        );
        if (pickedFile == null) {
          setState(() => _uploading = false);
          return;
        }
        fileBytes = await File(pickedFile.path).readAsBytes();
      }

      // Upload new photo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = candidateName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final newFileName = 'candidate_${sanitizedName}_$timestamp.jpg';
      
      final ref = FirebaseStorage.instance.ref('candidates/$newFileName');
      await ref.putData(fileBytes!);
      final newPhotoUrl = await ref.getDownloadURL();

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('candidates')
          .doc(candidateId)
          .update({'photoUrl': newPhotoUrl});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo update failed: $e')),
        );
      }
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _deleteCandidate(String candidateId, String? photoUrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Candidate'),
        content: const Text('Are you sure you want to delete this candidate?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('candidates')
          .doc(candidateId)
          .delete();

      // Delete photo from Storage if exists
      if (photoUrl != null) {
        try {
          await FirebaseStorage.instance.refFromURL(photoUrl).delete();
        } catch (e) {
          // Photo deletion failed, but document is already deleted
          debugPrint('Failed to delete photo: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Candidate deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Candidate Photo (Optional)', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _selectedPhotoBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _selectedPhotoBytes!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.person, size: 40, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: _uploading ? null : _pickPhoto,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt, size: 18),
                  label: Text(_selectedPhotoBytes != null ? 'Change Photo' : 'Add Photo'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                if (_selectedPhotoBytes != null)
                  TextButton(
                    onPressed: () => setState(() => _selectedPhotoBytes = null),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Remove'),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCandidateCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final photoUrl = data['photoUrl'] as String?;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null ? const Icon(Icons.person) : null,
        ),
        title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(data['party'] ?? 'Independent'),
        trailing: _isAdmin ? PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'photo':
                _updateCandidatePhoto(doc.id, data['name'] ?? '');
                break;
              case 'delete':
                _deleteCandidate(doc.id, photoUrl);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'photo',
              child: Row(
                children: [
                  Icon(Icons.camera_alt, size: 18),
                  SizedBox(width: 8),
                  Text('Update Photo'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedAdmin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isAdmin) ...[
                const Text(
                  'Add New Candidate',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Candidate Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _partyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Party (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _buildPhotoSection(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _uploading ? null : _addCandidate,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _uploading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Adding Candidate...'),
                            ],
                          )
                        : const Text('Add Candidate'),
                  ),
                ),
                const Divider(height: 40),
              ] else ...[
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You are not an admin. You can only view candidates.',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Row(
                children: [
                  const Text(
                    'Current Candidates',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('candidates').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text(
                          '(${snapshot.data!.docs.length})',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('candidates')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Error: ${snapshot.error}')),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  if (!snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.people_outline, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('No candidates yet', style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) => _buildCandidateCard(docs[index]),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}