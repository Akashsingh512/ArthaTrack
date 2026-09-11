class AppConstants {
  static const String appName = 'ArthaTrack';
  static const String appTagline = 'Privacy-First Indian Wealth & Expense Tracker';
  static const String currencySymbol = '₹';

  // Secure Storage Keys
  static const String secureKeyAiProvider = 'byok_ai_provider';
  static const String secureKeyGeminiApiKey = 'byok_gemini_api_key';
  static const String secureKeyGroqApiKey = 'byok_groq_api_key';
  static const String secureKeyBedrockApiKey = 'byok_bedrock_api_key';
  static const String secureKeyBedrockModel = 'byok_bedrock_model';
  static const String secureKeyBedrockRegion = 'byok_bedrock_region';
  static const String secureKeyActiveModel = 'byok_active_model';

  // AI Providers
  static const String providerGemini = 'Gemini';
  static const String providerGroq = 'Groq';
  static const String providerBedrock = 'AWS Bedrock';
  static const String defaultGeminiModel = 'gemini-flash-latest';
  static const String defaultGroqModel = 'llama-3.3-70b-versatile';
  static const String defaultBedrockModel = 'qwen.qwen3-coder-next';
  static const String defaultBedrockRegion = 'us-east-1';

  // Platform Channels
  static const String notificationEventChannel = 'com.arthatrack.app/notifications';
  static const String notificationControlChannel = 'com.arthatrack.app/notification_control';

  // Database
  static const String databaseName = 'arthatrack_local.db';
  static const int databaseVersion = 9;
}
