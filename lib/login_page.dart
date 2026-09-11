import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:food_order_cihos/orders_page.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> saveLoginData(int tenantId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tenant_id', tenantId);
  }

  Future<void> saveLoginSession(int tenantId, String tenantUserId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setInt('tenant_id', tenantId);
    await prefs.setString('tenant_user_id', tenantUserId);
  }

  Future<void> sendFcmTokenToBackend(
    String tenantUserId,
    String fcmToken,
  ) async {
    final url = Uri.parse(
      "http://172.19.10.208/food_order_api/save_fcm_token.php",
    );
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"tenant_user_id": tenantUserId, "fcm_token": fcmToken}),
    );

    if (response.statusCode == 200) {
      print("FCM token sent to backend");
    } else {
      print("Failed to send FCM token");
    }
  }

  Future<void> login() async {
    setState(() {
      isLoading = true;
    });

    var url = Uri.parse("http://172.19.10.208/food_order_api/login.php");
    var response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_username": usernameController.text,
        "user_password": passwordController.text,
      }),
    );

    var jsonResponse = jsonDecode(response.body);

    setState(() {
      isLoading = false;
    });

    if (jsonResponse["success"] == true) {
      int tenantId = jsonResponse['user']['tenant_id'];
      await saveLoginData(tenantId);

      String tenantUserId = jsonResponse['user']['tenant_user_id'].toString();
      await saveLoginSession(tenantId, tenantUserId);

      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await sendFcmTokenToBackend(tenantUserId, fcmToken);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Login berhasil, selamat datang ${jsonResponse['user']['user_name']}!",
          ),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => OrdersPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login gagal: ${jsonResponse["message"]}")),
      );
    }
  }

  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.5,
            child: Image.asset('assets/background.png', fit: BoxFit.cover),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.55,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Sign in",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text("Enter your username or email"),
                    SizedBox(height: 8),
                    TextField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        hintText: "Username or email",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text("Enter your Password"),
                    SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText:
                          !_isPasswordVisible, // Gunakan _isPasswordVisible untuk mengontrol visibilitas
                      decoration: InputDecoration(
                        hintText: "Password",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible =
                                  !_isPasswordVisible; // Toggle visibilitas password
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 48),
                    Center(
                      child: SizedBox(
                        width: 300,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child:
                              isLoading
                                  ? CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : Text(
                                    "Sign in",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Center(
                    //   child: TextButton(
                    //     onPressed: () {
                    //       // Navigate to forgot password
                    //     },
                    //     child: Text("forgot password? click here", style: TextStyle(color: Colors.blue)),
                    //   ),
                    // )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
