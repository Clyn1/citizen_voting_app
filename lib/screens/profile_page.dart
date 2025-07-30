import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (file == null || user == null) return;

    setState(() => uploading = true);
    final ref = FirebaseStorage.instance.ref('profiles/${user!.uid}/avatar.jpg');
    await ref.putFile(File(file.path));
    final url = await ref.getDownloadURL();
    await user!.updatePhotoURL(url);

    setState(() {
      photoUrl = url;
      uploading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
                child: photoUrl == null ? const Icon(Icons.person, size: 50) : null,
              ),
              if (uploading)
                const Positioned.fill(child: Center(child: CircularProgressIndicator())),
            ]),
            const SizedBox(height: 20),
            Text('Email: ${user!.email}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickAndUpload,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Change Photo'),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
