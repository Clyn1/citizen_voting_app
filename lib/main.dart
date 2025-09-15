import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/screen.dart';  // Fixed import path
import 'screens/admin_dashboard.dart';  // Add this import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables
    await dotenv.load(fileName: ".env");

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Print debug info (remove in production)
    Secrets.printConfig();
  } catch (e) {
    debugPrint('Initialization error: $e');
    // You might want to show an error dialog or use default values
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Citizen Voting App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
    );
  }
}

// Example splash screen that checks configuration
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkConfiguration();
  }

  void _checkConfiguration() {
    // Check if secrets are properly loaded
    if (!Secrets.hasAnyApiKey) {
      debugPrint('Warning: No API keys configured');
      // You might want to show a warning or use offline mode
    }

    // Navigate to your main screen after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        // Navigate to AdminDashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AdminDashboard()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text('Loading Configuration...'),
            if (!Secrets.hasAnyApiKey)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Running in offline mode',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
          ],
        ),
      ),
    );
  }
}