import 'dart:io';
import 'dart:typed_data'; // For Uint8List
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  String? photoUrl;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    photoUrl = user?.photoURL;
  }

  Future<void> _pickAndUpload() async {
    if (user == null) return;

    setState(() => uploading = true);

    Uint8List? fileBytes;
    String fileName = 'avatar.jpg';

    try {
      if (kIsWeb) {
        // Web: Use FilePicker
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result == null || result.files.isEmpty) {
          setState(() => uploading = false);
          return;
        }
        fileBytes = result.files.first.bytes;
        fileName = result.files.first.name;
      } else {
        // Mobile: Use ImagePicker
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 75,
        );
        if (pickedFile == null) {
          setState(() => uploading = false);
          return;
        }
        fileBytes = await File(pickedFile.path).readAsBytes();
        fileName = pickedFile.name;
      }

      // Upload to Firebase Storage
      final ref = FirebaseStorage.instance.ref('profiles/${user!.uid}/$fileName');
      await ref.putData(fileBytes!);
      final url = await ref.getDownloadURL();

      await user!.updatePhotoURL(url);

      if (!mounted) return;
      setState(() {
        photoUrl = url;
        uploading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
                  child: photoUrl == null ? const Icon(Icons.person, size: 50) : null,
                ),
                if (uploading)
                  const Positioned.fill(
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Email: ${user!.email}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: uploading ? null : _pickAndUpload, // Disable button while uploading
              icon: const Icon(Icons.camera_alt),
              label: const Text('Change Photo'),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _signOut,
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
