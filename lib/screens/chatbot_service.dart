// lib/screens/chatbot_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'screen.dart'; // Import your screen.dart file that contains the API key

class ChatbotService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  
  // Method to send message to OpenAI and get response
  static Future<String> sendMessage(String userMessage) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Secrets.openaiApiKey}',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a helpful AI assistant for a citizen voting app. Help users with voting procedures, candidate information, election results, and app navigation. Keep responses helpful, accurate, and relevant to voting and elections. Be concise but informative.'
            },
            {
              'role': 'user',
              'content': userMessage
            }
          ],
          'max_tokens': 200,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      } else {
        return _handleApiError(response.statusCode);
      }
    } catch (e) {
      print('ChatbotService Error: $e');
      return 'Sorry, I\'m having trouble connecting right now. Please check your internet connection and try again.';
    }
  }

  // Handle different API error codes
  static String _handleApiError(int statusCode) {
    print('API Error - Status Code: $statusCode');
    switch (statusCode) {
      case 401:
        return 'API authentication failed. Please check your API key configuration.';
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
      case 500:
        return 'OpenAI service is temporarily unavailable. Please try again later.';
      case 503:
        return 'Service is currently overloaded. Please try again in a few minutes.';
      default:
        return 'Sorry, I\'m experiencing technical difficulties. Please try again later.';
    }
  }
}