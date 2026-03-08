class AppConfig {
  static String apiBaseUrl = 'https://api.tatakai.me/api/v1';

  // Timeout for API requests in seconds - Increased for reliability
  static int connectTimeout = 30;
  static int receiveTimeout = 30;

  // Player Settings
  static bool autoPlay = true;
  static bool useNativeControls = false; // Use custom Plyr controls
}
