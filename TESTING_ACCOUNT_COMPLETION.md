## Testing the Account Completion Flow

### Running the Test

1. **Start the app**:
   ```bash
   flutter run
   ```

2. **Register with a new phone number** that hasn't been used before

3. **Check the console logs** - You should see detailed output like:

   ```
   📞 Verifying OTP for phone: 918446097001
   🔢 OTP Code: 1234
   📨 Sign-up Response: {...}
   📊 Response Status: 200
   📝 Response Message: User created
   ✅ Authentication successful - storing tokens and user data
   🎉 All data stored successfully
   👤 User Data Received:
      - First Name: "unnamed"
      - Last Name: "user"
      - Gender: "undefined"
   🔍 Profile Completion Check:
      - firstName == "unnamed": true
      - lastName == "user": true
      - gender == "undefined": true
      - firstName == null: false
      - lastName == null: false
      - gender == null: false
      - Needs Completion: true
   📝 ✅ NAVIGATING TO AccountCompletionScreen
   ```

### Expected Behavior

**For NEW users (User created):**
- Should see "User created" message
- Should automatically navigate to **AccountCompletionScreen**
- No manual action needed

**For EXISTING users (Login successful):**
- Should see "Login successful" message  
- Should automatically navigate to **HomeScreen**

### Common Issues & Solutions

#### Issue 1: Still going to HomeScreen
**Cause**: The user data might not have "unnamed", "user", or "undefined" values  
**Solution**: Check the console logs to see what values `first_name`, `last_name`, and `gender` actually have

#### Issue 2: Showing alert instead of navigating
**Cause**: There might be an error dialog or snackbar appearing
**Solution**: Check if there's an error in the console logs before the navigation

#### Issue 3: App crashes on navigation
**Cause**: AccountCompletionScreen might have a build error
**Solution**: Check the console for stack traces

### Debugging Steps

1. **Enable verbose logging**:
   Run the app with:
   ```bash
   flutter run -v
   ```

2. **Check the exact response**:
   Look for the line that says `📨 Sign-up Response:` and verify the structure

3. **Verify the import**:
   Make sure `account_completion_screen.dart` is imported in `otp_verification_screen.dart`

4. **Hot restart** (not hot reload):
   Press `R` in the terminal to do a full restart

### Manual Test Cases

| Test Case | Phone Number | OTP | Expected Screen | Expected Logs |
|-----------|--------------|-----|----------------|---------------|
| New User | 918446097001 | Valid OTP | AccountCompletionScreen | "User created", "NAVIGATING TO AccountCompletionScreen" |
| Returning User | 918810228783 | Valid OTP | HomeScreen | "Login successful", "Existing user - navigating to HomeScreen" |

### What to Share

If it's still not working, please share:
1. The complete console output from OTP verification
2. The exact response from `/sign-up/` API
3. Any error messages or stack traces
4. Which screen it's navigating to
