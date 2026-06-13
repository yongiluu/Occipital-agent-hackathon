import 'package:flutter_test/flutter_test.dart';
import 'package:iris_app/services/ai/vision_service.dart';
import 'package:iris_app/services/ai/context_manager.dart';

void main() {
  group('VisionService Tests', () {
    final visionService = VisionService();

    test('Mobility intent detection', () {
      expect(visionService.isMobilityIntent('how do i get to the bathroom'), isTrue);
      expect(visionService.isMobilityIntent('guide my steps to the door'), isTrue);
      expect(visionService.isMobilityIntent('what is on my left'), isTrue);
      expect(visionService.isMobilityIntent('what color is the shirt'), isFalse);
    });

    test('Mobility response sanitization', () {
      const validResponse = 'Turn left and take 2 steps.';
      expect(visionService.sanitizeMobilityResponse(validResponse), equals(validResponse));

      const invalidResponse = 'Go to the red bathroom.';
      expect(visionService.sanitizeMobilityResponse(invalidResponse), contains('Inexact direction'));
    });
  });

  group('ConversationContextManager Tests', () {
    final manager = ConversationContextManager();

    test('Consistent hashing', () {
      final base64Dummy = List.filled(200, 'A').join();
      final hash1 = manager.generateHash(base64Dummy);
      
      // Must contain the same truncated prefix length
      expect(hash1.startsWith(List.filled(64, 'A').join()), isTrue);
    });

    test('Image validation', () {
      final base64Dummy = List.filled(200, 'B').join();
      manager.updateContext(base64Dummy, 'Summary B');
      
      expect(manager.isSameImage(base64Dummy), isTrue);
      
      manager.invalidate();
      expect(manager.isSameImage(base64Dummy), isFalse);
    });
  });
}

