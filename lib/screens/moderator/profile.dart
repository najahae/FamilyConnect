import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:async';
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

  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _invitationSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadModeratorData();
    _setupInvitationListener();
  }

  StreamSubscription? _invitationSubscription;

  void _setupInvitationListener() {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      _invitationSubscription = _firestore
          .collection('families')
          .doc(widget.familyId)
          .collection('moderators')
          .doc(uid)
          .snapshots()
          .listen((doc) {
        if (doc.exists && doc.data()?['invitationStatus'] == 'accepted') {
          // Refresh UI if invitation was accepted
          setState(() {});
        }
      });
    }
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
        .child('moderators/${widget.familyId}/$uid/profile.jpg');

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

  Future<void> _handleInvitationResponse(String memberId, bool accepted) async {
    final familyRef = _firestore.collection('families').doc(widget.familyId);

    try {
      // Update the moderators collection
      await familyRef
          .collection('moderators')
          .doc(memberId)
          .update({
        'invitationStatus': accepted ? 'accepted' : 'rejected',
        'isModerator': accepted,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Also update the family_members collection
      await familyRef
          .collection('family_members')
          .doc(memberId)
          .update({
        'isModerator': accepted,
      });

      setState(() {});
    } catch (e) {
      print("Error updating invitation status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update status.")),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getFamilyMembers() async {
    final snapshot = await _firestore
        .collection('families')
        .doc(widget.familyId)
        .collection('family_members')
        .get();

    final allMembers = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        'fullName': data['fullName'] ?? '',
        'nickname': data['nickname'] ?? '',
        'isModerator': data['isModerator'] ?? false,
        'invitedToBeModerator': data['invitedToBeModerator'] ?? false,
        'profileImageUrl': data['profileImageUrl'], // optional
      };
    }).toList();

    if (_searchQuery.isEmpty) return allMembers;

    return allMembers.where((member) {
      final fullName = member['fullName'].toLowerCase();
      final nickname = member['nickname'].toLowerCase();
      final search = _searchQuery.toLowerCase();
      return fullName.contains(search) || nickname.contains(search);
    }).toList();
  }

  Future<void> _assignAsModerator(String memberId) async {
    final familyRef = _firestore.collection('families').doc(widget.familyId);

    try {
      // Update the family_members record
      await familyRef
          .collection('family_members')
          .doc(memberId)
          .update({
        'invitedToBeModerator': true,
        'isModerator': false, // Set to false initially until accepted
      });

      // Get the full data of the member
      DocumentSnapshot memberDoc = await familyRef
          .collection('family_members')
          .doc(memberId)
          .get();

      // Save to moderators collection with invitation status
      if (memberDoc.exists) {
        await familyRef
            .collection('moderators')
            .doc(memberId)
            .set({
          ...memberDoc.data() as Map<String, dynamic>,
          'invitationStatus': 'pending',
          'invitedAt': FieldValue.serverTimestamp(),
          'isModerator': false,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Moderator invite sent!")),
      );

      setState(() {}); // Refresh the UI
    } catch (e) {
      print("Error assigning moderator: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to assign moderator.")),
      );
    }
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

  Widget _buildInvitationStatus(String? status) {
    switch (status) {
      case 'accepted':
        return Text("Accepted", style: TextStyle(color: Colors.green));
      case 'rejected':
        return Text("Rejected", style: TextStyle(color: Colors.red));
      case 'pending':
      default:
        return Text("Pending", style: TextStyle(color: Colors.orange));
    }
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
            SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Assign New Moderator',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Divider(),

            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by full name or nickname',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim();
                });
              },
            ),
            SizedBox(height: 10),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: _getFamilyMembers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text("No matching family members found.");
                }

                final members = snapshot.data!;

                return Column(
                  children: members.map((member) {
                    final alreadyInvited = member['invitedToBeModerator'] == true;
                    final isAlreadyMod = member['isModerator'] == true;
                    final imageUrl = member['profileImageUrl'];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                        child: imageUrl == null ? Icon(Icons.person) : null,
                      ),
                      title: Text(member['fullName']),
                      subtitle: Text(member['nickname']),
                      // In your ListTile builder, modify the trailing widget:
                      trailing: isAlreadyMod
                          ? Text("Moderator", style: TextStyle(color: Colors.green))
                          : alreadyInvited
                          ? member['invitationStatus'] == 'pending'
                          ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.check, color: Colors.green),
                            onPressed: () => _handleInvitationResponse(member['id'], true),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.red),
                            onPressed: () => _handleInvitationResponse(member['id'], false),
                          ),
                        ],
                      )
                          : _buildInvitationStatus(member['invitationStatus'])
                          : ElevatedButton(
                        onPressed: () => _assignAsModerator(member['id']),
                        child: Text("Invite as Moderator"),
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
}
