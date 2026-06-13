import 'package:flutter/foundation.dart';

class ConversationContext {
  final String imageHash;
  final String lastSummary;
  final DateTime timestamp;

  ConversationContext({
    required this.imageHash,
    required this.lastSummary,
    required this.timestamp,
  });
}

class ConversationContextManager {
  ConversationContext? _currentContext;

  String generateHash(String base64Image) {
    // Lightweight hash: first 64 chars + current minute to detect fast changes or the same image.
    // We use the size and first characters as a heuristic.
    final prefix = base64Image.length > 64 ? base64Image.substring(0, 64) : base64Image;
    return '${prefix}_${DateTime.now().minute}';
  }

  bool isSameImage(String newBase64) {
    if (_currentContext == null) return false;
    // If more than 2 minutes have passed, the context expires.
    if (DateTime.now().difference(_currentContext!.timestamp).inMinutes >= 2) {
      invalidate();
      return false;
    }
    
    final prefix = newBase64.length > 64 ? newBase64.substring(0, 64) : newBase64;
    return _currentContext!.imageHash.startsWith(prefix);
  }

  void updateContext(String base64Image, String summary) {
    _currentContext = ConversationContext(
      imageHash: generateHash(base64Image),
      lastSummary: summary,
      timestamp: DateTime.now(),
    );
  }

  String? getContextPrompt(String newQuestion) {
    if (_currentContext == null) return null;
    debugPrint('📍 SENSORS: 11.1 Context injected (hash: ${_currentContext!.imageHash.substring(0, 8)}...)');
    return '[CONTEXT] Last scene: "${_currentContext!.lastSummary}". Reply ONLY to: "$newQuestion". If you need to see the image again, say: "I need you to show the image again".';
  }

  void invalidate() {
    _currentContext = null;
  }
}
