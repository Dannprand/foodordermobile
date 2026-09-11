import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'login_page.dart';
import 'orders_page.dart';

// Notifikasi lokal
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

String? _lastMessageId;

// Handler background
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('[Notification] Background message: ${message.messageId}');
  print('[Notification] Data: ${message.data}');

  final messageId = message.messageId ?? message.data['order_id'];
  if (_lastMessageId == messageId) return;
  _lastMessageId = messageId;

  final title = message.data['title'] ?? 'No Title';
  final body = message.data['body'] ?? 'No Body';

  NotificationDetails platformChannelSpecifics;
  if (Platform.isAndroid) {
    const androidDetails = AndroidNotificationDetails(
      'order_channel_ns',
      'Order Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      // sound: RawResourceAndroidNotificationSound('kachingsound'),
    );
    platformChannelSpecifics = const NotificationDetails(android: androidDetails);
  } else {
    const iOSDetails = DarwinNotificationDetails();
    platformChannelSpecifics = const NotificationDetails(iOS: iOSDetails);
  }

  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    platformChannelSpecifics,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("=== APP START ===");

  try {
    await Firebase.initializeApp();
    print("=== Firebase Initialized ===");
  } catch (e) {
    print("Firebase init error: $e");
  }

  // Inisialisasi notifikasi lokal
  if (Platform.isAndroid) {
    const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInitSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
    print("=== Local Notification Android Initialized ===");
  } else {
    const iosInitSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(iOS: iosInitSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
    print("=== Local Notification iOS Initialized ===");
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    final notificationService = NotificationService();
    await notificationService.init();
    print("=== NotificationService Initialized ===");
  } catch (e) {
    print("NotificationService error: $e");
  }

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  print("=== isLoggedIn: $isLoggedIn ===");

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF075E9C),
        scaffoldBackgroundColor: Colors.white,
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Color(0xFF075E9C),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
        ),
      ),
      home: isLoggedIn ? OrdersPage() : LoginPage(),
      routes: {
        '/login': (context) => LoginPage(),
      },
    );
  }
}
