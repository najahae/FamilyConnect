import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ModeratorProfile extends StatefulWidget {
  final String familyID;

  ModeratorProfile({required this.familyID});

  @override
  _ModeratorProfileState createState() => _ModeratorProfileState();
}

class _ModeratorProfileState extends State<ModeratorProfile> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String? _profileImageBase64;
  String? _originalEmail;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadModeratorData();
  }

  Future<void> _loadModeratorData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _emailController.text = user.email ?? '';
        _originalEmail = user.email;
      });

      try {
        final doc = await _firestore
            .collection('families')
            .doc(widget.familyID)
            .collection('moderators')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          _usernameController.text = data['username'] ?? '';
          _profileImageBase64 = data['profileImage'];
        }
      } catch (e) {
        _errorMessage = "Error loading profile: ${e.toString()}";
      }

      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      if (_emailController.text != _originalEmail) {
        await user.updateEmail(_emailController.text.trim());
      }

      await _firestore
          .collection('families')
          .doc(widget.familyID)
          .collection('moderators')
          .doc(user.uid)
          .update({
        'username': _usernameController.text.trim(),
        'profileImage': _profileImageBase64,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Profile updated successfully")),
      );
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to update profile: ${e.toString()}";
      });
    }
  }

  Future<void> _changePassword() async {
    TextEditingController newPasswordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Change Password"),
        content: TextField(
          controller: newPasswordController,
          obscureText: true,
          decoration: InputDecoration(labelText: "New Password"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
          TextButton(
            onPressed: () async {
              try {
                await _auth.currentUser?.updatePassword(newPasswordController.text.trim());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Password updated")));
              } catch (e) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
              }
            },
            child: Text("Change"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(bool fromCamera) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await File(pickedFile.path).readAsBytes();
      setState(() {
        _profileImageBase64 = base64Encode(bytes);
      });
    }
  }

  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.photo),
                title: Text("Gallery"),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(false);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text("Camera"),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(true);
                },
              ),
            ],
          ),
        );
      },
      child: CircleAvatar(
        radius: 50,
        backgroundColor: Colors.brown[200],
        backgroundImage: _profileImageBase64 != null
            ? MemoryImage(base64Decode(_profileImageBase64!))
            : null,
        child: _profileImageBase64 == null
            ? Icon(Icons.person, size: 50, color: Colors.white)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(body: Center(child: CircularProgressIndicator()));

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
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileImage(),
            SizedBox(height: 20),
            _buildTextField(_usernameController, "Username"),
            _buildTextField(_emailController, "Email"),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text("Save Changes", style: TextStyle(color: Colors.white)),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text("Change Password", style: TextStyle(color: Colors.white)),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_errorMessage!, style: TextStyle(color: Colors.red)),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey), // grey when not focused
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.brown, width: 2), // brown when focused
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
