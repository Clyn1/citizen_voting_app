// lib/screens/secrets.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class Secrets {
  // Private constructor to prevent instantiation
  Secrets._();
  
  // Check if dotenv is loaded
  static bool get isDotEnvLoaded => dotenv.isInitialized;
  
  // Gemini API key (primary)
  static String get geminiApiKey {
    try {
      return dotenv.env['GEMINI_API_KEY'] ?? '';
    } catch (e) {
      if (kDebugMode) {
        print('Error accessing GEMINI_API_KEY: $e');
      }
      return '';
    }
  }
  
  // OpenAI API key (backup/fallback)
  static String get openaiApiKey {
    try {
      return dotenv.env['OPENAI_API_KEY'] ?? '';
    } catch (e) {
      if (kDebugMode) {
        print('Error accessing OPENAI_API_KEY: $e');
      }
      return '';
    }
  }
  
  // Feature flags with better error handling
  static bool get useGemini {
    try {
      final value = dotenv.env['USE_GEMINI']?.toLowerCase();
      return value == 'true' || value == '1';
    } catch (e) {
      if (kDebugMode) {
        print('Error accessing USE_GEMINI: $e');
      }
      return false;
    }
  }
  
  static bool get enableFallbackResponses {
    try {
      final value = dotenv.env['ENABLE_FALLBACK_RESPONSES']?.toLowerCase();
      return value == 'true' || value == '1';
    } catch (e) {
      if (kDebugMode) {
        print('Error accessing ENABLE_FALLBACK_RESPONSES: $e');
      }
      return false;
    }
  }
  
  // Check if any AI service is configured
  static bool get hasAnyApiKey => geminiApiKey.isNotEmpty || openaiApiKey.isNotEmpty;
  
  // Get the active service name
  static String get activeService {
    if (useGemini && geminiApiKey.isNotEmpty) return 'Gemini';
    if (openaiApiKey.isNotEmpty) return 'OpenAI';
    return 'Offline';
  }
  
  // Validate configuration
  static Map<String, dynamic> get configStatus {
    return {
      'dotenvLoaded': isDotEnvLoaded,
      'hasGeminiKey': geminiApiKey.isNotEmpty,
      'hasOpenAIKey': openaiApiKey.isNotEmpty,
      'useGemini': useGemini,
      'enableFallback': enableFallbackResponses,
      'activeService': activeService,
    };
  }
  
  // Debug method to print configuration (remove in production)
  static void printConfig() {
    if (kDebugMode) {
      print('=== Secrets Configuration ===');
      print('DotEnv Loaded: $isDotEnvLoaded');
      print('Has Gemini Key: ${geminiApiKey.isNotEmpty}');
      print('Has OpenAI Key: ${openaiApiKey.isNotEmpty}');
      print('Use Gemini: $useGemini');
      print('Enable Fallback: $enableFallbackResponses');
      print('Active Service: $activeService');
      print('=============================');
    }
  }
}