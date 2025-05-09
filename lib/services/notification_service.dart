import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    print("Initializing Notification Service...");

    // Request permissions (required for iOS, recommended for Android 13+)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false, // Set to true for provisional permission on iOS
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Notification permissions granted.');

      // Get the initial FCM token
      // Use APNS token for iOS/macOS if not running on web
      String? token;
      if (!kIsWeb) {
        // For apple platforms, ensure you have configured APNS correctly.
        // You might need to explicitly get the APNS token first on iOS/macOS
        // String? apnsToken = await _firebaseMessaging.getAPNSToken();
        // print("APNS Token: $apnsToken");
      }
      token = await _firebaseMessaging.getToken();
      print("Initial FCM Token: $token");
      // Save the initial token
      await saveTokenToDatabase(token);

      // Handle token refreshes
      _firebaseMessaging.onTokenRefresh
          .listen((newToken) {
            print("FCM Token Refreshed: $newToken");
            // Save the refreshed token
            saveTokenToDatabase(newToken);
          })
          .onError((err) {
            print("Error listening to token refresh: $err");
          });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Foreground Message Received:');
        print('Message ID: ${message.messageId}');
        print('Message data: ${message.data}');
        if (message.notification != null) {
          print(
            'Message also contained a notification: ${message.notification!.title} - ${message.notification!.body}',
          );
          // TODO: Show a local notification or update UI
        }
      });

      // Handle notification tap when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('Message clicked! Navigating from background/terminated.');
        print('Message data: ${message.data}');
        // TODO: Navigate based on message data (e.g., to a chat screen)
      });

      // Handle notification tap when app was terminated and is now opening
      RemoteMessage? initialMessage =
          await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        print('App opened via terminated state notification!');
        print('Initial Message data: ${initialMessage.data}');
        // TODO: Navigate based on initialMessage data
      }
    } else {
      print('User declined or has not accepted notification permissions');
    }
  }

  // Function to save the FCM token to the user's Firestore document
  Future<void> saveTokenToDatabase(String? token) async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null || token == null) {
      print('User not logged in or token is null. Cannot save FCM token.');
      return;
    }

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);
      // Use FieldValue.arrayUnion to add the token to an array, avoiding duplicates.
      // This supports multiple devices per user.
      await userRef.set(
        // Use set with merge:true to create/update field
        {
          'fcmTokens': FieldValue.arrayUnion([token]),
        },
        SetOptions(merge: true), // Merge to avoid overwriting other user data
      );
      print('FCM token saved to Firestore for user $userId');
    } catch (e) {
      print('Error saving FCM token to Firestore: $e');
    }
  }
}
