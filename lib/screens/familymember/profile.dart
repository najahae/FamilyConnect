import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

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

  String? imageUrl;
  String fullName = '';
  String nickname = '';
  String email = '';
  String birthDate = '';
  String gender = '';
  String _fatherId = '';
  String _motherId = '';
  double latitude = 3.1390;
  double longitude = 101.6869;
  String? _getNameById(String? id) {
    return _members.firstWhere(
          (m) => m['id'] == id,
      orElse: () => {'name': null},
    )['name'];
  }
  String? _selectedSpouseId;

  bool isLoading = true;
  bool showCurrent = false;
  bool showNew = false;
  bool showConfirm = false;
  bool _hasSpouse = false;

  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _availableSpouses = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    loadFamilyMembers();
    initSpouseData();
  }

  Future<List<LatLng>> _getLocationHistory() async {
    final doc = await _firestore
        .collection('families')
        .doc(widget.familyId)
        .collection('family_members')
        .doc(widget.userId)
        .get();

    final data = doc.data() ?? {};
    final history = data['locationHistory'] as List? ?? [];
    print('Raw history entries: ${history.length}'); // See how many raw entries
    print('Raw history data: $history'); // Print the raw data

    final List<LatLng> distinctHistory = [];
    final Set<String> seenLocations = {}; // Use a Set to track seen locations

    for (var loc in history) {
      try {
        final lat = double.parse(loc['latitude'].toString());
        final lng = double.parse(loc['longitude'].toString());
        final latLng = LatLng(lat, lng);
        // Create a unique key for comparison (e.g., rounded to 6 decimal places)
        final key = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';

        if (!seenLocations.contains(key)) {
          distinctHistory.add(latLng);
          seenLocations.add(key);
        }
      } catch (e) {
        print("Error parsing location history entry: $e, entry: $loc");
        // Optionally, log this error to crashlytics or similar
      }
    }
    print('Distinct history locations: ${distinctHistory.length}');
    print('Distinct history data: $distinctHistory'); // Print the processed LatLng list
    return distinctHistory;
  }

  Future<void> _pickLocationOnMap() async {
    if (isLoading) return; // Prevent interaction if data is still loading

    var status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permission denied. Cannot fetch current location.')),
        );
      }
    }

    try {
      final currentLocation = LatLng(latitude, longitude);
      final previousLocations = await _getLocationHistory();

      LatLng? newLocation = await showDialog<LatLng>(
        context: context,
        builder: (context) => LocationPickerDialog(
          currentLocation: currentLocation,
          previousLocations: previousLocations,
          hasLocationPermission: status.isGranted, // Pass permission status
        ),
      );

      if (newLocation != null) {
        // Only update if the new location is different from the current one
        if (newLocation.latitude != latitude || newLocation.longitude != longitude) {
          // Update Firestore
          await _firestore
              .collection('families')
              .doc(widget.familyId)
              .collection('family_members')
              .doc(widget.userId)
              .update({
            'location': {
              'latitude': newLocation.latitude,
              'longitude': newLocation.longitude,
            },
            'locationHistory': FieldValue.arrayUnion([{
              'latitude': newLocation.latitude,
              'longitude': newLocation.longitude,
              'timestamp': DateTime.now().toIso8601String(),
            }]),
          });

          // Update local state
          setState(() {
            latitude = newLocation.latitude;
            longitude = newLocation.longitude;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location updated successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location is already set to this point.')),
          );
        }
      }
    } catch (e) {
      print('Failed to update location: $e'); // Log the error for debugging
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update location: ${e.toString()}')),
      );
    }
  }

  Future<void> initSpouseData() async {
    final doc = await _firestore
        .collection('families')
        .doc(widget.familyId)
        .collection('family_members')
        .doc(widget.userId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _hasSpouse = data['spouseId'] != null;
        _selectedSpouseId = data['spouseId'];
      });
      await _loadSpouseOptions(widget.userId, data['gender'] ?? '');
    }
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
        imageUrl = data['profileImageUrl']; // Load from Firestore
        fullName = data['fullName'] ?? '';
        nickname = data['nickname'] ?? '';
        email = data['email'] ?? '';
        birthDate = data['birthDate'] ?? '';
        gender = data['gender'] ?? '';
        _fatherId = data['fatherId'] ?? '';
        _motherId = data['motherId'] ?? '';
        Map<String, dynamic> locationData = data['location'] ?? {};
        latitude = double.tryParse(locationData['latitude'].toString()) ?? 3.1390;
        longitude = double.tryParse(locationData['longitude'].toString()) ?? 101.6869;
        isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      setState(() => isLoading = true);
      final file = File(pickedFile.path);
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw 'User not authenticated';

      // Upload to consistent path
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('family_members/${widget.familyId}/$uid/profile.jpg');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      // Save to Firestore with CORRECT field name
      await _firestore
          .collection('families')
          .doc(widget.familyId)
          .collection('family_members')
          .doc(uid)
          .update({'profileImageUrl': downloadUrl});

      setState(() {
        imageUrl = downloadUrl; // Or cachedUrl if using Option B
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Upload error: $e');
    }
  }

  Future<void> loadFamilyMembers() async {
    final snapshot = await _firestore
        .collection('families')
        .doc(widget.familyId)
        .collection('family_members')
        .get();

    setState(() {
      _members = snapshot.docs
          .where((doc) => doc.id != widget.userId)  // avoid self
          .map((doc) {
        return {
          'id': doc.id,
          'name': doc['fullName'] ?? '',
        };
      }).toList();
    });
  }

  Future<void> _selectSpouse() async {
    // First fetch all members with their genders
    final membersSnapshot = await _firestore
        .collection('families')
        .doc(widget.familyId)
        .collection('family_members')
        .get();

    // Filter based on opposite gender
    final filteredByGender = membersSnapshot.docs.where((doc) {
      return doc.id != widget.userId && // exclude self
          (doc['gender'] ?? '').toLowerCase() != gender.toLowerCase(); // opposite gender
    }).toList();

    String? selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        TextEditingController searchController = TextEditingController();
        List<Map<String, dynamic>> filteredMembers = filteredByGender.map((doc) {
          return {
            'id': doc.id,
            'name': doc['fullName'] ?? 'Unknown',
            'gender': doc['gender'] ?? '',
            'email': doc['email'] ?? '',
          };
        }).toList();
        List<Map<String, dynamic>> displayMembers = List.from(filteredMembers);

        return StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Select Spouse",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        displayMembers = filteredMembers.where((member) {
                          return member['name'].toLowerCase().contains(value.toLowerCase());
                        }).toList();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(),
                // None option
                ListTile(
                  leading: const Icon(Icons.cancel, color: Colors.grey),
                  title: const Text('None'),
                  onTap: () => Navigator.pop(context, ''),
                ),
                const Divider(),
                if (displayMembers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No matching members found'),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: displayMembers.length,
                      itemBuilder: (context, index) {
                        final member = displayMembers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: member['gender'].toLowerCase() == 'male'
                                ? Colors.blue[100]
                                : Colors.pink[100],
                            child: Icon(
                              member['gender'].toLowerCase() == 'male'
                                  ? Icons.male
                                  : Icons.female,
                              color: member['gender'].toLowerCase() == 'male'
                                  ? Colors.blue
                                  : Colors.pink,
                            ),
                          ),
                          title: Text(member['name']),
                          subtitle: Text(member['email']),
                          trailing: _selectedSpouseId == member['id']
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          onTap: () => Navigator.pop(context, member['id']),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );

    // Update Firestore with selectedId (which could be empty string for 'None')
    await _firestore
        .collection('families')
        .doc(widget.familyId)
        .collection('family_members')
        .doc(widget.userId)
        .update({
      'spouseId': selectedId == '' ? FieldValue.delete() : selectedId,
    });

    setState(() {
      _selectedSpouseId = selectedId == '' ? null : selectedId;
    });
  }

  Future<void> _loadSpouseOptions(String currentMemberId, String gender) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyId)
        .collection('family_members')
        .get();

    setState(() {
      _availableSpouses = snapshot.docs
          .where((doc) =>
      doc.id != currentMemberId && // exclude self
          (doc['gender'] ?? '') != gender) // opposite gender
          .map((doc) => {
        'id': doc.id,
        'name': doc['fullName'] ?? '[Unnamed]',
        'email': doc['email'],
        'gender': doc['gender'],
      })
          .toList();
    });
  }

  void _showEditDialog(String title, String field, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    DateTime? selectedDate = DateTime.tryParse(currentValue);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $title'),
        content: field == 'birthDate'
            ? StatefulBuilder(
          builder: (context, setState) => TextField(
            controller: TextEditingController(
                text: selectedDate != null
                    ? "${selectedDate!.toLocal()}".split(' ')[0]
                    : currentValue),
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Select Date',
              suffixIcon: IconButton(
                icon: Icon(Icons.calendar_today),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDate = picked;
                    });
                  }
                },
              ),
            ),
          ),
        )
            : TextField(
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
              final newValue = field == 'birthDate'
                  ? (selectedDate != null
                  ? selectedDate!.toIso8601String().split('T')[0]
                  : currentValue)
                  : controller.text;

              await _firestore
                  .collection('families')
                  .doc(widget.familyId)
                  .collection('family_members')
                  .doc(widget.userId)
                  .update({field: newValue});

              Navigator.pop(context);
              _loadUserData();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _selectParent(String type) async {
    // First fetch all members with their genders
    final membersSnapshot = await _firestore
        .collection('families')
        .doc(widget.familyId)
        .collection('family_members')
        .get();

    // Filter based on gender (male for father, female for mother)
    final filteredByGender = membersSnapshot.docs.where((doc) {
      final gender = doc['gender']?.toString().toLowerCase() ?? '';
      return type == 'father'
          ? gender == 'male'
          : gender == 'female';
    }).toList();

    String? selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        TextEditingController searchController = TextEditingController();
        List<Map<String, dynamic>> filteredMembers = filteredByGender.map((doc) {
          return {
            'id': doc.id,
            'name': doc['fullName'] ?? 'Unknown',
          };
        }).toList();
        List<Map<String, dynamic>> displayMembers = List.from(filteredMembers);

        return StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Select ${type == 'father' ? 'Father' : 'Mother'}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        displayMembers = filteredMembers.where((member) {
                          return member['name'].toLowerCase().contains(value.toLowerCase());
                        }).toList();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(),
                // None option
                ListTile(
                  leading: const Icon(Icons.cancel, color: Colors.grey),
                  title: const Text('None'),
                  onTap: () => Navigator.pop(context, ''),
                ),
                const Divider(),
                if (displayMembers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No matching members found'),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: displayMembers.length,
                      itemBuilder: (context, index) {
                        final member = displayMembers[index];
                        return ListTile(
                          leading: Icon(
                            type == 'father' ? Icons.male : Icons.female,
                            color: type == 'father' ? Colors.blue : Colors.pink,
                          ),
                          title: Text(member['name']),
                          trailing: (type == 'father' ? _fatherId : _motherId) == member['id']
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          onTap: () => Navigator.pop(context, member['id']),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );

    // Update Firestore with selectedId (which could be empty string for 'None')
    await _firestore
        .collection('families')
        .doc(widget.familyId)
        .collection('family_members')
        .doc(widget.userId)
        .update({
      type == 'father' ? 'fatherId' : 'motherId': selectedId == '' ? FieldValue.delete() : selectedId,
    });

    setState(() {
      if (type == 'father') {
        _fatherId = selectedId == '' ? '' : selectedId ?? '';
      } else {
        _motherId = selectedId == '' ? '' : selectedId ?? '';
      }
    });
  }

  Future<void> _selectGender() async {
    final selectedGender = await showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16),
            Text("Select Gender", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Divider(),
            ListTile(
              leading: Icon(Icons.male, color: Colors.blue),
              title: Text('Male'),
              onTap: () => Navigator.pop(context, 'Male'),
            ),
            ListTile(
              leading: Icon(Icons.female, color: Colors.pink),
              title: Text('Female'),
              onTap: () => Navigator.pop(context, 'Female'),
            ),
            SizedBox(height: 10),
          ],
        );
      },
    );

    if (selectedGender != null && selectedGender != gender) {
      await _firestore
          .collection('families')
          .doc(widget.familyId)
          .collection('family_members')
          .doc(widget.userId)
          .update({'gender': selectedGender});

      setState(() {
        gender = selectedGender;
      });
    }
  }

  Future<bool> reauthenticateUser(String email, String currentPassword) async {
    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      await FirebaseAuth.instance.currentUser!
          .reauthenticateWithCredential(credential);

      return true;
    } catch (e) {
      print('Reauthentication failed: $e');
      return false;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await FirebaseAuth.instance.currentUser!.updatePassword(newPassword);
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
          builder: (context, setState) {
            return Column(
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
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final current = currentPasswordController.text.trim();
              final newPass = newPasswordController.text.trim();
              final confirm = confirmPasswordController.text.trim();
              final email = FirebaseAuth.instance.currentUser?.email ?? '';

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

              bool success = await reauthenticateUser(email, current);
              if (success) {
                await updatePassword(newPass);
                Navigator.pop(context); // Close dialog
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
            GestureDetector(
              onTap: _pickAndUploadImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[300],
                backgroundImage:
                imageUrl != null ? NetworkImage(imageUrl!) : null,
                child: imageUrl == null
                    ? Icon(Icons.camera_alt, size: 40, color: Colors.white)
                    : null,
              ),
            ),
            SizedBox(height: 8),
            Text(fullName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(email, style: TextStyle(color: Colors.grey[700])),
            SizedBox(height: 20),

            Align(
              alignment: Alignment.centerLeft,
              child: Text('Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Divider(),
            SwitchListTile(
              title: const Text("Do you have a spouse?"),
              secondary: const Icon(Icons.favorite),
              value: _hasSpouse,
              onChanged: (value) async {
                setState(() {
                  _hasSpouse = value;
                  if (!value) _selectedSpouseId = null;
                });

                if (!value) {
                  await _firestore
                      .collection('families')
                      .doc(widget.familyId)
                      .collection('family_members')
                      .doc(widget.userId)
                      .update({'spouseId': FieldValue.delete()});
                } else {
                  await _loadSpouseOptions(widget.userId, gender);
                }
              },
            ),
            if (_hasSpouse)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.pink),
                    title: const Text('Spouse'),
                    subtitle: Text(
                      _selectedSpouseId != null
                          ? _getNameById(_selectedSpouseId) ?? 'Unknown'
                          : 'Not selected',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: _selectSpouse,
                  ),
                  if (_selectedSpouseId != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
                      child: OutlinedButton(
                        onPressed: () async {
                          await _firestore
                              .collection('families')
                              .doc(widget.familyId)
                              .collection('family_members')
                              .doc(widget.userId)
                              .update({'spouseId': FieldValue.delete()});
                          setState(() {
                            _selectedSpouseId = null;
                          });
                        },
                        child: const Text('Remove Spouse'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                ],
              ),
            _buildInfoTile(Icons.person, 'Full Name', fullName, () => _showEditDialog('Full Name', 'fullName', fullName)),
            _buildInfoTile(Icons.person_pin, 'Nickname', nickname, () => _showEditDialog('Nickname', 'nickname', nickname)),
            _buildInfoTile(Icons.wc, 'Gender', gender.isNotEmpty ? gender : 'Not selected', _selectGender),
            _buildInfoTile(Icons.male, 'Father', _getNameById(_fatherId) ?? 'Not selected', () => _selectParent('father')),
            _buildInfoTile(Icons.female, 'Mother', _getNameById(_motherId) ?? 'Not selected', () => _selectParent('mother')),
            _buildInfoTile(Icons.calendar_today, 'Birth Date', birthDate, () => _showEditDialog('Birth Date', 'birthDate', birthDate)),
            _buildInfoTile(Icons.location_on, 'Current Residence', 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}', _pickLocationOnMap),
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

// New LocationPickerDialog widget
class LocationPickerDialog extends StatefulWidget {
  final LatLng currentLocation;
  final List<LatLng> previousLocations;
  final bool hasLocationPermission;

  const LocationPickerDialog({
    super.key,
    required this.currentLocation,
    required this.previousLocations,
    this.hasLocationPermission = false,
  });

  @override
  _LocationPickerDialogState createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  late LatLng _selectedLocation;
  bool _loadingCurrentLocation = false;
  Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  BitmapDescriptor? _selectedMarkerIcon;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.currentLocation;
    _loadMarkerIcons().then((_) => _updateMarkers());
  }

  Future<void> _loadMarkerIcons() async {
    _selectedMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _updateMarkers() {
    final markers = <Marker>{};

    // Add marker for selected location
    markers.add(
      Marker(
        markerId: const MarkerId("selected"),
        position: _selectedLocation,
        icon: _selectedMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: "Selected Location"),
        zIndex: 2,
      ),
    );

    // Add markers for previous locations
    for (var i = 0; i < widget.previousLocations.length; i++) {
      final loc = widget.previousLocations[i];
      markers.add(
        Marker(
          markerId: MarkerId("history_$i"),
          position: loc,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: "Previous Location ${i + 1}"),
          zIndex: 1,
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _loadingCurrentLocation = true);

    try {
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
      );

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _updateMarkers();
      });

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation, 16),
        duration: const Duration(milliseconds: 700),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: ${e.toString()}')),
      );
    } finally {
      setState(() => _loadingCurrentLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Select Location',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Map with Current Location Button
            Flexible(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 300,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _selectedLocation,
                          zoom: 15,
                        ),
                        onMapCreated: (controller) {
                          _mapController = controller;
                          _mapController!.animateCamera(
                            CameraUpdate.newLatLngZoom(_selectedLocation, 15),
                          );
                          _updateMarkers(); // Call this after map is created
                        },
                        markers: _markers,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        onTap: (pos) {
                          setState(() {
                            _selectedLocation = pos;
                            _updateMarkers();
                          });
                        },
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: FloatingActionButton(
                        mini: true,
                        heroTag: 'currentLocationFAB',
                        backgroundColor: Colors.white,
                        onPressed: _getCurrentLocation,
                        child: _loadingCurrentLocation
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : const Icon(Icons.my_location, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Location Coordinates Display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.location_pin, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}\n'
                          'Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),

            // Location History List
            if (widget.previousLocations.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.history, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Previous Locations',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: widget.previousLocations.length,
                    itemBuilder: (context, index) {
                      final loc = widget.previousLocations[index];
                      final isSelected = _selectedLocation == loc;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: isSelected
                              ? BorderSide(color: Theme.of(context).primaryColor)
                              : BorderSide.none,
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            isSelected ? Icons.location_on : Icons.location_on_outlined,
                            color: isSelected ? Colors.red : Colors.grey,
                          ),
                          title: Text(
                            'Location ${index + 1}',
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}',
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            setState(() {
                              _selectedLocation = loc;
                              _updateMarkers();
                            });
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(loc, 16),
                              duration: const Duration(milliseconds: 500),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            // Confirm Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, _selectedLocation),
                  child: const Text('CONFIRM LOCATION'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}