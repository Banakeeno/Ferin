# Ferin iOS App

A beautiful iOS app with Firebase Authentication integration.

## Features

- 🔐 **Email/Password Authentication** - Sign up and sign in with email
- 🌟 **Google Sign-In** - Quick authentication with Google
- 🔄 **Password Reset** - Secure password recovery
- 📱 **Modern UI** - Beautiful, responsive SwiftUI interface
- 🔒 **Secure** - Firebase Auth handles all security

## Setup Instructions

### 1. Firebase Configuration

The app is already configured with Firebase. The `GoogleService-Info.plist` file contains:
- Project ID: `ferin-a643e`
- Bundle ID: `Alo.bankin.Ferin`

### 2. Xcode Project Setup

If you're using Xcode:

1. **Add Firebase SDK**: 
   - Go to File → Add Package Dependencies
   - Add: `https://github.com/firebase/firebase-ios-sdk`
   - Select: `FirebaseAuth` and `FirebaseCore`

2. **Add Google Sign-In SDK**:
   - Add: `https://github.com/google/GoogleSignIn-iOS`
   - Select: `GoogleSignIn`

3. **Configure URL Scheme**:
   - In your Xcode project, go to your app target's Info tab
   - In the URL Types section, add a new URL scheme
   - Set the URL scheme to your `REVERSED_CLIENT_ID` from GoogleService-Info.plist

### 3. Authentication Methods

#### Email/Password
- Users can create accounts with email and password
- Password requirements are handled by Firebase
- Email verification available

#### Google Sign-In
- One-tap sign-in with Google accounts
- Seamless integration with Firebase Auth
- Automatic account linking

#### Password Reset
- Send password reset emails
- Secure reset process through Firebase

### 4. Usage

The app automatically handles authentication state:
- Shows login screen when user is not authenticated
- Shows main app content when user is signed in
- Persists authentication across app launches

## File Structure

```
├── FerinApp.swift              # Main app entry point with Firebase config
├── ContentView.swift           # Main content view
├── MainAppView.swift           # Handles auth state routing
├── LoginView.swift             # Beautiful login/signup UI
├── AuthenticationManager.swift # Firebase Auth logic
├── GoogleService-Info.plist    # Firebase configuration
└── README.md                   # This file
```

## Authentication Flow

1. **App Launch** → Check if user is signed in
2. **Not Signed In** → Show LoginView
3. **Sign In/Up** → Authenticate with Firebase
4. **Success** → Navigate to main app content
5. **Sign Out** → Return to LoginView

## Security Features

- Secure password storage (handled by Firebase)
- Email verification
- Password reset functionality
- Token-based authentication
- Automatic session management

## Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 15.0+

## Support

For issues with Firebase setup, refer to:
- [Firebase iOS Documentation](https://firebase.google.com/docs/ios/setup)
- [Google Sign-In Documentation](https://developers.google.com/identity/sign-in/ios)