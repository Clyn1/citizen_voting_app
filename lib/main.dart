  import 'package:flutter/material.dart';
  import 'package:firebase_core/firebase_core.dart';
  import 'firebase_options.dart';
  import 'screens/admin_dashboard.dart';

  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    runApp(const MyApp());
  }

  class MyApp extends StatelessWidget {
    const MyApp({super.key});

    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        title: 'Citizen Voting App',
        theme: ThemeData(
          primarySwatch: Colors.deepPurple,
          useMaterial3: true,
        ),
        home: const AdminDashboard(),
        debugShowCheckedModeBanner: false,
      );
    }
  }