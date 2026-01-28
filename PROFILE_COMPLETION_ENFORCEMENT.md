# Profile Completion Enforcement

## Overview
This document describes the implementation of profile completion enforcement for users who fail to complete their registration.

## Problem
Previously, if a user failed to complete their profile during registration (e.g., closed the app on the AccountCompletionScreen), they would be able to access the HomeScreen directly on subsequent logins without completing their profile.

## Solution
The solution involves checking the user's profile completion status during the splash screen initialization and redirecting them to the AccountCompletionScreen if their profile is incomplete.

### Implementation Details

#### 1. Profile Completion Check (`_checkProfileCompletion`)
A new method was added to `SplashScreen.dart` that checks if the user's profile is complete by examining the `first_name` field in SharedPreferences:

```dart
Future<bool> _checkProfileCompletion() async {
  final prefs = await SharedPreferences.getInstance();
  final firstName = prefs.getString('first_name');
  
  // Profile is incomplete if first_name is null, empty, or 'unnamed'
  final needsCompletion = firstName == null || 
                          firstName.isEmpty || 
                          firstName.toLowerCase() == 'unnamed';
  
  return needsCompletion;
}
```

#### 2. Updated Navigation Logic (`_navigate`)
The `_navigate` method was made async and updated to check for profile completion before navigating to HomeScreen:

```dart
Future<void> _navigate() async {
  if (_isLoggedIn) {
    // Check if user profile needs completion
    final needsCompletion = await _checkProfileCompletion();
    
    if (needsCompletion) {
      // Redirect to AccountCompletionScreen with stored tokens and user data
      Navigator.of(context).pushReplacement(
        createRoute(
          AccountCompletionScreen(
            accessToken: accessToken,
            csrfToken: csrfToken,
            userData: userData,
          ),
        ),
      );
    } else {
      // Profile is complete, go to HomeScreen
      Navigator.of(context).pushReplacement(createRoute(const HomeScreen()));
    }
  } else {
    // User not logged in, show onboarding
    Navigator.of(context).pushReplacement(createRoute(const OnboardingScreen()));
  }
}
```

#### 3. Import Added
Added the necessary import for `AccountCompletionScreen`:
```dart
import 'package:exanor/screens/account_completion_screen.dart';
```

## User Flow

### For Users with Incomplete Profiles:
1. User opens the app
2. SplashScreen checks authentication (access token exists)
3. SplashScreen fetches and validates user data via `UserService.viewUserData()`
4. `_checkProfileCompletion()` detects incomplete profile (first_name is 'unnamed', null, or empty)
5. User is redirected to `AccountCompletionScreen` with their stored tokens and user data
6. User must complete their profile before accessing the app

### For Users with Complete Profiles:
1. User opens the app
2. SplashScreen checks authentication
3. Profile is complete
4. User goes directly to HomeScreen

## Testing Scenarios

### Test Case 1: New User Registration
1. User enters phone number
2. User verifies OTP
3. User is redirected to AccountCompletionScreen
4. User closes app without completing profile
5. **Expected**: On next login, user is redirected to AccountCompletionScreen

### Test Case 2: User Completes Profile
1. User completes profile on AccountCompletionScreen
2. User is redirected to HomeScreen
3. User closes app
4. **Expected**: On next login, user goes directly to HomeScreen

### Test Case 3: Existing User
1. User with completed profile logs in
2. **Expected**: User goes directly to HomeScreen

## Benefits
- **Data Integrity**: Ensures all users have complete profiles before using the app
- **User Experience**: Prevents users from accessing the app with incomplete information
- **Consistent State**: Maintains consistency between new and returning users
- **Easy to Maintain**: Centralized logic in SplashScreen makes it easy to modify behavior

## Future Enhancements
- Add more granular profile completion checks (e.g., check for date_of_birth, gender, etc.)
- Add a "Skip for now" option with limitations on app features
- Add analytics to track profile completion rates
- Implement server-side validation to ensure profile completeness
