/// ============================================================================
/// IRIS - Computer Vision Service (API + Mock)
/// ============================================================================
/// Manages sending frames to the vision API and processing responses.
/// Includes a smart mock for development without an API.
/// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../core/constants/app_constants.dart';
import 'context_manager.dart';

class VisionService {
  int _mockIndex = 0;
  final Random _random = Random();
  
  bool isRequestInProgress = false;
  final ConversationContextManager contextManager = ConversationContextManager();

  bool isMobilityIntent(String prompt) {
    final keywords = [
      'how do i get', 'how to get', 'walk to', 'guide me', 'where is', 'where are', 'on my left', 'on my right', 'in front of', 'navigate',
      'cómo llego', 'camina', 'guía', 'dónde está', 'a mi izquierda', 'a mi derecha', 'cómo voy', 'qué hay delante'
    ];
    final lower = prompt.toLowerCase();
    return keywords.any((k) => lower.contains(k));
  }

  String sanitizeMobilityResponse(String raw) {
    final spatialWords = ['left', 'right', 'forward', 'back', 'turn', 'steps', 'front', 'straight', 'izquierda', 'derecha', 'adelante', 'atrás', 'gira', 'pasos', 'frente'];
    if (!spatialWords.any((w) => raw.toLowerCase().contains(w))) {
      // Try not to interfere too much with the [en]/[es] tag if present, but add the fallback
      return 'Note: Inexact direction. / Nota: Dirección inexacta. $raw';
    }
    return raw;
  }

  /// Analyzes an image based on the user's prompt.
  Future<String?> analyzeImage(Uint8List? imageBytes, {required String prompt}) async {
    if (isRequestInProgress) return null;
    isRequestInProgress = true;

    try {
      if (imageBytes == null) {
        // Text-only mode using context
        return await _analyzeTextWithContext(prompt);
      }
      return await _analyzeWithApi(imageBytes, prompt);
    } finally {
      isRequestInProgress = false;
    }
  }

  Future<String?> _analyzeTextWithContext(String prompt) async {
    final contextPrompt = contextManager.getContextPrompt(prompt);
    if (contextPrompt == null) {
      return "No previous context available. Please take a new photo.";
    }

    debugPrint('📍 SENSORS: 11.2 Using DeepSeek to resolve request based on context.');
    final rescueUri = Uri.parse('https://router.huggingface.co/v1/chat/completions');
    final token = AppConstants.hfToken;

    final requestBody = {
      'model': 'deepseek-ai/DeepSeek-V4-Flash:novita',
      'messages': [
        {'role': 'system', 'content': '[CRITICAL RULE: STRICTLY REPLY IN THE SAME LANGUAGE AS THE QUESTION. If the user speaks in English, your reply MUST be in English. If Spanish, in Spanish. ALWAYS start your reply with the [en] or [es] tag accordingly] You are an assistant for blind people. Reply in a fluent sentence of up to 30 words without bullet points.'},
        {'role': 'user', 'content': contextPrompt}
      ]
    };

    final response = await http.post(
      rescueUri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['choices']?[0]?['message']?['content']?.toString().trim();
    }
    return "Error processing conversational context.";
  }

  /// Continuous Mode ("Active Eyes")
  Future<String?> analyzeContinuousMode(Uint8List imageBytes) async {
    if (isRequestInProgress) return null;
    isRequestInProgress = true;

    try {
      final Uint8List compressedBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: 400, // Even smaller for continuous mode
        minHeight: 300,
        quality: 50,
      );
      final String base64Image = base64Encode(compressedBytes);
      
      final uri = Uri.parse('https://router.huggingface.co/v1/chat/completions');
      final token = AppConstants.hfToken;

      final prompt = '[MODALITY: QUICK DESCRIPTION] Describe in MAXIMUM 30 WORDS what is in front of the user. Prioritize obstacles, people, movements or relevant changes. Format: fluent sentence, no bullet points.';

      final requestBody = {
        'model': 'Qwen/Qwen3-VL-8B-Instruct:novita',
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
              }
            ]
          }
        ]
      };

      debugPrint('📍 SENSORS: 12.3 Sending continuous capture to Qwen3-VL');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final message = data['choices']?[0]?['message']?['content']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          final logSnippet = message.length > 50 ? '${message.substring(0, 50)}...' : message;
          debugPrint('📍 SENSORS: 12.4 Response received: "$logSnippet"');
        }
        return message;
      } else {
        debugPrint('📍 SENSORS: 12.9 Error in continuous mode: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('📍 SENSORS: 12.9 Error in continuous mode: $e');
      return null;
    } finally {
      isRequestInProgress = false;
    }
  }

  /// ─── REAL API: Sending to OpenRouter (OpenAI Format) ───
  Future<String> _analyzeWithApi(Uint8List imageBytes, String prompt) async {
    try {
      // 1. Optimized Compression (Balance between visual quality and weight)
      final int originalKB = imageBytes.length ~/ 1024;
      
      final Uint8List compressedBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: 800,
        minHeight: 600,
        quality: 75,
      );
      
      final int compressedKB = compressedBytes.length ~/ 1024;
      debugPrint('📸 Frame compression: $originalKB KB -> $compressedKB KB');

      // 2. Encode compressed image to base64
      final String base64Image = base64Encode(compressedBytes);

      // ═══════════════════════════════════════════════════════════════
      // PLAN A: Primary Vision (Hugging Face - Qwen3.6-27B)
      // ═══════════════════════════════════════════════════════════════

      // 1. New Hugging Face Router URL Configuration
      final uri = Uri.parse('https://router.huggingface.co/v1/chat/completions');
      
      // 🔥 Token extracted from environment variables
      final hfToken = AppConstants.hfToken; 

      // 2. Plan A Configuration (Vision - Qwen3-VL-8B forced by Novita)
      var strictVisionPrompt = '[CRITICAL: REPLY IN THE EXACT SAME LANGUAGE AS THE USER. If English, use English. Si es español, usa español. MUST start with [en] or [es].] Role: Visual assistant for the blind / Asistente visual para ciegos. Task: Describe the image in max 30 words. Mention immediate hazards if any. / Describe la imagen en máx 30 palabras. Menciona peligros inmediatos si los hay. No lists / Sin viñetas. User says / Usuario dice: "$prompt"';

      final isMobility = isMobilityIntent(prompt);
      if (isMobility) {
        debugPrint('📍 SENSORS: 10.1 Mobility intent detected');
        strictVisionPrompt += ' [MOBILITY] Give spatial instructions / Da instrucciones espaciales. En: "Direction: X. Action: Y. Reference: Z." Es: "Dirección: X. Acción: Y. Referencia: Z."';
      }

      final requestBody = {
        // Restoring the 8B model pointing to Novita
        'model': 'Qwen/Qwen3-VL-8B-Instruct:novita',
        'messages': [
          {
            'role': 'user',
            'content': [
              // Restoring the original text-first structure
              {
                'type': 'text',
                'text': strictVisionPrompt,
              },
              {
                'type': 'image_url',
                'image_url': {
                  // Restoring the standard base64 prefix
                  'url': 'data:image/jpeg;base64,$base64Image', 
                }
              }
            ]
          }
        ]
      };

      debugPrint('📍 SENSORS: 6. Sending to Hugging Face (Qwen3.6-27B)...');
      debugPrint('📍 LLM DEBUG - System Prompt: $strictVisionPrompt');
      debugPrint('📍 LLM DEBUG - User Spoken Text: $prompt');
      
      // 3. Fire request to Hugging Face
      var response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $hfToken', 
        },
        body: jsonEncode(requestBody),
      ); 

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final message = data['choices']?[0]?['message'];
        
        final String? content = message?['content'];
        final String? reasoning = message?['reasoning'];

        debugPrint('📍 LLM DEBUG - Raw Response Content: $content');
        if (reasoning != null) {
          debugPrint('📍 LLM DEBUG - Raw Reasoning: $reasoning');
        }

        // 🟢 CASE A: Qwen was successful
        if (content != null && content.trim().isNotEmpty) {
           debugPrint('📍 SENSORS: 7. Response successfully extracted from content.');
           contextManager.updateContext(base64Image, content.trim());
           
           if (isMobility) {
             return sanitizeMobilityResponse(content.trim());
           }
           return content.trim();
        } 
        // 🟡 CASE B: Token exhaustion. Firing Cascade Pipeline (OpenRouter)
        else if (reasoning != null) {
           // 1. Garbage Filter: Clean tags and check for real text
           final cleanReasoning = reasoning.replaceAll('<think>', '').replaceAll('</think>', '').trim();
           
           // ═══════════════════════════════════════════════════════════
           // Rescuers CONTINUE using Hugging Face Router
           // ═══════════════════════════════════════════════════════════
           final rescueUri = Uri.parse('https://router.huggingface.co/v1/chat/completions');
           final token = AppConstants.hfToken; // Hugging Face Token

           if (cleanReasoning.length > 10) {
               debugPrint('📍 SENSORS: 6.5 Token exhaustion. Starting Level 1 Rescue (DeepSeek-V4-Flash:novita)...');
               
               // 2. Prompt with Safeword (Kill Switch)
               final promptRescate = '[CRITICAL RULE: REPLY IN THE SAME LANGUAGE AS THE ORIGINAL INTENT. Start with [en] or [es]] You are an assistant for blind people. Summarize the following thought flow in A SINGLE FLUENT SENTENCE OF UP TO 30 WORDS that describes the environment in front of the user. Bullet points are forbidden. If it is incomprehensible, reply: ABORT.';

               // --- LEVEL 1: Attempt with DeepSeek:novita ---
               final textRequestL1 = {
                 'model': 'deepseek-ai/DeepSeek-V4-Flash:novita',
                 'messages': [
                   {'role': 'system', 'content': promptRescate},
                   {'role': 'user', 'content': cleanReasoning}
                 ]
               };

               var responseL1 = await http.post(
                 rescueUri,
                 headers: {
                   'Content-Type': 'application/json',
                   'Authorization': 'Bearer $token',
                   'HTTP-Referer': 'https://iris-vision-app.com',
                   'X-Title': 'Iris Assistant',
                 },
                 body: jsonEncode(textRequestL1),
               );

               debugPrint('📍 SENSORS: 6.6 Level 1 Status (DeepSeek:novita): ${responseL1.statusCode}');
               
               if (responseL1.statusCode == 200) {
                 final dataL1 = jsonDecode(utf8.decode(responseL1.bodyBytes));
                 final contentL1 = dataL1['choices']?[0]?['message']?['content'];
                 
                 // Validate it exists and DOES NOT contain the safeword
                 if (contentL1 != null && contentL1.trim().isNotEmpty && !contentL1.contains('ABORT')) {
                    debugPrint('📍 SENSORS: 7. Response successfully rescued by DeepSeek:novita.');
                    return contentL1.trim();
                 } else {
                    debugPrint('📍 SENSORS: 6.6.1 L1 Rescue with DeepSeek-V4-Flash:novita returned ABORT or useless text.');
                 }
               }

               // --- LEVEL 2: Attempt with OpenRouter (deepseek/deepseek-v4-flash:free) ---
               debugPrint('📍 SENSORS: 6.7 Starting Level 2 Rescue (OpenRouter: DeepSeek-V4-Flash:free)...');
               
               final openRouterUri = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
               final openRouterToken = AppConstants.apiKey;
               
               final textRequestL2 = {
                 'model': 'deepseek/deepseek-v4-flash:free',
                 'messages': [
                   {'role': 'system', 'content': promptRescate},
                   {'role': 'user', 'content': cleanReasoning}
                 ]
               };

               var responseL2 = await http.post(
                 openRouterUri,
                 headers: {
                   'Content-Type': 'application/json',
                   'Authorization': 'Bearer $openRouterToken',
                   'HTTP-Referer': 'https://iris-vision-app.com',
                   'X-Title': 'Iris Assistant',
                 },
                 body: jsonEncode(textRequestL2),
               );

               debugPrint('📍 SENSORS: 6.8 Level 2 Status (OpenRouter): ${responseL2.statusCode}');

               if (responseL2.statusCode == 200) {
                 final dataL2 = jsonDecode(utf8.decode(responseL2.bodyBytes));
                 final contentL2 = dataL2['choices']?[0]?['message']?['content'];
                 
                 if (contentL2 != null && contentL2.trim().isNotEmpty && !contentL2.contains('ABORT')) {
                    debugPrint('📍 SENSORS: 7. Response successfully rescued by OpenRouter (DeepSeek).');
                    return contentL2.trim();
                 }
               }

               // --- FINAL NETWORK SHIELD: Graceful Degradation ---
               if (responseL1.statusCode == 429 || responseL2.statusCode == 429) {
                 debugPrint('📍 SENSORS: 6.9 Cascading network collapse. Delivering saturation message.');
                 return 'Free servers are saturated right now. Please try again.';
               }
           }
           
           // --- FINAL SEMANTIC SHIELD (Nemotron saw nothing or rescuers Aborted) ---
           debugPrint('📍 SENSORS: 6.9 Semantic failure. AI could not interpret the image.');
           return 'The image was not clear enough. Please point again.';
        } else {
           throw Exception('Nemotron returned neither useful content nor reasoning.');
        }
      } else {
         throw Exception('HTTP Error ${response.statusCode} on vision server.');
      }
    } catch (e) {
      debugPrint('📍 SENSORS: 7. Final error caught: $e');
      throw Exception('Connection or interpretation error on server.');
    }
  }
}
