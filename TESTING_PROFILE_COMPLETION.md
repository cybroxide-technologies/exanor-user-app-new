# Testing Guide: Profile Completion Enforcement

## How to Test

### Scenario 1: New User Abandons Profile Completion
**Steps:**
1. Start the app fresh (no existing user data)
2. On the login screen, enter a phone number
3. Verify the OTP code
4. You should be redirected to the Account Completion Screen
5. **DO NOT** fill out the form - instead, close the app completely
6. Reopen the app
7. **Expected Result**: You should be redirected back to the Account Completion Screen

### Scenario 2: User Completes Profile
**Steps:**
1. Follow steps 1-4 from Scenario 1
2. Fill out all required fields (First Name, Last Name, Gender, Date of Birth)
3. Click "Continue"
4. You should be redirected to the Location Selection or Home Screen
5. Close the app
6. Reopen the app
7. **Expected Result**: You should go directly to the Home Screen (no Account Completion Screen)

### Scenario 3: Existing User with Complete Profile
**Steps:**
1. Login with an account that has a complete profile
2. Use the app normally
3. Close the app
4. Reopen the app
5. **Expected Result**: You should go directly to the Home Screen

## Debug Logging

When testing, check the Flutter console logs for these messages:

### Profile Incomplete:
```
⚠️ Profile incomplete - first_name: unnamed
🔄 Redirecting to AccountCompletionScreen - profile incomplete
```

### Profile Complete:
```
✅ Profile complete - first_name: John
```

## Manual Testing with SharedPreferences

To manually test different profile states, you can clear SharedPreferences or modify the `first_name` value:

### Clear All Data (Simulate New User):
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.clear();
```

### Simulate Incomplete Profile:
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('access_token', 'some_token');
await prefs.setString('csrf_token', 'some_csrf');
await prefs.setString('first_name', 'unnamed'); // This triggers the check
```

### Simulate Complete Profile:
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('access_token', 'some_token');
await prefs.setString('csrf_token', 'some_csrf');
await prefs.setString('first_name', 'John'); // Profile is complete
await prefs.setString('last_name', 'Doe');
```

## Edge Cases to Test

1. **Network Failure During Profile Completion**
   - Start profile completion
   - Disconnect internet
   - Try to submit
   - **Expected**: Error message shown, user stays on Account Completion Screen
   - Reconnect and try again
   - **Expected**: Profile completes successfully

2. **App Killed During API Call**
   - Start profile completion
   - Submit the form
   - Kill the app immediately
   - Reopen the app
   - **Expected**: 
     - If profile saved on backend: User goes to Home Screen
     - If profile not saved: User redirected to Account Completion Screen

3. **Multiple Login/Logout Cycles**
   - Complete profile
   - Logout
   - Login again with same phone
   - **Expected**: User goes directly to Home Screen

## Verification Checklist

- [ ] New users who abandon profile completion are redirected back
- [ ] Users can complete their profile and access the app
- [ ] Completed profiles don't get asked to complete again
- [ ] Logout/Login doesn't break the flow
- [ ] Network errors are handled gracefully
- [ ] Profile data is preserved across app restarts

## Common Issues and Solutions

### Issue: User stuck in loop on Account Completion Screen
**Cause**: Profile update API call might be failing
**Solution**: Check network logs, verify API endpoint is working

### Issue: User goes to Home Screen despite incomplete profile
**Cause**: `first_name` in SharedPreferences might have a value other than 'unnamed'
**Solution**: Check SharedPreferences data, ensure new users get 'unnamed' default

### Issue: User forced to complete profile when it's already complete
**Cause**: SharedPreferences might be cleared or corrupted
**Solution**: Clear app data and try fresh login
