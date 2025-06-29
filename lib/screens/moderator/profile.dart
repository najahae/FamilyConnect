import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ModeratorProfilePage extends StatefulWidget {
  final String familyId;

  const ModeratorProfilePage({Key? key, required this.familyId}) : super(key: key);

  @override
  _ModeratorProfilePageState createState() => _ModeratorProfilePageState();
}

class _ModeratorProfilePageState extends State<ModeratorProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool showCurrent = false;
  bool showNew = false;
  bool showConfirm = false;
  bool isLoading = true;

  File? _imageFile;
  String? _imageUrl;
  String email = '';

  @override
  void initState() {
    super.initState();
    _loadModeratorData();
  }

  Future<void> _loadModeratorData() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final doc = await _firestore
          .collection('families')
          .doc(widget.familyId)
          .collection('moderators')
          .doc(uid)
          .get();

      if (doc.exists) {
        setState(() {
          email = doc['email'] ?? '';
          isLoading = false;
        });
      }
      setState(() {
        email = doc['email'] ?? '';
        _imageUrl = doc['profileImageUrl']; // Get profile picture
        isLoading = false;
      });
    }
  }

  Future<bool> reauthenticateUser(String email, String currentPassword) async {
    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await _auth.currentUser?.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      print('Reauthentication failed: $e');
      return false;
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    final uid = _auth.currentUser!.uid;

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('moderators/$uid/profile.jpg');

    await storageRef.putFile(file);
    final downloadUrl = await storageRef.getDownloadURL();

    await _firestore
        .collection('families')
        .doc(widget.familyId)
        .collection('moderators')
        .doc(uid)
        .update({'profileImageUrl': downloadUrl});

    setState(() {
      _imageFile = file;
      _imageUrl = downloadUrl;
    });
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password updated successfully!")),
      );
    } catch (e) {
      print('Password update failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update password")),
      );
    }
  }

  void _showPasswordUpdateDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Password'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: !showCurrent,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  suffixIcon: IconButton(
                    icon: Icon(showCurrent ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => showCurrent = !showCurrent),
                  ),
                ),
              ),
              TextField(
                controller: newPasswordController,
                obscureText: !showNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  suffixIcon: IconButton(
                    icon: Icon(showNew ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => showNew = !showNew),
                  ),
                ),
              ),
              TextField(
                controller: confirmPasswordController,
                obscureText: !showConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  suffixIcon: IconButton(
                    icon: Icon(showConfirm ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => showConfirm = !showConfirm),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final current = currentPasswordController.text.trim();
              final newPass = newPasswordController.text.trim();
              final confirm = confirmPasswordController.text.trim();

              String? error;
              if (newPass != confirm) {
                error = "Passwords do not match.";
              } else if (newPass.length < 6) {
                error = "Password must be at least 6 characters long.";
              } else if (!RegExp(r'[A-Z]').hasMatch(newPass)) {
                error = "Password must contain at least one uppercase letter.";
              } else if (!RegExp(r'[0-9]').hasMatch(newPass)) {
                error = "Password must contain at least one number.";
              } else if (!RegExp(r'[_!@#\$&*~]').hasMatch(newPass)) {
                error = "Password must contain at least one special character (_!@#\$&*~)";
              }

              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                return;
              }

              final userEmail = _auth.currentUser?.email;
              if (userEmail == null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User not signed in")));
                return;
              }

              final success = await reauthenticateUser(userEmail, current);
              if (success) {
                await updatePassword(newPass);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Wrong current password.")),
                );
              }
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Account'),
        content: Text('Are you sure you want to delete your account? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      final user = _auth.currentUser;
      if (user != null) {
        try {
          await _firestore
              .collection('families')
              .doc(widget.familyId)
              .collection('moderators')
              .doc(user.uid)
              .delete();

          await user.delete();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Account deleted successfully')),
            );
            Navigator.of(context).pop();
          }
        } catch (e) {
          print("Error deleting moderator: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to delete account.")),
          );
        }
      }
    }
  }

  Widget _buildInfoTile(IconData icon, String label, String value, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
      trailing: Icon(Icons.arrow_forward_ios),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
            child: AppBar(
              backgroundColor: Colors.green[200],
              centerTitle: true,
              automaticallyImplyLeading: false,
              title: Text(
                "Profile",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(25),
            bottomRight: Radius.circular(25),
          ),
          child: AppBar(
            backgroundColor: Colors.green[200],
            centerTitle: true,
            automaticallyImplyLeading: false,
            title: Text(
              "Profile",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
          GestureDetector(
          onTap: _pickAndUploadImage,
          child: CircleAvatar(
            radius: 50,
            backgroundImage: _imageUrl != null
                ? NetworkImage(_imageUrl!)
                : null,
            child: _imageUrl == null
                ? Icon(Icons.person, size: 60)
                : null,
          ),
        ),
          SizedBox(height: 8),
          TextButton(
            onPressed: _pickAndUploadImage,
            child: Text("Change Profile Picture"),
          ),
            SizedBox(height: 8),
            Text(email, style: TextStyle(color: Colors.grey[700])),
            _buildInfoTile(Icons.lock, 'Password', '************', _showPasswordUpdateDialog),

            SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Divider(),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _deleteAccount,
                child: Text('Delete Account', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
