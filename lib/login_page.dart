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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Background Image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.55,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/Ciputra-Hospital-Surabaya.jpg',
                  fit: BoxFit.cover,
                ),
                // Gradient overlay agar kontras & modern
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
                // Teks simpel di area atas kiri & Logo di pojok kanan atas
                Positioned(
                  top: MediaQuery.of(context).padding.top + 20,
                  left: 24,
                  right: 24,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo polos transparan di pojok kanan atas
                      Image.asset(
                        'assets/icon/logoapp.png',
                        height: 58,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Floating Sheet dari bawah (tinggi pas, tidak terlalu tinggi)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 25,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 20.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar indikator
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Judul Login lebih bold
                      const Center(
                        child: Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Username field
                      const Text(
                        "Username / Email",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: usernameController,
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                        decoration: InputDecoration(
                          hintText: "Masukkan username atau email",
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.person_outline_rounded,
                            size: 20,
                            color: Color(0xFF1E5BB0),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF1E5BB0),
                              width: 1.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      const Text(
                        "Password",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: passwordController,
                        obscureText: !_isPasswordVisible,
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                        decoration: InputDecoration(
                          hintText: "Masukkan password Anda",
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            size: 20,
                            color: Color(0xFF1E5BB0),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              size: 20,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF1E5BB0),
                              width: 1.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E5BB0),
                            elevation: 4,
                            shadowColor:
                                const Color(0xFF1E5BB0).withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Sign in",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                     
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
