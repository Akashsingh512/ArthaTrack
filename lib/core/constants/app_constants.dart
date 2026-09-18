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
  static const String secureKeyThemeMode = 'app_theme_mode';
  static const String secureKeyBackupPassphrase = 'backup_passphrase';
  static const String secureKeyBackupDestination = 'backup_destination'; // 'google_drive', 'webdav', 'local'
  static const String secureKeyBackupWebDavUrl = 'backup_webdav_url';
  static const String secureKeyBackupWebDavUser = 'backup_webdav_user';
  static const String secureKeyBackupWebDavPassword = 'backup_webdav_password';
  static const String secureKeyBackupAutoInterval = 'backup_auto_interval'; // 'daily', 'weekly', 'disabled'
  static const String secureKeyBackupLastSyncTime = 'backup_last_sync_time';
  static const String secureKeyBackupLastStatus = 'backup_last_status';

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
  static const int databaseVersion = 12;

  // App Version & In-App Updates
  static const String appVersion = '1.1.0';
  static const int appBuildNumber = 10;
  static const String githubRepo = 'Akashsingh512/ArthaTrack';
  static const String updaterChannel = 'com.arthatrack.app/updater';
  static const String secureKeyAutoCheckUpdates = 'app_auto_check_updates';
  static const String secureKeyLastUpdateCheck = 'app_last_update_check';
}
