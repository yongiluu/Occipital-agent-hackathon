/// ============================================================================
/// IRIS - Configuration Constants
/// ============================================================================
/// ALL configurable project variables are centralized here.
/// ============================================================================

class AppConstants {
  AppConstants._(); // Prevent instantiation

  // ─────────────────────────────────────────────────────────────
  // COMPUTER VISION API (OPENROUTER)
  // ─────────────────────────────────────────────────────────────

  /// OpenRouter Vision API endpoint URL.
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://openrouter.ai/api/v1/chat/completions', 
  );

  /// OpenRouter API Key.
  /// Pass via console as: --dart-define=OPENROUTER_API_KEY="your_key"
  static const String apiKey = String.fromEnvironment(
    'OPENROUTER_API_KEY',
    defaultValue: '', 
  );

  /// Hugging Face API Key.
  static const String hfToken = String.fromEnvironment('HF_API_KEY', defaultValue: '');

  /// Primary vision model.
  static const String primaryModel = String.fromEnvironment(
    'API_MODEL_PRIMARY',
    defaultValue: 'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free', 
  );

  /// Fallback model in case of failure or timeout.
  /// Uses 'openrouter/free' which automatically selects an available 
  /// free model that supports vision.
  static const String fallbackModel = String.fromEnvironment(
    'API_MODEL_FALLBACK',
    defaultValue: 'openrouter/free', 
  );

  /// If true, uses mock responses instead of the real API.
  /// Automatically activated if apiKey is empty.
  static bool get useMock => apiKey.isEmpty;

  // ─────────────────────────────────────────────────────────────
  // FRAME SAMPLING AND TTS
  // ─────────────────────────────────────────────────────────────

  static const int frameCaptureIntervalMs = 1800;
  static const int imageQuality = 70;

  static const String ttsLanguage = 'en-US';
  static const double ttsSpeechRate = 0.55;
  static const double ttsPitch = 1.0;
  static const double ttsVolume = 1.0;

  // ─────────────────────────────────────────────────────────────
  // MOCK / SIMULATION
  // ─────────────────────────────────────────────────────────────

  static const int mockDelayMs = 500;

  static const List<String> mockResponses = [
    'There is a street with a red traffic light ahead. A crosswalk is two meters away.',
    'I detect a person walking towards you about three meters away, on your left side.',
    'There are descending stairs one meter in front of you. There are approximately ten steps.',
    'I see a sign that says: Emergency Exit, with an arrow pointing to the right.',
    'The environment appears to be a well-lit indoor hallway. No immediate obstacles detected.',
    'There is a closed door two meters in front of you. It appears to be a glass door.',
    'I detect a parked vehicle to your right, about four meters away.',
    'I see a table with objects on it. There appears to be a glass and a plate one meter away.',
  ];
}
