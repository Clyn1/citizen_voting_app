// lib/screens/chatbot_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
class ChatbotService {
  // Replace with your actual OpenAI API key
  static const String _apiKey = 'YOUR_OPENAI_API_KEY_HERE';
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  
  // Rate limiting variables
  static DateTime? _lastRequestTime;
  static const int _requestIntervalSeconds = 3; // Wait 3 seconds between requests

  // Check if we can make a request (not rate limited)
  static bool canMakeRequest() {
    if (_lastRequestTime == null) return true;
    
    final now = DateTime.now();
    final timeDifference = now.difference(_lastRequestTime!);
    return timeDifference.inSeconds >= _requestIntervalSeconds;
  }

  // Get remaining wait time before next request
  static Duration getRemainingWaitTime() {
    if (_lastRequestTime == null) return Duration.zero;
    
    final now = DateTime.now();
    final timeDifference = now.difference(_lastRequestTime!);
    final remainingSeconds = _requestIntervalSeconds - timeDifference.inSeconds;
    
    return remainingSeconds > 0 
        ? Duration(seconds: remainingSeconds) 
        : Duration.zero;
  }

  // Send message to OpenAI API
  static Future<String> sendMessage(String message) async {
    try {
      // Update last request time for rate limiting
      _lastRequestTime = DateTime.now();

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a helpful AI assistant for a Citizen Voting App. Help users with questions about voting, candidates, election processes, and app navigation. Be informative, friendly, and concise.'
            },
            {
              'role': 'user',
              'content': message,
            }
          ],
          'max_tokens': 500,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      } else if (response.statusCode == 429) {
        // Rate limit exceeded
        return "I'm receiving too many requests right now. Please wait a moment before trying again.";
      } else if (response.statusCode == 401) {
        // Invalid API key
        return "There's an authentication issue with the AI service. Please contact support.";
      } else {
        // Other API errors
        return "I'm having trouble connecting to the AI service. Please try again later.";
      }
    } catch (e) {
      // Network or other errors
      return "I'm having trouble connecting right now. Please check your internet connection and try again.";
    }
  }

  // Reset rate limiting (useful for testing)
  static void resetRateLimit() {
    _lastRequestTime = null;
  }
}
