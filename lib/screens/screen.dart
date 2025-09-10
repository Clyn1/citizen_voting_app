// lib/screens/screen.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Secrets {
  static String get openaiApiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
}
