// lib/screens/chatbot_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'screen.dart'; // Import your screen.dart file that contains the API key

class ChatbotService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  
  // Method to send message to OpenAI and get response
  static Future<String> sendMessage(String userMessage) async {
    try {
      // Check if API key is configured
      if (Secrets.openaiApiKey.isEmpty || Secrets.openaiApiKey == 'your-openai-api-key-here') {
        return 'Please configure your OpenAI API key in screen.dart file to use AI features.';
      }

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
              'content': 'You are a helpful AI assistant for a citizen voting app. Help users with voting procedures, candidate information, election results, and app navigation. Keep responses helpful, accurate, and relevant to voting and elections. Be concise but informative. Focus on:\n'
                        '- How to vote in the app\n'
                        '- Information about candidates\n'
                        '- Understanding election results\n'
                        '- App features and navigation\n'
                        '- Voting rights and procedures\n'
                        '- Election security and privacy'
            },
            {
              'role': 'user',
              'content': userMessage
            }
          ],
          'max_tokens': 300,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'].toString().trim();
        return content.isNotEmpty ? content : 'I received an empty response. Please try again.';
      } else {
        print('API Error - Status: ${response.statusCode}, Body: ${response.body}');
        return _handleApiError(response.statusCode);
      }
    } catch (e) {
      print('ChatbotService Error: $e');
      return 'Sorry, I\'m having trouble connecting right now. Please check your internet connection and try again.';
    }
  }

  // Handle different API error codes
  static String _handleApiError(int statusCode) {
    switch (statusCode) {
      case 401:
        return 'API authentication failed. Please check your OpenAI API key configuration.';
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
      case 500:
        return 'OpenAI service is temporarily unavailable. Please try again later.';
      case 503:
        return 'Service is currently overloaded. Please try again in a few minutes.';
      default:
        return 'Sorry, I\'m experiencing technical difficulties (Error $statusCode). Please try again later.';
    }
  }

  // Test connection method
  static Future<bool> testConnection() async {
    try {
      if (Secrets.openaiApiKey.isEmpty || Secrets.openaiApiKey == 'your-openai-api-key-here') {
        return false;
      }
      
      String response = await sendMessage('Hello');
      return response.isNotEmpty && !response.contains('Please configure');
    } catch (e) {
      return false;
    }
  }
}