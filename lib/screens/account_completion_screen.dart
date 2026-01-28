import 'package:exanor/screens/location_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/screens/HomeScreen.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountCompletionScreen extends StatefulWidget {
  final String accessToken;
  final String csrfToken;
  final Map<String, dynamic> userData;

  const AccountCompletionScreen({
    super.key,
    required this.accessToken,
    required this.csrfToken,
    required this.userData,
  });

  @override
  State<AccountCompletionScreen> createState() =>
      _AccountCompletionScreenState();
}

class _AccountCompletionScreenState extends State<AccountCompletionScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  String _selectedGender = 'male';
  DateTime? _selectedDateOfBirth;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Pre-populate fields with existing user data if available
    _prefillFormFields();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Start animation
    _animationController.forward();
  }

  /// Pre-fill form fields with existing user data
  void _prefillFormFields() {
    final userData = widget.userData;

    // Pre-fill first name (only if not 'unnamed')
    final firstName = userData['first_name'];
    if (firstName != null &&
        firstName != 'unnamed' &&
        firstName.toString().isNotEmpty) {
      _firstNameController.text = firstName.toString();
    }

    // Pre-fill last name (only if not 'user')
    final lastName = userData['last_name'];
    if (lastName != null &&
        lastName != 'user' &&
        lastName.toString().isNotEmpty) {
      _lastNameController.text = lastName.toString();
    }

    // Pre-fill email if available
    final email = userData['email'];
    if (email != null && email.toString().isNotEmpty) {
      _emailController.text = email.toString();
    }

    // Pre-fill gender if available and valid
    final gender = userData['gender'];
    if (gender != null && gender != 'undefined') {
      final genderStr = gender.toString().toLowerCase();
      if (genderStr == 'male' ||
          genderStr == 'female' ||
          genderStr == 'other') {
        _selectedGender = genderStr;
      }
    }

    // Pre-fill date of birth if available
    final dob = userData['date_of_birth'];
    if (dob != null && dob.toString().isNotEmpty) {
      try {
        _selectedDateOfBirth = DateTime.parse(dob.toString());
      } catch (e) {
        // If parsing fails, leave it null
        print('⚠️ Failed to parse date of birth: $dob');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: screenHeight * 0.08),

                      // Welcome Header
                      _buildHeader(theme),

                      const SizedBox(height: 40),

                      // First Name Field
                      _buildTextField(
                        controller: _firstNameController,
                        label: 'First Name',
                        hint: 'Enter your first name',
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your first name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Last Name Field
                      _buildTextField(
                        controller: _lastNameController,
                        label: 'Last Name',
                        hint: 'Enter your last name',
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your last name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Gender Selection
                      _buildGenderSelector(theme),

                      const SizedBox(height: 20),

                      // Date of Birth Picker
                      _buildDateOfBirthPicker(theme),

                      const SizedBox(height: 20),

                      // Email Field (Optional)
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email (Optional)',
                        hint: 'Enter your email address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          // Email is optional, but if provided, should be valid
                          if (value != null && value.trim().isNotEmpty) {
                            final emailRegex = RegExp(
                              r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
                            );
                            if (!emailRegex.hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 40),

                      // Continue Button
                      _buildContinueButton(theme),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Decorative element
        Container(
          width: 60,
          height: 6,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 24),

        TranslatedText(
          'Complete Your Profile',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),

        TranslatedText(
          'Please provide a few details to personalize your experience',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TranslatedText(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),

        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.95 + (0.05 * value),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              prefixIcon: Icon(
                icon,
                color: theme.colorScheme.primary.withOpacity(0.7),
                size: 22,
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: theme.colorScheme.error,
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: theme.colorScheme.error,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TranslatedText(
          'Gender',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildGenderOption('Male', 'male', Icons.male, theme),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderOption(
                'Female',
                'female',
                Icons.female,
                theme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderOption(
                'Other',
                'other',
                Icons.transgender,
                theme,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(
    String label,
    String value,
    IconData icon,
    ThemeData theme,
  ) {
    final isSelected = _selectedGender == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.1)
              : theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.5),
              size: 28,
            ),
            const SizedBox(height: 8),
            TranslatedText(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateOfBirthPicker(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TranslatedText(
          'Date of Birth',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),

        GestureDetector(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _selectedDateOfBirth ?? DateTime(2000, 1, 1),
              firstDate: DateTime(1924),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: theme.copyWith(
                    colorScheme: theme.colorScheme.copyWith(
                      primary: theme.colorScheme.primary,
                      onPrimary: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );

            if (picked != null) {
              setState(() {
                _selectedDateOfBirth = picked;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: theme.colorScheme.primary.withOpacity(0.7),
                  size: 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TranslatedText(
                    _selectedDateOfBirth != null
                        ? '${_selectedDateOfBirth!.day.toString().padLeft(2, '0')}/${_selectedDateOfBirth!.month.toString().padLeft(2, '0')}/${_selectedDateOfBirth!.year}'
                        : 'Select your date of birth',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: _selectedDateOfBirth != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _completeProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: theme.colorScheme.primary.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          disabledBackgroundColor: theme.colorScheme.outline.withOpacity(0.3),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TranslatedText(
                    'Continue',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate date of birth
    if (_selectedDateOfBirth == null) {
      _showErrorSnackBar('Please select your date of birth');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Format date of birth as YYYY-MM-DD
      final formattedDob =
          '${_selectedDateOfBirth!.year}-${_selectedDateOfBirth!.month.toString().padLeft(2, '0')}-${_selectedDateOfBirth!.day.toString().padLeft(2, '0')}';

      // Prepare the user data fields
      final userDataFields = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'gender': _selectedGender,
        'date_of_birth': formattedDob,
      };

      // Add email only if provided
      if (_emailController.text.trim().isNotEmpty) {
        userDataFields['email'] = _emailController.text.trim();
      }

      // Wrap in "data" object to match GET response format
      final updateData = {'data': userDataFields};

      print('📝 Updating user profile: $updateData');

      // Call API to update user profile
      // You'll need to add this endpoint or modify the existing one
      final response = await ApiService.put(
        '/update-user-data/',
        body: updateData,
        useBearerToken: true,
      );

      print('📨 Update Profile Response: $response');

      if (mounted) {
        if (response['data'] != null && response['data']['status'] == 200) {
          print('✅ Profile updated successfully');

          // Update local storage with new data
          await _updateLocalUserData();

          // Navigate to HomeScreen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const LocationSelectionScreen(),
            ),
            (route) => false,
          );
        } else {
          setState(() {
            _isLoading = false;
          });
          _showErrorSnackBar('Failed to update profile. Please try again.');
        }
      }
    } catch (e) {
      print('❌ Error updating profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Network error. Please try again.');
      }
    }
  }

  Future<void> _updateLocalUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('first_name', _firstNameController.text.trim());
      await prefs.setString('last_name', _lastNameController.text.trim());
      await prefs.setString('gender', _selectedGender);

      if (_selectedDateOfBirth != null) {
        final formattedDob =
            '${_selectedDateOfBirth!.year}-${_selectedDateOfBirth!.month.toString().padLeft(2, '0')}-${_selectedDateOfBirth!.day.toString().padLeft(2, '0')}';
        await prefs.setString('date_of_birth', formattedDob);
      }

      if (_emailController.text.trim().isNotEmpty) {
        await prefs.setString('email', _emailController.text.trim());
      }

      print('✅ Local user data updated successfully');
    } catch (e) {
      print('❌ Error updating local user data: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TranslatedText(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
