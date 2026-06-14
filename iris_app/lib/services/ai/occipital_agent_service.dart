/// ============================================================================
/// OCCIPITAL HACKATHON - Microsoft Agents League
/// ============================================================================
/// Base Service for Azure & Microsoft Foundry Integration
/// ============================================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../core/constants/env_config.dart';

enum OccipitalLayer { macro, micro, critical }

/// Isolated base class that will serve as the central connection point
/// for our integration with Azure and Microsoft Foundry.
class OccipitalAgentService {
  static final OccipitalAgentService _instance = OccipitalAgentService._internal();

  factory OccipitalAgentService() => _instance;

  OccipitalAgentService._internal();

  /// Base Persona for the Occipital Agent
  static const String systemPrompt = '''
You are Occipital, an advanced, highly reliable visual and reasoning assistant for visually impaired users. Your primary directive is user safety and absolute accuracy. When analyzing images containing critical text (such as medication labels or safety instructions), you must strictly use the provided retrieved context to verify facts and never hallucinate information. For general requests, be concise, highly descriptive of the physical environment, and empathetic.
''';

  bool _isInitialized = false;

  /// UdeC Campus mock coordinates for Hackathon POC
  final double mockLat = -36.8282;
  final double mockLon = -73.0366;

  /// Initializes the connection with Microsoft Foundry / Azure services.
  Future<void> initialize() async {
    if (_isInitialized) return;

    final endpoint = EnvConfig.azureFoundryEndpoint;
    final key = EnvConfig.azureFoundryKey;

    if (endpoint.isEmpty || key.isEmpty) {
      debugPrint('⚠️ OccipitalAgentService: Missing Azure credentials in .env');
    } else {
      debugPrint('🔌 OccipitalAgentService: Initialized with Azure endpoint $endpoint');
    }

    _isInitialized = true;
  }

  /// Heuristic router to classify user intent into the appropriate layer
  OccipitalLayer _classifyIntent(String prompt) {
    final p = prompt.toLowerCase();
    
    // Critical layer keywords
    if (p.contains('medicine') || p.contains('guideline') || p.contains('fda') || 
        p.contains('contraindication') || p.contains('medical') || p.contains('health') || 
        p.contains('insulin')) {
      return OccipitalLayer.critical;
    }
    
    // Macro layer keywords
    if (p.contains('street') || p.contains('where am i') || p.contains('weather') || 
        p.contains('coat') || p.contains('temperature') || p.contains('navigate')) {
      return OccipitalLayer.macro;
    }
    
    // Default to Micro
    return OccipitalLayer.micro;
  }

  // ─── HTTP INTEGRATION HANDLERS ───

  Future<String> _handleMacroLayer(String prompt) async {
    debugPrint('🌍 OccipitalAgentService [MACRO]: Fetching LocationIQ & OpenWeatherMap data...');
    
    String locationText = 'Unknown location';
    String weatherText = 'Unknown weather';

    double lat = mockLat;
    double lon = mockLon;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition();
          lat = position.latitude;
          lon = position.longitude;
        } else {
          debugPrint('⚠️ OccipitalAgentService: Location permissions denied, falling back to mock coordinates.');
        }
      } else {
        debugPrint('⚠️ OccipitalAgentService: Location services disabled, falling back to mock coordinates.');
      }
    } catch (e) {
      debugPrint('⚠️ OccipitalAgentService: Error getting location (\$e), falling back to mock coordinates.');
    }

    try {
      // 1. LocationIQ
      if (EnvConfig.locationIqKey.isNotEmpty) {
        final locUrl = Uri.parse('https://us1.locationiq.com/v1/reverse?key=${EnvConfig.locationIqKey}&lat=$lat&lon=$lon&format=json');
        final locRes = await http.get(locUrl);
        if (locRes.statusCode == 200) {
          final data = jsonDecode(locRes.body);
          final address = data['address'];
          final road = address['road'] ?? 'an unknown street';
          final city = address['city'] ?? address['town'] ?? address['village'] ?? '';
          locationText = '$road, $city';
        }
      }

      // 2. OpenWeatherMap
      if (EnvConfig.openWeatherKey.isNotEmpty) {
        final weatherUrl = Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=${EnvConfig.openWeatherKey}&units=metric');
        final weatherRes = await http.get(weatherUrl);
        if (weatherRes.statusCode == 200) {
          final data = jsonDecode(weatherRes.body);
          final temp = data['main']['temp'];
          final description = data['weather'][0]['description'];
          weatherText = '$temp°C and $description';
        }
      }

      return "You are currently near $locationText. The weather is $weatherText.";
    } catch (e) {
      debugPrint('Error in Macro Layer: $e');
      return "I'm sorry, I couldn't fetch the location and weather information at the moment.";
    }
  }

  Future<String> _handleCriticalLayer(String prompt, Uint8List imageBytes) async {
    debugPrint('🏥 OccipitalAgentService [CRITICAL]: Querying Foundry IQ (insulina-fda-kb)...');
    
    try {
      // 1. Azure AI Search Query
      String searchContext = '';
      if (EnvConfig.azureSearchEndpoint.isNotEmpty && EnvConfig.azureSearchKey.isNotEmpty) {
        final searchUrl = Uri.parse('${EnvConfig.azureSearchEndpoint}/indexes/insulina-fda-kb/docs/search?api-version=2023-11-01');
        final searchRes = await http.post(
          searchUrl,
          headers: {
            'Content-Type': 'application/json',
            'api-key': EnvConfig.azureSearchKey,
          },
          body: jsonEncode({
            "search": prompt,
            "top": 3
          }),
        );

        if (searchRes.statusCode == 200) {
          final data = jsonDecode(searchRes.body);
          final values = data['value'] as List;
          if (values.isNotEmpty) {
            searchContext = values.map((e) => e['content'] ?? '').join('\n');
          } else {
            searchContext = 'No relevant FDA guidelines found in the secure database.';
          }
        }
      }

      // 2. Azure OpenAI Request
      return await _callAzureOpenAI(
        prompt: "Context from FDA guidelines:\n$searchContext\n\nUser Question: $prompt",
        imageBytes: imageBytes,
      );
    } catch (e) {
      debugPrint('Error in Critical Layer: $e');
      return "I encountered an error while querying the secure medical database. Please try again safely.";
    }
  }

  Future<String> _handleMicroLayer(String prompt, Uint8List imageBytes) async {
    debugPrint('👁️ OccipitalAgentService [MICRO]: Running general vision analysis via GPT-4.1-mini...');
    try {
      return await _callAzureOpenAI(prompt: prompt, imageBytes: imageBytes);
    } catch (e) {
      debugPrint('Error in Micro Layer: $e');
      return "I'm having trouble analyzing the image right now.";
    }
  }

  /// Helper to call Azure OpenAI
  Future<String> _callAzureOpenAI({required String prompt, required Uint8List imageBytes}) async {
    final endpoint = EnvConfig.azureFoundryEndpoint;
    final key = EnvConfig.azureFoundryKey;
    final deploymentName = 'gpt-4.1-mini'; // Based on user instruction

    if (endpoint.isEmpty || key.isEmpty) {
      return "API keys for Azure OpenAI are not configured.";
    }

    // Prepare Base64 Image
    final base64Image = base64Encode(imageBytes);

    final url = Uri.parse('https://occipital-east-resource.services.ai.azure.com/openai/v1/chat/completions');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'api-key': key,
      },
      body: jsonEncode({
        "model": deploymentName,
        "messages": [
          {
            "role": "system",
            "content": systemPrompt
          },
          {
            "role": "user",
            "content": [
              {"type": "text", "text": prompt},
              {
                "type": "image_url",
                "image_url": {
                  "url": "data:image/jpeg;base64,$base64Image"
                }
              }
            ]
          }
        ],
        "max_tokens": 300,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      debugPrint('Azure OpenAI Error: ${response.statusCode} - ${response.body}');
      return "Error: Unable to generate response from Azure OpenAI.";
    }
  }

  /// Sends visual and contextual data to the reasoning agent for advanced processing.
  Future<String?> processWithAgenticReasoning({
    required Uint8List imageBytes,
    required String userPrompt,
    Map<String, dynamic>? contextData,
    Function(String status)? onStatusUpdate,
  }) async {
    debugPrint('🧠 OccipitalAgentService: Routing payload...');
    debugPrint('   - Prompt: $userPrompt');
    
    final layer = _classifyIntent(userPrompt);

    switch (layer) {
      case OccipitalLayer.macro:
        onStatusUpdate?.call('Fetching GPS & Weather...');
        return await _handleMacroLayer(userPrompt);
      case OccipitalLayer.critical:
        onStatusUpdate?.call('Querying Secure Medical Database...');
        return await _handleCriticalLayer(userPrompt, imageBytes);
      case OccipitalLayer.micro:
      default:
        onStatusUpdate?.call('Analyzing Vision...');
        return await _handleMicroLayer(userPrompt, imageBytes);
    }
  }

  /// Handles graceful shutdown of the service connection.
  Future<void> dispose() async {
    debugPrint('🔌 OccipitalAgentService: Disposing connections...');
    _isInitialized = false;
  }
}

