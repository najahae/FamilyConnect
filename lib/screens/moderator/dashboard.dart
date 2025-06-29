import 'package:familytree/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:familytree/screens/familymember/family_tree.dart';
import 'package:familytree/screens/familymember/event.dart';
import '../moderator/profile.dart';

class ModeratorDashboard extends StatefulWidget {
  final String userId;
  final String email;
  final String familyId;

  ModeratorDashboard({
    required this.userId,
    required this.email,
    required this.familyId,
  });

  @override
  _ModeratorDashboardState createState() => _ModeratorDashboardState();
}

class _ModeratorDashboardState extends State<ModeratorDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = -1;
  }

  void _logout() async {
    await _auth.signOut();
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => WelcomeScreen())
    );
  }

  void _onLogoTap() {
    setState(() {
      _selectedIndex = -1;
    });
  }

  void _onNavBarTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildGreetingPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Hello ${widget.email},",
            style: TextStyle(
                fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          Text(
            "manage your family here",
            style: TextStyle(fontSize: 20, color: Colors.black87),
          ),
          SizedBox(height: 30),
          _buildDashboardButton(
            iconPath: "assets/images/tree.png",
            label: "Family Tree",
            onTap: () {
              setState(() {
                _selectedIndex = 0;
              });
            },
          ),
          SizedBox(height: 20),
          _buildDashboardButton(
            iconPath: "assets/images/events.png",
            label: "Manage Family Events",
            onTap: () {
              setState(() {
                _selectedIndex = 1;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardButton({
    required String iconPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.green[400],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(iconPath, height: 60),
            SizedBox(width: 20),
            Text(
              label,
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_selectedIndex == -1) {
      return _buildGreetingPage(); // Show greeting/dashboard page
    }

    switch (_selectedIndex) {
      case 0:
        return FamilyTreePage(familyID: widget.familyId, role: 'moderator');
      case 1:
        return EventPage(familyID: widget.familyId, role: 'moderator');
      case 2:
        return ModeratorProfilePage(familyId: widget.familyId);
      default:
        return Center(child: Text("Page not found"));
    }
  }

  Widget _customBottomNavBar() {
    List<Map<String, dynamic>> navItems = [
      {"icon": Icons.account_tree, "label": "Tree"},
      {"icon": Icons.event, "label": "Event"},
      {"icon": Icons.person, "label": "Profile"},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green[200],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(navItems.length, (index) {
          bool isSelected = _selectedIndex == index && _selectedIndex != -1;
          return GestureDetector(
            onTap: () => _onNavBarTap(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.green[400] : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(navItems[index]['icon'],
                      color: Colors.white, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    navItems[index]['label'],
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.green[200],
        elevation: 0,
        automaticallyImplyLeading: false,
        title: GestureDetector(
          onTap: _onLogoTap,
          child: CircleAvatar(
            backgroundImage: AssetImage("assets/images/logo.png"),
            backgroundColor: Colors.transparent,
            radius: 25,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              bool? confirmed = await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Confirm Logout'),
                  content: Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Logout'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) _logout();
            },
          ),
        ],
      ),
      body: _buildBodyContent(),
      bottomNavigationBar: _customBottomNavBar(),
    );
  }
}
