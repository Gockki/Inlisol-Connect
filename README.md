# InliConnect Mobile Application

## Overview

InliConnect is a secure mobile application designed for enterprise IoT device management and tracking. The application provides a comprehensive solution for monitoring and managing connected devices across multiple organizational levels.

## Key Features

- **Secure Authentication**: Robust login system with token-based authentication
- **Hierarchical Navigation**: Intuitive multi-level navigation through organizational structure
- **Device Monitoring**: Real-time tracking and status updates for IoT devices
- **Location Tracking**: Advanced visualization of device locations
- **QR Code Integration**: Seamless device and room management

## Technical Architecture

- **Platform**: Flutter/Dart
- **Authentication**: Bearer token-based
- **Background Processing**: WorkManager for periodic tasks
- **Notifications**: Firebase Messaging and Local Notifications
- **State Management**: Native Flutter state management

## Security Considerations

- Secure token storage
- Encrypted local storage
- Comprehensive error handling
- Minimal local data caching

## Setup and Configuration

### Prerequisites

- Flutter SDK (latest stable version)
- Android Studio or VS Code
- Firebase project setup

### Environment Setup

1. Clone the repository
2. Run `flutter pub get`
3. Configure Firebase credentials
4. Run `flutter run`

## Deployment Notes

- Supports Android platforms
- Requires active network connection
- Periodic background synchronization

## Confidentiality Notice

*This project contains proprietary and confidential information. Unauthorized use, reproduction, or distribution is strictly prohibited.*

## Contact

For any technical inquiries, please contact the development team through official channels.

---

*© [2025] Inlisol. All Rights Reserved.*
