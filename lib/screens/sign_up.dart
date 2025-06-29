import 'package:familytree/screens/login_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';


class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _familyIdController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _fatherIdController = TextEditingController();
  final TextEditingController _motherIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String? _selectedGender;
  String? _selectedSpouseId;
  String? _familyID;
  String? _errorMessage;
  String _userType = "Moderator";

  LatLng? _pickedLocation;
  CameraPosition? _initialCameraPosition;
  late GoogleMapController _mapController;

  bool _isLoading = false;
  bool _isFamilyIdValid = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _hasSpouse = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, String>> _members = [];
  List<Map<String, dynamic>> _availableSpouses = [];

  @override
  void initState() {
    super.initState();
    _fetchExistingMembers();
    _familyIdController.addListener(() {
      setState(() {
        _isFamilyIdValid = false;
      });
    });
    _setInitialLocation();
  }

  Future<void> _fetchExistingMembers() async {
    final familyId = _familyIdController.text.trim();

    if (familyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a Family ID first.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('family_members')
          .get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No family members found for this Family ID.')),
        );
      } else {
        setState(() {
          _members = snapshot.docs
              .map((doc) => {'id': doc.id, 'name': doc['fullName'].toString()})
              .toList();
        });
      }
    } catch (e) {
      print('Error fetching members: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching family members.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _searchFamilyID() async {
    final familyId = _familyIdController.text.trim();
    final doc = await FirebaseFirestore.instance.collection('families').doc(familyId).get();

    if (doc.exists) {
      setState(() {
        _isFamilyIdValid = true;
        _familyID = familyId;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Family ID found!")),
      );
      _fetchExistingMembers(); // fetch data bila family ID valid
    } else {
      setState(() {
        _isFamilyIdValid = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Family ID not found!")),
      );
    }
  }

  Future<void> _loadSpouseOptions(String familyId, String selectedGender) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('family_members')
        .get();

    setState(() {
      _availableSpouses = snapshot.docs
          .where((doc) => (doc.data()['gender'] ?? '') != selectedGender)
          .map((doc) => {
        'id': doc.id,
        'name': doc.data()['fullName'] ?? '[Unnamed]',
      })
          .toList();
    });
  }

  void _showFamilyIdInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('What is a Family ID?'),
        content: Text(
          'A Family ID is a unique code created by the Moderator. '
              'You must enter a valid Family ID to join your family tree.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void _openMapDialog() async {
    LatLng? selected = await showDialog<LatLng>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: double.infinity,
          height: 400,
          child: _MapPickerDialog(
            initialLocation: _pickedLocation ?? LatLng(3.1390, 101.6869),
          ),
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _pickedLocation = selected;
      });
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    // Check permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    // Get current position
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _setInitialLocation() async {
    Position position = await _determinePosition();
    setState(() {
      _initialCameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 14.0,
      );
    });
  }

  Future<void> _selectBirthDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _birthDateController.text = "${pickedDate.toLocal()}".split(' ')[0];
      });
    }
  }

  Future<void> _signUp() async {
    String familyID = _familyIdController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();
    String fullName = _fullNameController.text.trim();
    String nickname = _nicknameController.text.trim();
    String gender = _selectedGender ?? '';
    String fatherId = _fatherIdController.text.trim();
    String motherId = _motherIdController.text.trim();
    String birthDate = _birthDateController.text.trim();

    if (familyID.isEmpty || password.isEmpty || confirmPassword.isEmpty || (_userType == "Family member" && (fullName.isEmpty || gender.isEmpty || birthDate.isEmpty))) {
      setState(() {
        _errorMessage = "All fields are required.";
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = "Password must be at least 6 characters long.";
      });
      return;
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      setState(() {
        _errorMessage = "Password must contain at least one uppercase letter.";
      });
      return;
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      setState(() {
        _errorMessage = "Password must contain at least one number.";
      });
      return;
    }

    if (!RegExp(r'[_!@#\$&*~]').hasMatch(password)) {
      setState(() {
        _errorMessage = "Password must contain at least one special character (_!@#\$&*~)";
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = "Passwords do not match.";
      });
      return;
    }

    try {
      final familyDoc = _firestore.collection('families').doc(familyID);
      final familySnapshot = await familyDoc.get();

      if (_userType == "Moderator") {
        if (familySnapshot.exists) {
          setState(() {
            _errorMessage = "This Family ID already exists. Choose a different one.";
          });
          return;
        } else {
          await familyDoc.set({'createdAt': FieldValue.serverTimestamp()});
        }
      } else {
        if (!familySnapshot.exists) {
          setState(() {
            _errorMessage = "Family ID not found. Please ask your moderator.";
          });
          return;
        }
      }
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String collection = _userType == "Moderator" ? "moderators" : "family_members";

      Map<String, dynamic> userData = {
        'email': email,
        'role': _userType,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_userType == "Family member") {
        if (!_isFamilyIdValid) {
          setState(() {
            _errorMessage = "Please verify a valid Family ID before signing up.";
          });
          return;
        }

        userData.addAll({
          'fullName': fullName,
          'nickname': nickname,
          'gender': gender,
          'spouseId': _hasSpouse ? _selectedSpouseId : null,
          'birthDate': birthDate,
          'fatherId': fatherId.isNotEmpty ? fatherId : null,
          'motherId': motherId.isNotEmpty ? motherId : null,
        });

        if (_pickedLocation != null) {
          userData['location'] = {
            'latitude': _pickedLocation!.latitude,
            'longitude': _pickedLocation!.longitude,
          };
        } else {
          setState(() {
            _errorMessage = "Please pin your location on the map.";
          });
          return;
        }
      }

      await _firestore
          .collection('families')
          .doc(familyID)
          .collection(collection)
          .doc(userCredential.user!.uid)
          .set(userData);

      // After saving to Firestore
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      String? token = await messaging.getToken();
      if (token != null) {
        await _firestore
            .collection('families')
            .doc(familyID)
            .collection(collection)
            .doc(userCredential.user!.uid)
            .update({
          'fcmToken': token,
        });
      }


      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen(familyID: _familyIdController.text.trim()),
        ),
      );
    } catch (e) {
      print('Sign up error: $e');
      setState(() {
        _errorMessage = "Something went wrong. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[100],
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 50),
              Image.asset("assets/images/logo.png", height: 180, width: 180),
              SizedBox(height: 20),
              Text("CREATE NEW ACCOUNT", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Already registered? "),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoginScreen(),
                        ),
                      );
                    },
                    child: Text(
                      "Login here",
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5)],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Radio(
                          value: "Family member",
                          groupValue: _userType,
                          onChanged: (value) => setState(() => _userType = value.toString()),
                          activeColor: Colors.green,
                        ),
                        Text("Family member"),
                        Radio(
                          value: "Moderator",
                          groupValue: _userType,
                          onChanged: (value) => setState(() => _userType = value.toString()),
                          activeColor: Colors.green,
                        ),
                        Text("Moderator"),
                      ],
                    ),
                    if (_userType == "Family member") ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextField(
                              _familyIdController,
                              "Family ID",
                              suffixIcon: IconButton(
                                icon: Icon(Icons.help_outline, color: Colors.grey),
                                onPressed: () {
                                  _showFamilyIdInfo(); // Function to explain Family ID
                                },
                              ),
                            ),
                          ),
                          if (_isFamilyIdValid)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0, top: 12.0),
                              child: Icon(Icons.check_circle, color: Colors.green),
                            )
                          else if (!_isFamilyIdValid && _familyIdController.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0, top: 12.0),
                              child: Icon(Icons.cancel, color: Colors.red),
                            ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: _searchFamilyID,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.brown,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Verify Family ID', style: TextStyle(color: Colors.white)),
                      ),
                      if (_isLoading) CircularProgressIndicator(),
                      if (_isFamilyIdValid) ...[
                      _buildTextField(_fullNameController, "Full Name"),
                        _buildTextField(_nicknameController, "Nickname (Optional)"),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DropdownButtonFormField<String>(
                          value: _selectedGender,
                          onChanged: (value) {
                            setState(() {
                              _selectedGender = value;
                            });
                          },
                          items: ['Male', 'Female']
                              .map((gender) => DropdownMenuItem<String>(
                            value: gender,
                            child: Text(gender),
                          ))
                              .toList(),
                          decoration: InputDecoration(
                            labelText: 'Gender',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.brown, width: 2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            floatingLabelStyle: TextStyle(
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                        Row(
                          children: [
                            Checkbox(
                              value: _hasSpouse,
                              onChanged: (value) {
                                setState(() {
                                  _hasSpouse = value ?? false;
                                });
                                if (_hasSpouse) {
                                  // Call this with the selected gender and familyId (must be filled)
                                  _loadSpouseOptions(_familyIdController.text.trim(), _selectedGender ?? '');
                                }
                              },
                            ),
                            const Text("Do you have a spouse?"),
                          ],
                        ),

                        if (_hasSpouse)
                          DropdownButtonFormField<String>(
                            value: _selectedSpouseId,
                            decoration: const InputDecoration(labelText: 'Select Spouse'),
                            items: _availableSpouses
                                .map((spouse) => DropdownMenuItem<String>(
                              value: spouse['id'],
                              child: Text(spouse['name']),
                            ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedSpouseId = value;
                              });
                            },
                          ),

                        Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DropdownButtonFormField<String>(
                          value: _fatherIdController.text.isNotEmpty ? _fatherIdController.text : null,
                          onChanged: (value) => setState(() => _fatherIdController.text = value ?? ''),
                          items: _members.map((member) => DropdownMenuItem<String>(
                            value: member['id'],
                            child: Text(member['name']!),
                          )).toList(),
                          decoration: InputDecoration(
                            labelText: "Father",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.brown, width: 2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            floatingLabelStyle: TextStyle(
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DropdownButtonFormField<String>(
                          value: _motherIdController.text.isNotEmpty ? _motherIdController.text : null,
                          onChanged: (value) => setState(() => _motherIdController.text = value ?? ''),
                          items: _members.map((member) => DropdownMenuItem<String>(
                            value: member['id'],
                            child: Text(member['name']!),
                          )).toList(),
                          decoration: InputDecoration(
                            labelText: "Mother",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.brown, width: 2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            floatingLabelStyle: TextStyle(
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      _buildTextField(_birthDateController, "Birth Date",
                          readOnly: true,
                          onTap: _selectBirthDate,
                          suffixIcon: Icon(Icons.calendar_today)),
                        SizedBox(height: 8),
                        GestureDetector(
                          onTap: _openMapDialog,
                          child: Container(
                            height: 200,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _pickedLocation == null
                                ? Center(child: Text("Tap to pick your address location"))
                                : GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: _pickedLocation!,
                                zoom: 15,
                              ),
                              markers: {
                                Marker(markerId: MarkerId("picked"), position: _pickedLocation!),
                              },
                              zoomControlsEnabled: false,
                              liteModeEnabled: true, // Flutter 3.7+ only
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildTextField(_emailController, "Email"),
                        _buildTextField(
                          _passwordController,
                          "Password",
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.brown,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        _buildTextField(
                          _confirmPasswordController,
                          "Confirm Password",
                          obscureText: _obscureConfirmPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.brown,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                      ],
                    ],

                    if (_userType == "Moderator") ...[
                      _buildTextField(_familyIdController, "Create Family ID"),
                      _buildTextField(_emailController, "Email"),
                      _buildTextField(
                        _passwordController,
                        "Password",
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.brown,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      _buildTextField(
                        _confirmPasswordController,
                        "Confirm Password",
                        obscureText: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.brown,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                    ],

                    SizedBox(height: 10),
                    if (_errorMessage != null)
                      Text(_errorMessage!, style: TextStyle(color: Colors.red)),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: Size(double.infinity, 50),
                      ),
                      child: Text("Sign up", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool obscureText = false, bool readOnly = false, VoidCallback? onTap, Widget? suffixIcon,}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: hint,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.brown, width: 2),
          ),
          floatingLabelStyle: TextStyle(
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _MapPickerDialog extends StatefulWidget {
  final LatLng initialLocation;

  const _MapPickerDialog({required this.initialLocation});

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  LatLng? _tempPicked;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _tempPicked = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      print('Error getting location: $e');
      // Fallback to provided initial location
      _tempPicked = widget.initialLocation;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _tempPicked == null
              ? Center(child: CircularProgressIndicator())
              : GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _tempPicked!,
              zoom: 15,
            ),
            onTap: (position) {
              setState(() {
                _tempPicked = position;
              });
            },
            markers: {
              Marker(
                markerId: MarkerId("tempPin"),
                position: _tempPicked!,
              )
            },
            myLocationEnabled: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop(_tempPicked);
            },
            icon: Icon(Icons.check),
            label: Text("Done"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              minimumSize: Size(double.infinity, 48),
            ),
          ),
        ),
      ],
    );
  }
}

