import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/vote_page.dart';
import 'screens/results_page.dart';

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
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      initialRoute: '/login', // ✅ Start from login
      routes: {
        '/login': (_) => const LoginPage(),
        '/home': (_) => const HomePage(), // ✅ New route
        '/vote': (_) => const VotePage(),
        '/results': (_) => const ResultsPage(),
      },
    );
  }
}
