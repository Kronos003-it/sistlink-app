import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:sist_link1/screens/auth/login_screen.dart'; // Import LoginScreen
import 'package:sist_link1/responsive/mobile_screen_layout.dart';
import 'package:sist_link1/responsive/web_screen_layout.dart'; // Import WebScreenLayout
import 'package:sist_link1/responsive/responsive_layout.dart'; // Import ResponsiveLayout
import 'package:sist_link1/firebase_options.dart'; // Import generated options
import 'package:sist_link1/services/notification_service.dart'; // Import NotificationService

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Notification Service (run async, don't block startup)
  NotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SistLink',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            // User is logged in - use ResponsiveLayout
            return const ResponsiveLayout(
              mobileScreenLayout: MobileScreenLayout(),
              webScreenLayout: WebScreenLayout(),
            );
          }
          // User is not logged in
          return const LoginScreen();
        },
      ),
    );
  }
}

// Removed old MyHomePage code
