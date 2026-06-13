/// ============================================================================
/// IRIS - Text-to-Speech (TTS) Service
/// ============================================================================
/// Handles native device voice synthesis.
/// Implements automatic interruption: if a new message arrives while
/// the TTS is speaking, it interrupts and reads the most recent one.
/// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/constants/app_constants.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  final Completer<void> _initCompleter = Completer<void>();

  /// Indicates if the TTS is currently speaking.
  bool get isSpeaking => _isSpeaking;

  /// Initializes the TTS engine with Iris configuration.
  Future<void> initialize() async {
    try {
      // Set language
      await _tts.setLanguage(AppConstants.ttsLanguage);

      // Set speed, pitch, and volume
      await _tts.setSpeechRate(AppConstants.ttsSpeechRate);
      await _tts.setPitch(AppConstants.ttsPitch);
      await _tts.setVolume(AppConstants.ttsVolume);

      // Set preferred TTS engine (Android)
      await _tts.setEngine('com.google.android.tts');

      // Register state callbacks
      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _tts.setCancelHandler(() {
        _isSpeaking = false;
      });

      _tts.setErrorHandler((message) {
        _isSpeaking = false;
        debugPrint('⚠️ TTS Error: $message');
      });

      _initCompleter.complete();
    } catch (e) {
      debugPrint('⚠️ Error initializing TTS: $e');
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  /// Speaks the provided text.
  ///
  /// If the TTS is already speaking, it is automatically interrupted
  /// and begins reading the new text (real-time context).
  Future<void> speak(String text) async {
    await _initCompleter.future;

    if (text.trim().isEmpty) return;

    String textToSpeak = text.trim();
    String detectedLang = AppConstants.ttsLanguage;

    final match = RegExp(r'^\[(en|es)\]\s*').firstMatch(textToSpeak.toLowerCase());
    if (match != null) {
      detectedLang = match.group(1) == 'en' ? 'en-US' : 'es-CL';
      textToSpeak = textToSpeak.substring(match.end).trim();
    }

    await _tts.setLanguage(detectedLang);

    // Interrupt current speech if it exists (prioritize recent info)
    if (_isSpeaking) {
      await _tts.stop();
      // Brief pause for the engine to cleanly restart
      await Future.delayed(const Duration(milliseconds: 50));
    }

    await _tts.speak(textToSpeak);
  }

  /// Stops any ongoing speech.
  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  /// Speaks a brief status message (non-interruptible by analysis).
  Future<void> speakStatus(String text) async {
    await _initCompleter.future;
    await _tts.setLanguage(AppConstants.ttsLanguage);
    await _tts.stop();
    await Future.delayed(const Duration(milliseconds: 50));
    await _tts.speak(text);
  }

  /// Releases TTS engine resources.
  Future<void> dispose() async {
    await _tts.stop();
  }
}
