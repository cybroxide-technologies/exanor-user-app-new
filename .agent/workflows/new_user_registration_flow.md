---
description: New user registration flow with account completion
---

# New User Registration Flow

This workflow documents the enhanced registration flow that handles both registered and unregistered users.

## Overview

The app now intelligently routes users based on their registration status:
- **Registered users** (with complete profile) → Go directly to HomeScreen
- **New users** (with default/incomplete profile) → Go to AccountCompletionScreen first

## Flow Diagram

```
Phone Input → OTP Verification → API Response
                                      ↓
                        ┌─────────────┴─────────────┐
                        ↓                           ↓
                "Login successful"          "User created"
                        ↓                           ↓
                   HomeScreen              Check Profile Completeness
                                                    ↓
                                    ┌───────────────┴───────────────┐
                                    ↓                               ↓
                            Incomplete Profile              Complete Profile
                                    ↓                               ↓
                        AccountCompletionScreen                HomeScreen
```

## API Response Handling

### Registered User Response
```json
{
    "status": 200,
    "message": "Login successful",
    "access_token": "...",
    "csrf_token": "...",
    "user_data": {
        "first_name": "Gourav",
        "last_name": "Dash",
        "gender": "male",
        ...
    }
}
```

### New User Response
```json
{
    "status": 200,
    "message": "User created",
    "access_token": "...",
    "csrf_token": "...",
    "user_data": {
        "first_name": "unnamed",
        "last_name": "user",
        "gender": "undefined",
        ...
    }
}
```

## Implementation Details

### 1. OTP Verification Screen (`otp_verification_screen.dart`)
- Enhanced `_verifyOTP()` method to check response message
- Detects if user is registered or newly created
- Routes to appropriate screen based on profile completeness

**Profile Completion Check:**
```dart
final needsProfileCompletion = 
    firstName == 'unnamed' ||
    lastName == 'user' ||
    gender == 'undefined' ||
    firstName == null ||
    lastName == null ||
    gender == null;
```

### 2. Account Completion Screen (`account_completion_screen.dart`)

**Features:**
- Beautiful animated UI with fade and slide transitions
- Required fields: First Name, Last Name, Gender
- Optional field: Email
- Gender selector with three options (Male, Female, Other)
- Visual feedback with smooth animations
- Form validation

**API Integration:**
- Calls `/update-profile/` endpoint with PATCH method
- Sends updated user data
- Stores updated data locally
- Navigates to HomeScreen on success

**Required Data Structure:**
```dart
{
  'first_name': 'John',
  'last_name': 'Doe',
  'gender': 'male',
  'email': 'john@example.com'  // Optional
}
```

## UI/UX Features

### Animations
1. **Fade Animation**: Screen fades in on mount (800ms)
2. **Slide Animation**: Content slides up from bottom (cubic ease-out)
3. **Field Animations**: Input fields scale and fade in with stagger effect
4. **Gender Selection**: Smooth color/border transitions (300ms)
5. **Button State**: Loading indicator with smooth transitions

### Design Elements
- Gradient accent bar at top for visual interest
- Large, clear typography for headings
- Subtle shadows and borders
- Rounded corners (16px) for modern feel
- Icon-enhanced input fields
- Visual gender selector buttons
- Floating label style for better UX

### Color Scheme
- Primary: Theme's primary color (typically purple/indigo)
- Backgrounds: Surface variants with opacity
- Text: Proper contrast ratios for accessibility
- Borders: Subtle outlines that strengthen on focus

## Testing Checklist

- [ ] New user sees AccountCompletionScreen after OTP
- [ ] Existing user goes directly to HomeScreen
- [ ] All animations play smoothly
- [ ] Form validation works correctly
- [ ] Email field is truly optional
- [ ] Gender selection updates UI
- [ ] Profile update API call succeeds
- [ ] Local storage updates correctly
- [ ] Navigation to HomeScreen works
- [ ] Error states display properly

## API Endpoints Used

1. **Send OTP**: `POST /send-otp/`
2. **Verify & Sign Up**: `POST /sign-up/`
3. **Update Profile**: `PATCH /update-profile/`

## Files Modified/Created

### Created
- `lib/screens/account_completion_screen.dart`
- `.agent/workflows/new_user_registration_flow.md`

### Modified
- `lib/screens/otp_verification_screen.dart`
- `lib/main.dart`

## Future Enhancements

1. Add profile picture upload on completion screen
2. Add date of birth field
3. Add address fields (optional)
4. Implement progress indicator for multi-step forms
5. Add skip option with reminder later
6. Add welcome message/tutorial after completion
