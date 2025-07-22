import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/welcome_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🔔 Setup for background notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // This runs when the app is terminated or in background
  print("🔕 Background message received: ${message.data}");
}

Future<void> initializeFCM() async {
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  Map<String, dynamic> _parsePayload(String payload) {
    final cleanPayload = payload.replaceAll(RegExp(r'^{|}$'), ''); // remove curly braces
    final Map<String, String> parts = Map.fromEntries(
      cleanPayload.split(', ').map((pair) {
        final split = pair.split(':');
        return MapEntry(split[0].trim(), split[1].trim());
      }),
    );

    return {
      'eventId': parts['eventId'] ?? '',
      'familyId': parts['familyId'] ?? '',
      'userId': parts['userId'] ?? '', // pass this from FCM!
    };
  }

  Future<void> _updateRSVPStatus(
      String familyId, String eventId, String userId, String rsvpStatus) async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      // Find the correct notification doc
      final notifQuery = await firestore
          .collection("families")
          .doc(familyId)
          .collection("family_members")
          .doc(userId)
          .collection("notifications")
          .where("eventId", isEqualTo: eventId)
          .limit(1)
          .get();

      if (notifQuery.docs.isNotEmpty) {
        final docRef = notifQuery.docs.first.reference;
        await docRef.update({"rsvpStatus": rsvpStatus});
        print("✅ RSVP updated to $rsvpStatus");
      } else {
        print("⚠️ Notification doc not found.");
      }
    } catch (e) {
      print("❌ Error updating RSVP: $e");
    }
  }

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.high,
  );

  const AndroidInitializationSettings androidSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      String? actionId = response.actionId;
      String? payload = response.payload;

      print("🔘 RSVP Button tapped: $actionId");
      print("📦 Payload: $payload");

      if (actionId == 'RSVP_GOING' || actionId == 'RSVP_MAYBE' || actionId == 'RSVP_NOT_GOING') {
        if (payload != null) {
          final Map<String, dynamic> data = _parsePayload(payload);

          final String eventId = data['eventId'];
          final String familyId = data['familyId'];
          final String userId = data['userId']; // you’ll include this in the Cloud Function

          final String rsvp = actionId!.replaceFirst('RSVP_', '').toLowerCase(); // going / maybe / not_going

          await _updateRSVPStatus(familyId, eventId, userId, rsvp);
        }
      }
    },
  );

  // 💥 Foreground handler
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("📬 Foreground message received: ${message.notification?.title}");

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'RSVP_GOING',
                'Going',
              ),
              AndroidNotificationAction(
                'RSVP_MAYBE',
                'Maybe',
              ),
              AndroidNotificationAction(
                'RSVP_NOT_GOING',
                'Not Going',
              ),
            ],
          ),
        ),
        payload: message.data.toString(), // so you can handle it later
      );
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await initializeFCM();

  await FirebaseMessaging.instance.requestPermission();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const WelcomeScreen(), // start from WelcomeScreen
    );
  }
}
