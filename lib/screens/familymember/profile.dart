import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
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
        imageUrl = data['imageUrl']; // Load from Firestore
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
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${widget.userId}.jpg');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firestore
      await _firestore
          .collection('families')
          .doc(widget.familyId)
          .collection('family_members')
          .doc(widget.userId)
          .update({'imageUrl': downloadUrl});

      setState(() {
        imageUrl = downloadUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile picture updated!')),
      );
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

  Future<void> _pickLocationOnMap() async {
    if (isLoading) return; // prevent opening the dialog before data loads

    LatLng currentLocation = LatLng(latitude, longitude);
    LatLng? newLocation = await showDialog<LatLng>(
      context: context,
      builder: (context) => LocationPickerMap(initialLocation: currentLocation),
    );

    if (newLocation != null) {
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
      });

      setState(() {
        latitude = newLocation.latitude;
        longitude = newLocation.longitude;
      });
    }
  }

  Future<void> _selectParent(String type) async {
    String? selectedId = await showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Select ${type == 'father' ? 'Father' : 'Mother'}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final member = _members[index];
                  return ListTile(
                    title: Text(member['name']),
                    onTap: () => Navigator.pop(context, member['id']),
                  );
                },
              ),
            ),
          ],
        );
      },
    );

    if (selectedId != null) {
      await _firestore
          .collection('families')
          .doc(widget.familyId)
          .collection('family_members')
          .doc(widget.userId)
          .update({
        type == 'father' ? 'fatherId' : 'motherId': selectedId,
      });

      setState(() {
        if (type == 'father') {
          _fatherId = selectedId;
        } else {
          _motherId = selectedId;
        }
      });
    }
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
                  if (_selectedSpouseId != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text("Current Spouse: ${_getNameById(_selectedSpouseId) ?? 'Unknown'}"),
                    ),
                  DropdownButtonFormField<String>(
                    value: _selectedSpouseId,
                    decoration: const InputDecoration(labelText: 'Select Spouse'),
                    items: _availableSpouses
                        .map((spouse) => DropdownMenuItem<String>(
                      value: spouse['id'],
                      child: Text(spouse['name']),
                    ))
                        .toList(),
                    onChanged: (value) async {
                      setState(() {
                        _selectedSpouseId = value;
                      });

                      await _firestore
                          .collection('families')
                          .doc(widget.familyId)
                          .collection('family_members')
                          .doc(widget.userId)
                          .update({'spouseId': value});
                    },
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

class LocationPickerMap extends StatefulWidget {
  final LatLng initialLocation;

  const LocationPickerMap({super.key, required this.initialLocation});

  @override
  _LocationPickerMapState createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  late LatLng selectedLocation;

  @override
  void initState() {
    super.initState();
    selectedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: SizedBox(
        width: 300,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: selectedLocation,
                    zoom: 15,
                  ),
                  onTap: (LatLng pos) {
                    setState(() => selectedLocation = pos);
                  },
                  markers: {
                    Marker(markerId: MarkerId("selected"), position: selectedLocation),
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, selectedLocation);
                },
                child: Text("Confirm Location"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
