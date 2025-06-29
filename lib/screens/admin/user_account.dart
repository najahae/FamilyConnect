import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:familytree/screens/welcome_screen.dart';

class UserAccountsPage extends StatefulWidget {
  const UserAccountsPage({super.key});

  @override
  State<UserAccountsPage> createState() => _UserAccountsPageState();
}

class _UserAccountsPageState extends State<UserAccountsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  Future<Map<String, dynamic>> _fetchFamilyData() async {
    try {
      print("⏳ STARTING to fetch family data...");
      final familiesSnapshot = await _firestore.collection('families').get();
      print("📦 Families found: ${familiesSnapshot.docs.length}");

      if (familiesSnapshot.docs.isEmpty) return {};

      Map<String, dynamic> result = {};

      await Future.wait(familiesSnapshot.docs.map((family) async {
        final familyId = family.id;
        print("➡️ Fetching data for familyId: $familyId");

        final moderatorsSnapshot = await _firestore
            .collection('families')
            .doc(familyId)
            .collection('moderators')
            .get();

        final membersSnapshot = await _firestore
            .collection('families')
            .doc(familyId)
            .collection('family_members')
            .get();

        result[familyId] = {
          'moderators': moderatorsSnapshot.docs.map((doc) => {
            'id': doc.id,
            'email': doc['email'] ?? '',
          }).toList(),
          'members': membersSnapshot.docs.map((doc) => {
            'id': doc.id,
            'fullName': doc['fullName'] ?? '',
            'nickname': doc['nickname'] ?? '',
          }).toList(),
        };
      }).toList());

      print("✅ FETCH COMPLETE. Result: $result");
      return result;
    } catch (e, stack) {
      print("🔥 ERROR in _fetchFamilyData(): $e");
      print(stack);
      return {};
    }
  }

  void _deleteUser(String familyId, String role, String userId) async {
    await _firestore
        .collection('families')
        .doc(familyId)
        .collection(role)
        .doc(userId)
        .delete();
    setState(() {}); // refresh
  }

  void _editUser(String familyId, String role, String userId) {
    // TODO: Navigate to Edit screen (not implemented here)
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Edit user $userId from $familyId ($role)"),
    ));
  }

  void _logout() async {
    bool? confirmed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
          child: AppBar(
            backgroundColor: Colors.green[200],
            title: const Text("User Accounts"),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _logout,
              ),
            ],
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchFamilyData(),
        builder: (context, snapshot) {
          print("Snapshot state: ${snapshot.connectionState}");
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print("🔥 Snapshot error: ${snapshot.error}");
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No user accounts found."));
          }

          final families = snapshot.data!;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, nickname, or email',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: families.entries.map((entry) {
                    final familyId = entry.key;
                    final moderators = (entry.value['moderators'] as List).where((mod) {
                      final value = (mod['email'] ?? '').toLowerCase();
                      return value.contains(_searchQuery);
                    }).toList();

                    final members = (entry.value['members'] as List).where((mem) {
                      final fullName = (mem['fullName'] ?? '').toLowerCase();
                      final nickname = (mem['nickname'] ?? '').toLowerCase();
                      return fullName.contains(_searchQuery) || nickname.contains(_searchQuery);
                    }).toList();

                    // If both filtered lists are empty, don't show the family section
                    if (moderators.isEmpty && members.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Family ID: $familyId", style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),

                        if (moderators.isNotEmpty) ...[
                          Text("Moderator", style: const TextStyle(fontWeight: FontWeight.w500)),
                          ...moderators.map((mod) => _buildUserTile(
                            initials: _getInitials(mod['email']),
                            name: mod['email'],
                            familyId: familyId,
                            userId: mod['id'],
                            role: 'moderators',
                          )),
                          const SizedBox(height: 10),
                        ],

                        if (members.isNotEmpty) ...[
                          Text("Family Members", style: const TextStyle(fontWeight: FontWeight.w500)),
                          ...members.map((mem) => _buildUserTile(
                            initials: _getInitials(mem['fullName']),
                            name: mem['fullName'],
                            familyId: familyId,
                            userId: mem['id'],
                            role: 'family_members',
                          )),
                        ],

                        const Divider(height: 30),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserTile({
    required String initials,
    required String name,
    required String familyId,
    required String userId,
    required String role,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.red[200],
            child: Text(initials, style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14))),
          TextButton(
            onPressed: () => _editUser(familyId, role, userId),
            child: const Text("Edit", style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () => _deleteUser(familyId, role, userId),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(" ");
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }
}
