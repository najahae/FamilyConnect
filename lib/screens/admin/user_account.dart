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
  String? _selectedFamilyId; // Null means showing family list

  TextEditingController _searchController = TextEditingController();
  List<String> _familyIds = [];
  Map<String, dynamic> _familyData = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadFamilies();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  Future<void> _loadFamilies() async {
    try {
      final snapshot = await _firestore.collection('families').get();
      _familyIds = snapshot.docs.map((doc) => doc.id).toList();
      setState(() {});
    } catch (e) {
      print("Error loading families: $e");
    }
  }

  Future<void> _loadFamilyDetails(String familyId) async {
    try {
      final moderators = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('moderators')
          .get();

      final members = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('family_members')
          .get();

      setState(() {
        _familyData[familyId] = {
          'moderators': moderators.docs.map((doc) => doc.data()).toList(),
          'members': members.docs.map((doc) => doc.data()).toList(),
        };
      });
    } catch (e) {
      print("Error loading family details: $e");
    }
  }

  void _viewFamily(String familyId) {
    setState(() {
      _selectedFamilyId = familyId;
    });
    if (!_familyData.containsKey(familyId)) {
      _loadFamilyDetails(familyId);
    }
  }

  void _goBackToFamilies() {
    setState(() {
      _selectedFamilyId = null;
    });
  }

  void _deleteUser(String userId, String role) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Deletion',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        content: Text(
          'Are you sure you want to delete this user?',
          style: TextStyle(color: Colors.grey[600]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red[600],
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm && _selectedFamilyId != null) {
      try {
        await _firestore
            .collection('families')
            .doc(_selectedFamilyId)
            .collection(role == 'moderator' ? 'moderators' : 'family_members')
            .doc(userId)
            .delete();

        _loadFamilyDetails(_selectedFamilyId!); // Refresh

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("User deleted successfully"),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to delete: ${e.toString()}"),
              backgroundColor: Colors.red[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  void _logout() async {
    bool? confirmed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirm Logout',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: Colors.grey[600]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.green[200],
        foregroundColor: Colors.green[800],
        title: Text(
          _selectedFamilyId == null ? "All Families" : "Family Details",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.green[800],
          ),
        ),
        centerTitle: true,
        leading: _selectedFamilyId != null
            ? IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.green[800]),
          onPressed: _goBackToFamilies,
        )
            : null,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.green[800]),
            onPressed: _logout,
          ),
        ],
      ),
      body: _selectedFamilyId == null
          ? _buildFamilyList()
          : _buildFamilyDetails(),
    );
  }

  Widget _buildFamilyList() {
    final filteredFamilies = _familyIds.where((id) =>
        id.toLowerCase().contains(_searchQuery)).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20.0),
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search families...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.search, color: Colors.green[600]),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(color: Colors.green[400]!, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
          ),
        ),
        Container(
          height: 1,
          color: Colors.grey[200],
        ),
        Expanded(
          child: filteredFamilies.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.family_restroom, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No families found',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredFamilies.length,
            itemBuilder: (context, index) {
              final familyId = filteredFamilies[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.family_restroom, color: Colors.green[700], size: 24),
                  ),
                  title: Text(
                    "Family ID: $familyId",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                      fontSize: 16,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.green[600]),
                  onTap: () => _viewFamily(familyId),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyDetails() {
    if (_selectedFamilyId == null || !_familyData.containsKey(_selectedFamilyId)) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
        ),
      );
    }

    final family = _familyData[_selectedFamilyId]!;
    final moderators = family['moderators'] as List<dynamic>;
    final members = family['members'] as List<dynamic>;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20.0),
          color: Colors.white,
          child: Column(
            children: [
              Text(
                "Family ID: $_selectedFamilyId",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${moderators.length} moderators • ${members.length} members",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 1,
          color: Colors.grey[200],
        ),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  child: TabBar(
                    labelColor: Colors.green[700],
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: Colors.green[600],
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: "Moderators"),
                      Tab(text: "Members"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildUserList(moderators, 'moderator'),
                      _buildUserList(members, 'member'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserList(List<dynamic> users, String role) {
    final filteredUsers = users.where((user) {
      final name = (user['fullName'] ?? user['email'] ?? '').toLowerCase();
      final nickname = (user['nickname'] ?? '').toLowerCase();
      return name.contains(_searchQuery) || nickname.contains(_searchQuery);
    }).toList();

    if (filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              role == 'moderator' ? Icons.admin_panel_settings : Icons.people,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              "No ${role}s found",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
        return _buildUserTile(user, role);
      },
    );
  }

  void _showUserDetails(Map<String, dynamic> user, String role) async {
    final name = user['fullName'] ?? 'Unknown';
    final email = user['email'] ?? 'Not specified';
    final nickname = user['nickname'] ?? 'Not specified';
    final birthDate = user['birthDate'] ?? 'Not specified';
    final gender = user['gender'] ?? 'Not specified';
    final fatherId = user['fatherId'] ?? 'Not specified';
    final motherId = user['motherId'] ?? 'Not specified';
    final imageUrl = user['profileImageUrl'];

    // Handle location data
    final locationData = user['location'] ?? {};
    final latitude = double.tryParse(locationData['latitude']?.toString() ?? '0') ?? 0;
    final longitude = double.tryParse(locationData['longitude']?.toString() ?? '0') ?? 0;
    final hasLocation = latitude != 0 && longitude != 0;

    // Fetch parent names if available
    String fatherName = 'Not specified';
    String motherName = 'Not specified';

    if (_selectedFamilyId != null) {
      if (fatherId.isNotEmpty && fatherId != 'Not specified') {
        final doc = await _firestore
            .collection('families')
            .doc(_selectedFamilyId)
            .collection('family_members')
            .doc(fatherId)
            .get();
        if (doc.exists) {
          fatherName = doc.data()?['fullName'] ?? 'Unknown';
        }
      }

      if (motherId.isNotEmpty && motherId != 'Not specified') {
        final doc = await _firestore
            .collection('families')
            .doc(_selectedFamilyId)
            .collection('family_members')
            .doc(motherId)
            .get();
        if (doc.exists) {
          motherName = doc.data()?['fullName'] ?? 'Unknown';
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(imageUrl),
              )
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: role == 'moderator'
                        ? [Colors.blue[400]!, Colors.blue[600]!]
                        : [Colors.green[400]!, Colors.green[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  role == 'moderator' ? Icons.admin_panel_settings : Icons.person,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (nickname != 'Not specified')
                    Text(
                      '"$nickname"',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserDetailCard(
                icon: Icons.email,
                label: 'Email',
                value: email,
                color: Colors.blue,
              ),
              if (role == 'member') ...[
                _buildUserDetailCard(
                  icon: Icons.face,
                  label: 'Nickname',
                  value: nickname,
                  color: Colors.purple,
                ),
                _buildUserDetailCard(
                  icon: Icons.cake,
                  label: 'Birth Date',
                  value: birthDate,
                  color: Colors.pink,
                ),
                _buildUserDetailCard(
                  icon: gender.toLowerCase() == 'male'
                      ? Icons.male
                      : Icons.female,
                  label: 'Gender',
                  value: gender,
                  color: gender.toLowerCase() == 'male'
                      ? Colors.blue
                      : Colors.pink,
                ),
                _buildUserDetailCard(
                  icon: Icons.man,
                  label: 'Father',
                  value: fatherName,
                  color: Colors.blue,
                ),
                _buildUserDetailCard(
                  icon: Icons.woman,
                  label: 'Mother',
                  value: motherName,
                  color: Colors.pink,
                ),
              ],
              _buildUserDetailCard(
                icon: Icons.admin_panel_settings,
                label: 'Role',
                value: role.toUpperCase(),
                color: role == 'moderator' ? Colors.blue : Colors.green,
              ),
              if (hasLocation) ...[
                _buildUserDetailCard(
                  icon: Icons.location_on,
                  label: 'Location',
                  value: 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
                  color: Colors.red,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
            ),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetailCard({
    required IconData icon,
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[100]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: color[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, String role) {
    final name = user['fullName'] ?? user['email'] ?? 'Unknown';
    final userId = user['id'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: role == 'moderator' ? Colors.blue[100] : Colors.green[100],
          child: Text(
            _getInitials(name),
            style: TextStyle(
              color: role == 'moderator' ? Colors.blue[700] : Colors.green[700],
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (role == 'member' && user['nickname'] != null) ...[
              const SizedBox(height: 4),
              Text(
                "Nickname: ${user['nickname']}",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: role == 'moderator' ? Colors.blue[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                role.toUpperCase(),
                style: TextStyle(
                  color: role == 'moderator' ? Colors.blue[700] : Colors.green[700],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(Icons.visibility, color: Colors.green[600], size: 20),
                onPressed: () => _showUserDetails(user, role),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red[600], size: 20),
                onPressed: () => _deleteUser(userId, role),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(" ");
    if (parts.isEmpty) return "?";
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }
}