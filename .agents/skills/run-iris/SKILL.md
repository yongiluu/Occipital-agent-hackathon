---
name: run-iris
description: >-
  Cleans, downloads dependencies, and runs the Iris Flutter app on the default device.
---

# Run Iris

## Overview
This skill automates the clean build flow for the Iris application. It performs three sequential steps: cleans the previous build, resolves dependencies, and launches the application.

## Workflow

### 1. Clean Rebuild
- Navigate to the application directory: `D:/proyectos/OccipitalHackaton/iris_app`
- Execute sequentially in a single command line: `flutter clean`, `flutter pub get`, `flutter run`

### 2. Monitoring
- Notify the user that the process has been launched in the background.
- Keep the task running to allow subsequent use of Hot Reload (`r`).
