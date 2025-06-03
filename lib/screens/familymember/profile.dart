import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FamilyProfilePage extends StatefulWidget {
  final String userId;
  final String familyId;

  const FamilyProfilePage({required this.userId, required this.familyId});

  @override
  _FamilyProfilePageState createState() => _FamilyProfilePageState();
}

class _FamilyProfilePageState extends State<FamilyProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late String fullName = '';
  late String email = '';
  late String birthDate = '';
  late String address = '';

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final doc = await _firestore
        .collection('families')
        .doc(widget.familyId)
        .collection('family_members')
        .doc(widget.userId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        fullName = data['fullName'] ?? '';
        email = data['email'] ?? '';
        birthDate = data['birthDate'] ?? '';
        address = data['address'] ?? '';
        isLoading = false;
      });
    }
  }

  void _showEditDialog(String title, String field, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Enter new $title'),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Save'),
            onPressed: () async {
              await _firestore
                  .collection('families')
                  .doc(widget.familyId)
                  .collection('family_members')
                  .doc(widget.userId)
                  .update({field: controller.text});
              Navigator.pop(context);
              _loadUserData();
            },
          )
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
      await _firestore
          .collection('families')
          .doc(widget.familyId)
          .collection('family_members')
          .doc(widget.userId)
          .delete();

      await _auth.currentUser?.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account deleted successfully')),
        );
        Navigator.of(context).pop();
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
      return Center(child: CircularProgressIndicator());
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
            CircleAvatar(radius: 50, child: Icon(Icons.person, size: 60)),
            SizedBox(height: 8),
            Text(fullName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(email, style: TextStyle(color: Colors.grey[700])),
            SizedBox(height: 20),

            Align(
              alignment: Alignment.centerLeft,
              child: Text('Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Divider(),

            _buildInfoTile(Icons.person, 'Full Name', fullName, () => _showEditDialog('Full Name', 'fullName', fullName)),
            _buildInfoTile(Icons.calendar_today, 'Birth Date', birthDate, () => _showEditDialog('Birth Date', 'birthDate', birthDate)),
            _buildInfoTile(Icons.lock, 'Password', '************', () => {}),
            _buildInfoTile(Icons.location_on, 'Address', address, () => _showEditDialog('Address', 'address', address)),

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
