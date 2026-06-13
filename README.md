# Iris - Visual Assistant POC

## Description
Iris is a Proof of Concept (POC) Flutter application built for the Microsoft Agents League Hackathon. It serves as a visual assistant designed to help users interact with their environment using real-time camera feeds, speech recognition, and Text-to-Speech (TTS) capabilities. The project is structured to integrate seamlessly with the Microsoft IQ intelligence layer (Foundry IQ, Work IQ, or Fabric IQ) and Azure AI services.

## Architecture
This project follows **Clean Architecture** tailored for Flutter to ensure separation of concerns, scalability, and testability.

### Project Structure
- **`lib/core/`**: Core configurations, themes, constants, and utilities.
- **`lib/features/`**: Feature-specific UI screens, widgets, and business logic (e.g., Assistant feature).
- **`lib/services/`**: Abstractions and implementations for hardware (Camera, Haptics) and AI services (Speech, TTS, Vision).
    - **`OccipitalAgentService`**: Central connection point designed for integration with Azure and Microsoft Foundry.

### Key Components
- **Flutter Frontend**: Provides the user interface, camera rendering, and haptic feedback.
- **AI Integrations**: Ready for integration with Microsoft Foundry/Azure for advanced reasoning and visual analysis.

## Requirements
- **Flutter SDK**: >=3.0.0 (Recommended latest stable)
- **Dart SDK**: >=3.0.0
- **Android Studio / VS Code**: With Flutter & Dart plugins installed.
- **Physical Device**: A physical Android or iOS device is recommended to test Camera, Speech Recognition, and Haptics.

## Setup and Installation
1. Clone the repository:
   ```bash
   git clone <repository_url>
   ```
2. Navigate to the app directory:
   ```bash
   cd iris_app
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the application:
   ```bash
   flutter run
   ```

## Contribution Guidelines
This project is part of the Microsoft Agents League Hackathon. Please ensure all code adheres to Clean Architecture patterns and is properly translated to English before opening a PR.

## License
MIT License
"# Occipital-agent-hackathon" 
