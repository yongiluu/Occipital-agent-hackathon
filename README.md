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


# Occipital Agent - Test Results

This document records the successful integration tests of the three core layers of the Occipital Agent architecture during the Microsoft Agents League Hackathon.

## 1. Macro Layer (Navigation & Environment)
- **User Prompt:** "Where am I?" / "What is the weather?"
- **Integration Used:** LocationIQ (Reverse Geocoding) + OpenWeatherMap
- **Result:** **SUCCESS**
- **Description:** The heuristic router successfully classified the intent as a Macro request. The system fetched the hardcoded/GPS coordinates, reverse-geocoded them into a street address (e.g., UdeC campus), retrieved the current temperature and conditions, and presented a concatenated environmental awareness string to the user.

## 2. Micro Layer (General Vision)
- **User Prompt:** "What is in front of me?" / Image capture
- **Integration Used:** Azure OpenAI (GPT-4.1-mini Vision)
- **Result:** **SUCCESS**
- **Description:** The system accurately captured a frame from the camera, encoded it in base64, and sent it to the Azure OpenAI gateway endpoint. The model successfully recognized the objects in the image and returned a highly descriptive and empathetic response for the visually impaired user.

## 3. Critical Layer (Medical/Safety Queries)
- **User Prompt:** "Are there contraindications for this insulin?"
- **Integration Used:** Azure AI Search (`insulina-fda-kb`) + Azure OpenAI (GPT-4.1-mini)
- **Result:** **SUCCESS**
- **Description:** The system detected a critical medical keyword ("insulin"). It first queried the Foundry IQ secure knowledge base using Azure AI Search to retrieve the top 3 relevant FDA guidelines chunks. Then, it securely formatted the context to avoid jailbreak filters and sent it to Azure OpenAI. The final response strictly adhered to the retrieved FDA guidelines without hallucinations.

---
*Testing completed with 0 errors. The Three-Layer Architecture is fully functional.*

