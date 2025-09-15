// lib/services/chatbot_service.dart
// Offline-only version (no external API dependencies)
import 'dart:math';
import 'package:flutter/foundation.dart';

class ChatbotService {
  static bool _initialized = false;
  
  // Rate limiting
  static DateTime? _lastRequestTime;
  static int _requestCount = 0;
  static const int _maxRequestsPerMinute = 15;
  static const int _baseRequestIntervalSeconds = 2; // Shorter for offline
  static final List<DateTime> _requestHistory = [];
  static int _failureCount = 0;

  // Initialize service (offline mode)
  static void initialize() {
    _initialized = true;
    debugPrint('ChatBot Service initialized in offline mode');
  }

  static bool canMakeRequest() {
    final now = DateTime.now();
    
    // Clean old requests (older than 1 minute)
    _requestHistory.removeWhere((time) => 
        now.difference(time).inMinutes >= 1);
    
    // Check if we've hit the rate limit
    if (_requestHistory.length >= _maxRequestsPerMinute) {
      return false;
    }

    // Check basic interval
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = now.difference(_lastRequestTime!);
      final requiredInterval = _getRequiredInterval();
      return timeSinceLastRequest.inSeconds >= requiredInterval;
    }

    return true;
  }

  static int _getRequiredInterval() {
    // Simple rate limiting for offline responses
    return _baseRequestIntervalSeconds;
  }

  static Duration getRemainingWaitTime() {
    if (!canMakeRequest()) {
      final now = DateTime.now();
      
      // If rate limited by requests per minute
      if (_requestHistory.length >= _maxRequestsPerMinute && _requestHistory.isNotEmpty) {
        final oldestRequest = _requestHistory.first;
        final timeUntilOldestExpires = const Duration(minutes: 1) - 
            now.difference(oldestRequest);
        return timeUntilOldestExpires.isNegative ? Duration.zero : timeUntilOldestExpires;
      }
      
      // If rate limited by interval
      if (_lastRequestTime != null) {
        final timeSinceLastRequest = now.difference(_lastRequestTime!);
        final requiredInterval = Duration(seconds: _getRequiredInterval());
        final remaining = requiredInterval - timeSinceLastRequest;
        return remaining.isNegative ? Duration.zero : remaining;
      }
    }
    return Duration.zero;
  }

  static Future<String> sendMessage(String message) async {
    // Check rate limits
    if (!canMakeRequest()) {
      final waitTime = getRemainingWaitTime();
      return "Please wait ${waitTime.inSeconds} seconds before asking another question.";
    }

    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 500));

    final now = DateTime.now();
    _lastRequestTime = now;
    _requestHistory.add(now);
    _requestCount++;

    return _getFallbackResponse(message);
  }

  // Comprehensive offline responses for Kenyan voting
  static String _getFallbackResponse(String message) {
    final lowercaseMessage = message.toLowerCase();
    
    // Voting process
    if (lowercaseMessage.contains('vote') || lowercaseMessage.contains('voting') || lowercaseMessage.contains('cast')) {
      return '''To vote in Kenya:
1. Ensure you're registered with IEBC
2. Locate your polling station
3. Bring your national ID or passport
4. In this app: Go to 'Vote' tab, review candidates, select your choice, and confirm
5. Your vote is secret and secure

Voting hours are typically 6 AM to 6 PM on election day.''';
    }
    
    // Registration
    if (lowercaseMessage.contains('register') || lowercaseMessage.contains('registration')) {
      return '''Voter Registration in Kenya:
1. Visit nearest IEBC registration center
2. Bring original national ID or passport
3. Complete voter registration form
4. Provide biometric data (fingerprints & photo)
5. Verify details before submitting

Registration is FREE and takes 10-15 minutes. You must be 18+ years old.''';
    }
    
    // Candidates
    if (lowercaseMessage.contains('candidate') || lowercaseMessage.contains('candidates')) {
      return '''About Candidates:
• View all candidates in the 'Vote' tab
• Each profile shows: name, party, photo, and current votes
• Read their manifestos and policy positions
• Attend public debates to learn more
• Research their track records and experience

Make informed choices based on policies and qualifications.''';
    }
    
    // App usage
    if (lowercaseMessage.contains('app') || lowercaseMessage.contains('how') || lowercaseMessage.contains('use')) {
      return '''How to use this Voting App:
🗳️ Vote Tab: View and select candidates
📊 Results Tab: See real-time election results  
👤 Profile Tab: Manage your account
🤖 Chat Tab: Get help (that's me!)
⚙️ Admin Tab: For authorized personnel only

Navigate using the bottom menu. You can vote once per election.''';
    }
    
    // Results
    if (lowercaseMessage.contains('result') || lowercaseMessage.contains('results') || lowercaseMessage.contains('count')) {
      return '''Election Results:
• View live results in the 'Results' tab
• See vote counts and percentages
• Results update in real-time as votes are cast
• Final results are certified by IEBC
• Check official IEBC website for verified results

Remember: This app shows preliminary results only.''';
    }
    
    // IEBC and electoral process
    if (lowercaseMessage.contains('iebc') || lowercaseMessage.contains('commission') || lowercaseMessage.contains('electoral')) {
      return '''About IEBC (Independent Electoral and Boundaries Commission):
• Kenya's official electoral body
• Manages voter registration and elections
• Ensures free and fair elections
• Website: www.iebc.or.ke
• Hotline: 0800 221 221

IEBC oversees all electoral processes in Kenya including presidential, parliamentary, and county elections.''';
    }
    
    // Security and safety
    if (lowercaseMessage.contains('secure') || lowercaseMessage.contains('safety') || lowercaseMessage.contains('fraud')) {
      return '''Voting Security in Kenya:
• Your vote is secret and anonymous
• This app uses secure digital encryption
• No one can see how you voted
• Report any irregularities to IEBC
• Each voter can only vote once

Both physical and digital voting systems have security measures to prevent fraud.''';
    }
    
    // Requirements
    if (lowercaseMessage.contains('requirement') || lowercaseMessage.contains('need') || lowercaseMessage.contains('document')) {
      return '''Voting Requirements in Kenya:
✅ Must be 18+ years old
✅ Kenyan citizen (by birth or registration)
✅ Registered voter with IEBC
✅ Valid national ID or passport
✅ Be at correct polling station

For this app: Just login with your registered account and vote securely online.''';
    }
    
    // Elections types
    if (lowercaseMessage.contains('election') || lowercaseMessage.contains('president') || lowercaseMessage.contains('governor') || lowercaseMessage.contains('mp')) {
      return '''Types of Elections in Kenya:
🏛️ Presidential: Elect the President
🏢 Parliamentary: Elect Members of Parliament (MPs)
🏙️ County: Elect Governors and County Assembly Members
👥 Ward Representatives: Local area representatives

All are conducted simultaneously every 5 years. Each has different requirements and roles.''';
    }
    
    // Political parties
    if (lowercaseMessage.contains('party') || lowercaseMessage.contains('parties')) {
      return '''Political Parties in Kenya:
• Registered with the Registrar of Political Parties
• Must meet minimum membership requirements
• Have constitutions and manifestos
• Finance political campaigns
• Nominate candidates for elections

Research party policies and candidate track records before voting.''';
    }
    
    // Greetings
    if (lowercaseMessage.contains('hello') || lowercaseMessage.contains('hi') || lowercaseMessage.contains('hey')) {
      return '''Hello! I'm your AI voting assistant. I can help you with:

• How to vote in Kenya
• Voter registration process
• Using this voting app
• Candidate information
• Election results and procedures
• IEBC guidelines and requirements

What would you like to know about voting?''';
    }
    
    // Help requests
    if (lowercaseMessage.contains('help') || lowercaseMessage.contains('assist') || lowercaseMessage.contains('support')) {
      return '''I can help you with:

🗳️ Voting procedures in Kenya
📋 Voter registration process
📱 How to use this app
👥 Candidate information
📊 Understanding election results
⚖️ Electoral laws and requirements
🏛️ IEBC processes and contact info

What specific question do you have about voting?''';
    }

    // Constituencies and wards
    if (lowercaseMessage.contains('constituency') || lowercaseMessage.contains('ward')) {
      return '''Electoral Boundaries in Kenya:
🗺️ Constituencies: 290 areas for electing MPs
🏘️ Wards: Smaller areas for county representatives
📍 Each voter belongs to one constituency and ward
🆔 Your ID shows your registration location

Use the IEBC website to find your polling station and electoral area details.''';
    }

    // Voting problems/issues
    if (lowercaseMessage.contains('problem') || lowercaseMessage.contains('issue') || lowercaseMessage.contains('error')) {
      return '''Common Voting Issues & Solutions:

📱 App Problems: Restart the app, check internet connection
🆔 ID Issues: Ensure your ID is valid and you're registered
📍 Wrong Station: Check IEBC website for correct location
⏰ Time Issues: Voting is 6 AM - 6 PM only
🔒 Login Problems: Contact admin or use "Forgot Password"

For serious issues, contact IEBC hotline: 0800 221 221''';
    }

    // Default response with random helpful tip
    final tips = [
      '''I'm here to help with voting in Kenya! You can ask me about:

• How to vote and voter requirements
• Candidate information and selection  
• Using this voting app features
• Election results and processes
• IEBC guidelines and procedures
• Voter registration steps

What would you like to know about the electoral process?''',
      
      '''Tip: Did you know that in Kenya, you vote for multiple positions in one election? You can vote for President, Governor, Senator, MP, Woman Representative, and Ward Representative all at once!

What voting question can I help you with today?''',
      
      '''Quick fact: Kenya uses a "first-past-the-post" system for most elections, but the President needs over 50% of votes AND at least 25% in half the counties to avoid a runoff.

How can I assist you with voting today?''',
    ];
    
    return tips[Random().nextInt(tips.length)];
  }

  // Utility methods
  static void resetRateLimit() {
    _lastRequestTime = null;
    _requestHistory.clear();
    _requestCount = 0;
    _failureCount = 0;
  }

  static Map<String, dynamic> getServiceStatus() {
    return {
      'initialized': _initialized,
      'canMakeRequest': canMakeRequest(),
      'requestCount': _requestCount,
      'failureCount': _failureCount,
      'remainingWaitTimeSeconds': getRemainingWaitTime().inSeconds,
      'recentRequestsCount': _requestHistory.length,
      'serviceType': 'Offline Assistant',
    };
  }

  // Call this when your app starts
  static void initializeService() {
    initialize();
  }
}