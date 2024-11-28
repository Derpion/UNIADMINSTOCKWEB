import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unistock/layout.dart';
import 'package:unistock/constants/style.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unistock/main.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _isPasswordVisible = false;

  // Firebase Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Query Firestore to find the matching user
        QuerySnapshot adminSnapshot = await FirebaseFirestore.instance
            .collection('admin')
            .where('Username', isEqualTo: _usernameController.text)
            .where('Password', isEqualTo: _passwordController.text)
            .get();

        if (adminSnapshot.docs.isNotEmpty) {
          // Get the first document (since usernames are unique)
          DocumentSnapshot adminDoc = adminSnapshot.docs.first;

          // Fetch the document ID
          String documentId = adminDoc.id;

          // Store the document ID globally in the UserController
          UserController userController = Get.find();
          userController.setDocumentId(documentId);

          // Navigate to the dashboard (or the next page)
          Get.offAll(SiteLayout());
        } else {
          // Show error message if no user found
          Get.snackbar('Error', 'Invalid username or password',
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      } catch (e) {
        // Handle any errors
        Get.snackbar('Error', 'Failed to login. Please try again later.',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(() {
      if (!_passwordFocusNode.hasFocus) {
        _login();
      }
    });
  }

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: active,
        title: RichText(
          text: TextSpan(
            style: GoogleFonts.poppins(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
            children: <TextSpan>[
              TextSpan(text: 'UNI', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'STOCK', style: TextStyle(color: Colors.yellow)),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person,
                      size: 60,
                      color: active,
                    ),
                    Text(
                      "WELCOME",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: active,
                      ),
                    ),
                    SizedBox(height: 30),
                    Container(
                      width: 300,
                      child: TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        ),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (value) {
                          FocusScope.of(context)
                              .requestFocus(_passwordFocusNode);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your username';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      width: 300,
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        focusNode: _passwordFocusNode,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        onFieldSubmitted: (value) {
                          _login();
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: active,
                        padding: EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        textStyle: TextStyle(fontSize: 18),
                      ),
                      child: Text(
                        "Login",
                        style: TextStyle(color: Colors.yellow),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
