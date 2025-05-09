# SistLink - Social and Event Management App

SistLink is a feature-rich mobile and web application built with Flutter and Firebase. It aims to provide a platform for social interaction, real-time communication, and event organization.

## Key Features

*   **User Authentication:** Secure signup, login, and password reset functionality.
*   **User Profiles:** Viewable user profiles with usernames, bios, online status, and follower/following counts. Users can edit their own profiles.
*   **Social Feed & Interactions:**
    *   Create text-based posts.
    *   View a personalized feed of posts from followed users.
    *   Like and comment on posts.
    *   Search for other users.
*   **Real-time Chat:**
    *   1-to-1 private messaging.
    *   Group chat functionality with group creation.
    *   View group information (participants, admins) and leave groups.
    *   Quick navigation to user profiles from 1-to-1 chat screens.
    *   Online status indicators for users.
*   **Event Management:**
    *   Create new events with details (name, description, location, date/time).
    *   List all upcoming events.
    *   View detailed information for each event, including a list of attendee usernames.
    *   RSVP to events.
    *   Event creators can edit or delete their events.
*   **Admin Panel (Basic):**
    *   Designated admin users can access an admin dashboard.
    *   View a list of all application users.
    *   Toggle admin status and ban/unban users.
    *   Banned users are prevented from logging in.
*   **Responsive UI:**
    *   Mobile-first design with `MobileScreenLayout`.
    *   Basic responsive web layout (`WebScreenLayout`) with side navigation for wider screens.
*   **Push Notifications:**
    *   Client-side setup for receiving push notifications.
    *   Backend Cloud Function written for new chat message notifications (deployment pending Firebase plan upgrade).

## Technologies Used

*   **Flutter:** For cross-platform (iOS, Android, Web) UI development.
*   **Dart:** Programming language for Flutter.
*   **Firebase:**
    *   **Firebase Authentication:** For user management.
    *   **Cloud Firestore:** As the NoSQL database for storing all application data (users, posts, chats, events, etc.).
    *   **Firebase Cloud Messaging (FCM):** For push notification capabilities (client-side integration and basic backend function).
    *   **(Firebase Storage):** Planned for media uploads (profile pictures, post images, chat media) - full integration pending Firebase plan upgrade.
*   **Firebase Cloud Functions:** For backend logic, such as sending notifications (functions written, deployment pending).

## Getting Started

This project is a Flutter application. To get started with Flutter development, view the [online documentation](https://docs.flutter.dev/).

To run this project:
1.  Ensure you have Flutter installed.
2.  Set up a Firebase project and configure it for Android, iOS, and Web.
    *   Place your `google-services.json` in `android/app/`.
    *   Place your `GoogleService-Info.plist` in `ios/Runner/`.
    *   Ensure your `lib/firebase_options.dart` is correctly configured for all platforms.
3.  Run `flutter pub get` to install dependencies.
4.  Run the app using `flutter run` (for mobile) or `flutter run -d chrome` (for web).
