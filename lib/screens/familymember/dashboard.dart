import 'package:familytree/screens/familymember/event.dart';
import 'package:familytree/screens/familymember/family_tree.dart';
import 'package:familytree/screens/familymember/profile.dart';
import 'package:familytree/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../familymember/maps.dart';
import '../familymember/notifications.dart';

class FamilyMemberDashboard extends StatefulWidget {
  final String userId;
  final String familyId;
  final Map<String, dynamic> userData;

  const FamilyMemberDashboard({
    Key? key,
    required this.userId,
    required this.familyId,
    required this.userData,
  }) : super(key: key);

  @override
  _FamilyMemberDashboardState createState() => _FamilyMemberDashboardState();
}

class _FamilyMemberDashboardState extends State<FamilyMemberDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? familyID;
  String? email;
  String? username;
  int _selectedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        email = user.email;
      });

      var snapshot = await FirebaseFirestore.instance.collection('families').get();

      for (var doc in snapshot.docs) {
        var member = await FirebaseFirestore.instance
            .collection('families')
            .doc(doc.id)
            .collection('family_members')
            .doc(user.uid)
            .get();

        if (member.exists) {
          setState(() {
            familyID = doc.id;
            username = member.data()?['fullName'] ?? user.email;
          });
          break;
        }
      }
    }
  }

  void _logout() async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => WelcomeScreen()),
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
          Text("Get to know your own family tree,",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text("${username ?? ''}",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic)),
          SizedBox(height: 20),
          _buildFeatureCard(
            imagePath: "assets/images/tree.png",
            title: "Create your",
            subtitle: "Family Tree",
            onTap: () {
              if (familyID != null) {
                setState(() {
                  _selectedIndex = 0;
                });
              }
            },
          ),
          SizedBox(height: 30),
          _buildFeatureCard(
            imagePath: "assets/images/map.png",
            title: "Observe your",
            subtitle: "Family Map",
            onTap: () {
              if (familyID != null) {
                setState(() {
                  _selectedIndex = 1;
                });
              }
            },
          ),
          SizedBox(height: 30),
          _buildFeatureCard(
            imagePath: "assets/images/events.png",
            title: "Save the date for your",
            subtitle: "Family Events",
            onTap: () {
              setState(() {
                _selectedIndex = 2;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String imagePath,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.green[400],
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Image.asset(imagePath, height: 70),
            SizedBox(width: 16),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.white, fontSize: 16)),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_selectedIndex == -1) {
      return _buildGreetingPage();
    }

    User? user = _auth.currentUser;
    if (user == null || familyID == null) {
      return Center(child: CircularProgressIndicator());
    }

    switch (_selectedIndex) {
      case 0:
        return FamilyTreePage(familyID: familyID!);
      case 1:
        return FamilyMapPage(familyID: familyID!);
      case 2:
        return EventPage(familyID: familyID!);
      case 3:
        return FamilyProfilePage(familyId: familyID!, userId: user.uid);
      default:
        return Center(child: Text("Page not found"));
    }
  }

  Widget _customBottomNavBar() {
    List<Map<String, dynamic>> navItems = [
      {"icon": Icons.account_tree, "label": "Tree"},
      {"icon": Icons.map, "label": "Map"},
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
                  Icon(navItems[index]['icon'], color: Colors.white, size: 24),
                  SizedBox(height: 4),
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
            icon: Icon(Icons.notifications),
            onPressed: () {
              if (familyID == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Family ID not loaded yet!")),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationsPage(familyID: familyID!),
                ),
              );
            },
          ),
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
