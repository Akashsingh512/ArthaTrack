class AppConstants {
  static const String appName = 'ArthaTrack';
  static const String appTagline = 'Privacy-First Indian Wealth & Expense Tracker';
  static const String currencySymbol = '₹';

  // Secure Storage Keys
  static const String secureKeyAiProvider = 'byok_ai_provider';
  static const String secureKeyGeminiApiKey = 'byok_gemini_api_key';
  static const String secureKeyGroqApiKey = 'byok_groq_api_key';
  static const String secureKeyActiveModel = 'byok_active_model';

  // AI Providers
  static const String providerGemini = 'Gemini';
  static const String providerGroq = 'Groq';
  static const String defaultGeminiModel = 'gemini-flash-latest';
  static const String defaultGroqModel = 'llama-3.3-70b-versatile';

  // Platform Channels
  static const String notificationEventChannel = 'com.arthatrack.app/notifications';
  static const String notificationControlChannel = 'com.arthatrack.app/notification_control';

  // Database
  static const String databaseName = 'arthatrack_local.db';
  static const int databaseVersion = 8;
}
