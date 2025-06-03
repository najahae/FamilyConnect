import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'familymember/dashboard.dart';
import 'moderator/dashboard.dart';
import 'sign_up.dart';

class LoginScreen extends StatefulWidget {
  final String? familyID;

  LoginScreen({this.familyID});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _familyIdController = TextEditingController();

  bool _obscurePassword = true;
  String _userType = "Moderator";
  String? _errorMessage;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadSavedFamilyID();
  }

  Future<void> _loadSavedFamilyID() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedID = prefs.getString('familyID');

    if (widget.familyID != null) {
      _familyIdController.text = widget.familyID!;
    } else if (savedID != null) {
      _familyIdController.text = savedID;
    }
  }

  Future<void> _saveFamilyID(String id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('familyID', id);
  }

  Future<void> _login() async {
    String familyID = _familyIdController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (familyID.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "All fields are required.");
      return;
    }

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      String userId = userCredential.user!.uid;
      String rolePath = _userType == "Moderator" ? "moderators" : "family_members";

      DocumentSnapshot doc = await _firestore
          .collection('families')
          .doc(familyID)
          .collection(rolePath)
          .doc(userId)
          .get();

      if (!doc.exists) {
        setState(() => _errorMessage = "No $_userType account found in this Family ID.");
        return;
      }

      await _saveFamilyID(familyID);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => _userType == "Moderator"
              ? ModeratorDashboard()
              : FamilyMemberDashboard(),
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll(RegExp(r'\[.*?\]'), ''));
    }
  }

  Future<void> _resetPassword() async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your email to reset password.";
      });
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password reset email sent.")),
      );

    } catch (e) {
      setState(() {
        _errorMessage = "Error sending password reset email.";
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[100],
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(height: 60),
            Image.asset("assets/images/logo.png", height: 180, width: 180),
            Text("SIGN IN", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            Text("to continue", style: TextStyle(fontSize: 14)),
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
                  _buildTextField(_familyIdController, "Family ID"),
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
                  if (_errorMessage != null)
                    Text(_errorMessage!, style: TextStyle(color: Colors.red)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.teal[200]
                              : Colors.brown,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text("Login", style: TextStyle(color: Colors.white)),
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? "),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SignUpScreen(),
                            ),
                          );
                        },
                        child: Text(
                          "Sign up here",
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool obscureText = false, Widget? suffixIcon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.brown, width: 2),
          ),
          floatingLabelStyle: TextStyle(
            color: Colors.black,
          ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
