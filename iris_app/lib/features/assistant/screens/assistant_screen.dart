/// ============================================================================
/// IRIS - Main Assistant Screen
/// ============================================================================

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/hardware/camera_service.dart';
import '../../../services/ai/vision_service.dart';
import '../../../services/ai/tts_service.dart';
import '../../../services/hardware/haptic_service.dart';
import '../../../services/ai/speech_service.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen>
    with TickerProviderStateMixin {
  // ─── Services ───
  final CameraService _cameraService = CameraService();
  final VisionService _visionService = VisionService();
  final TtsService _ttsService = TtsService();
  final HapticService _hapticService = HapticService();
  final SpeechService _speechService = SpeechService();

  // ─── State ───
  bool _isListening = false;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String _lastDescription = '';
  String _statusText = 'Press and hold the microphone to speak';
  
  // ─── Physical Button Control ───
  DateTime? _lastVolumeUpTime;
  bool _isAutoListening = false;
  
  // ─── Continuous Mode ───
  bool _continuousMode = false;
  Timer? _continuousTimer;
  int _consecutiveCount = 0;

  // ─── Animations ───
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const MethodChannel _volumeChannel = MethodChannel('com.iris.visual.iris_app/volume');

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initServices();
    _volumeChannel.setMethodCallHandler(_handleVolumeChannel);
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();
  }

  Future<void> _initServices() async {
    try {
      _speechService.onSpeechDone = () {
        if (_isAutoListening && _isListening) {
          _stopPTTAndProcess();
        }
      };

      await Future.wait<void>([
        _cameraService.initialize(),
        _ttsService.initialize(),
        _hapticService.initialize(),
        _speechService.initialize(),
      ]);

      setState(() => _isInitialized = true);

      await _ttsService.speakStatus(
        'Iris is ready. Press and hold the microphone to speak.',
      );
    } catch (e) {
      setState(() {
        _statusText = 'Error initializing: $e';
      });
      debugPrint('⚠️ Error initializing services: $e');
    }
  }

  // ─── Continuous Mode ───
  void _toggleContinuousMode(bool value) async {
    setState(() {
      _continuousMode = value;
    });
    if (_continuousMode) {
      _consecutiveCount = 0;
      debugPrint('📍 SENSORS: 12.1 Continuous mode activated');
      await _ttsService.speak('Continuous mode activated');
      _startContinuousMode();
    } else {
      _continuousTimer?.cancel();
      _consecutiveCount = 0;
      await _ttsService.speak('Continuous mode deactivated');
    }
  }

  void _startContinuousMode() {
    _continuousTimer?.cancel();
    
    if (_consecutiveCount == 0) {
      debugPrint('📍 SENSORS: 12.1 Continuous mode: immediate initial capture');
      _captureAndDescribeContinuous();
      _consecutiveCount++;
    }

    _continuousTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      if (_consecutiveCount >= 3) {
        _pauseContinuousMode();
        return;
      }
      
      // Do not interrupt if user is interacting
      if (_isListening || _isProcessing) return;

      debugPrint('📍 SENSORS: 12.1 Continuous mode: capture #$_consecutiveCount');
      await _captureAndDescribeContinuous();
      _consecutiveCount++;
    });
  }

  void _pauseContinuousMode() {
    _continuousTimer?.cancel();
    debugPrint('📍 SENSORS: 12.2 Cooldown applied (60s)');
    Future.delayed(const Duration(seconds: 60), () {
      _consecutiveCount = 0;
      if (mounted && _continuousMode) {
        _startContinuousMode();
      }
    });
  }

  Future<void> _captureAndDescribeContinuous() async {
    final Uint8List? imageBytes = await _cameraService.captureSingleFrame();
    if (imageBytes == null) return;
    
    final String? desc = await _visionService.analyzeContinuousMode(imageBytes);
    if (desc != null && mounted) {
      setState(() {
        _lastDescription = desc.replaceAll(RegExp(r'^\[(en|es)\]\s*', caseSensitive: false), '');
      });
      debugPrint('📍 SENSORS: 12.5 Sending to TTS: "$desc"');
      await _ttsService.speak(desc);
      _resetState(null); // Ensure UI refreshes if necessary
    }
  }

  // ─── Push-To-Talk (PTT) ───
  Future<void> _startPTT() async {
    if (_isListening || _isProcessing) return;

    if (_continuousMode) _continuousTimer?.cancel();
    _visionService.contextManager.invalidate();
    await _ttsService.stop();

    try {
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate(duration: 50);
      }
    } catch (_) {}
    SystemSound.play(SystemSoundType.click);

    debugPrint('📍 SENSORS: 9.3 PTT activated');

    setState(() {
      _isListening = true;
      _statusText = 'Listening...';
    });

    _pulseController.repeat(reverse: true);
    await _speechService.startListening();
  }

  Future<void> _stopPTTAndProcess() async {
    if (!_isListening) return;
    _isAutoListening = false;
    
    debugPrint('📍 SENSORS: 9.4 PTT released -> request sent');
    
    _pulseController.stop();
    _pulseController.reset();

    String prompt = await _speechService.stopListening();
    
    if (prompt.isEmpty) {
      debugPrint('📍 SENSORS: 9.4 Empty recognition');
      _resetState('I didn\'t understand, please try again');
      await _ttsService.speak('I didn\'t understand, please try again');
      return;
    }

    // ─── Voice Commands for Continuous Mode ───
    final lowerPrompt = prompt.toLowerCase();
    final activateKeywords = ['activate continuous mode', 'continuous description', 'active eyes mode', 'describe all the time', 'activa el modo continuo', 'descripción continua', 'modo ojos activos', 'describe todo el tiempo'];
    final deactivateKeywords = ['stop describing', 'deactivate continuous', 'deja de describir', 'desactiva continuo'];
    
    if (activateKeywords.any((k) => lowerPrompt.contains(k))) {
       debugPrint('📍 SENSORS: 13.1 Continuous mode activated by voice');
       _resetState('Activating continuous mode...');
       _toggleContinuousMode(true);
       return;
    } else if (deactivateKeywords.any((k) => lowerPrompt.contains(k))) {
       debugPrint('📍 SENSORS: 13.2 Continuous mode deactivated by voice');
       _resetState('Deactivating continuous mode...');
       _toggleContinuousMode(false);
       return;
    }

    setState(() {
      _isListening = false;
      _isProcessing = true;
      _statusText = 'Analyzing...';
    });

    Uint8List? imageBytes = await _cameraService.captureSingleFrame();
    
    try {
      final String? description = await _visionService.analyzeImage(imageBytes, prompt: prompt);
      
      _resetState(null);
      setState(() {
        _lastDescription = (description ?? 'No response obtained.').replaceAll(RegExp(r'^\[(en|es)\]\s*', caseSensitive: false), '');
      });

      if (description != null) {
        await _ttsService.speak(description);
      }
    } catch (e) {
      _resetState('Service error.');
    }

    // Resume continuous mode if active
    if (_continuousMode && _consecutiveCount < 2) {
      _startContinuousMode();
    }
  }

  void _resetState(String? errorMessage) {
    debugPrint('📍 SENSORS: 9.5 State reset to idle post-TTS');
    if (mounted) {
      setState(() {
         _isListening = false;
         _isProcessing = false;
         _statusText = errorMessage ?? 'Press and hold the microphone to speak';
      });
    }
  }

  // ─── Native Physical Events (Volume Button via MethodChannel) ───
  Future<void> _handleVolumeChannel(MethodCall call) async {
    if (call.method == 'volumeUpPressed') {
      final now = DateTime.now();
      if (_lastVolumeUpTime != null && now.difference(_lastVolumeUpTime!) < const Duration(milliseconds: 300)) {
        _lastVolumeUpTime = null; // Reset
        _onDoubleTapVolumeUp();
      } else {
        _lastVolumeUpTime = now;
      }
    }
  }

  Future<void> _onDoubleTapVolumeUp() async {
    if (_isListening || _isProcessing) return;
    
    debugPrint('📍 SENSORS: 9.4 Volume double tap detected');
    _isAutoListening = true;
    
    if (_continuousMode) _continuousTimer?.cancel();
    _visionService.contextManager.invalidate();
    await _ttsService.stop();
    
    try {
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate(duration: 50);
      }
    } catch (_) {}
    SystemSound.play(SystemSoundType.click);

    setState(() {
      _isListening = true;
      _statusText = 'Listening...';
    });
    
    _pulseController.repeat(reverse: true);
    
    await _ttsService.speak('Hello, Iris activated, how can I help you?');
    // Wait for TTS to finish speaking (approx 2.5s)
    await Future.delayed(const Duration(milliseconds: 2500));
    
    if (_isListening) {
      await _speechService.startListening();
    }
  }

  @override
  void dispose() {
    _volumeChannel.setMethodCallHandler(null);
    _continuousTimer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    _cameraService.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_cameraService.controller != null && _cameraService.controller!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraService.controller!.value.previewSize?.height ?? 1,
                  height: _cameraService.controller!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_cameraService.controller!),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan)),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildTopStatus(),
                          if (_lastDescription.isNotEmpty) _buildDescriptionOverlay(),
                        ],
                      ),
                    ),
                  ),
                  _buildFloatingButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStatus() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isListening ? Colors.redAccent.withValues(alpha: 0.8) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isListening ? 'LISTENING...' : 'IRIS READY',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                Row(
                  children: [
                    const Text('Continuous', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Switch(
                      value: _continuousMode,
                      onChanged: _toggleContinuousMode,
                      activeColor: AppTheme.accentCyan,
                    ),
                  ],
                ),
              ],
            ),
            if (_statusText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _statusText,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.left,
                ),
              ),
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionOverlay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.spatial_audio_off, color: AppTheme.accentCyan, size: 18),
                SizedBox(width: 8),
                Text(
                  'LAST DESCRIPTION',
                  style: TextStyle(
                    color: AppTheme.accentCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _lastDescription,
              style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
              maxLines: null,
              textAlign: TextAlign.justify,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 48.0),
      child: GestureDetector(
        onPanStart: (_) => _startPTT(),
        onTapDown: (_) => _startPTT(),
        onPanEnd: (_) => _stopPTTAndProcess(),
        onTapUp: (_) => _stopPTTAndProcess(),
        onTapCancel: () => _stopPTTAndProcess(),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isListening ? _pulseAnimation.value : 1.0,
              child: child,
            );
          },
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening ? Colors.redAccent.withValues(alpha: 0.8) : AppTheme.primaryCyan.withValues(alpha: 0.8),
              boxShadow: [
                BoxShadow(
                  color: _isListening ? Colors.redAccent.withValues(alpha: 0.4) : AppTheme.primaryCyan.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
