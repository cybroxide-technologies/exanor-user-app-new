import 'package:exanor/screens/profile_image_upload_screen.dart';
import 'package:flutter/material.dart';
import 'package:exanor/services/api_service.dart';
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
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Ambient Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(color: theme.colorScheme.surface),
            ),
          ),
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withOpacity(0.05),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.secondary.withOpacity(0.1),
                    blurRadius: 80,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
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
                        SizedBox(height: screenHeight * 0.02),

                        // Header
                        _buildHeader(theme, isDark),

                        const SizedBox(height: 40),

                        // Form Fields
                        _buildSectionLabel(theme, 'Personal Info'),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _firstNameController,
                                label: 'First Name',
                                hint: 'John',
                                icon: Icons.person_outline_rounded,
                                theme: theme,
                                isDark: isDark,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _lastNameController,
                                label: 'Last Name',
                                hint: 'Doe',
                                icon: Icons.person, // Or leave empty if desired
                                theme: theme,
                                isDark: isDark,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        _buildDateOfBirthPicker(theme, isDark),

                        const SizedBox(height: 24),

                        _buildSectionLabel(theme, 'Gender Identity'),
                        const SizedBox(height: 16),
                        _buildGenderSelector(theme, isDark),

                        const SizedBox(height: 32),

                        _buildSectionLabel(theme, 'Contact'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          hint: 'john.doe@example.com (Optional)',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          theme: theme,
                          isDark: isDark,
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              final emailRegex = RegExp(
                                r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
                              );
                              if (!emailRegex.hasMatch(value)) {
                                return 'Invalid email address';
                              }
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 50),

                        // Action Button
                        _buildContinueButton(theme),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        TranslatedText(
          'Finish Setting Up',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
            fontSize: 32,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 12),
        TranslatedText(
          "Let's personalize your profile to get the best experience.",
          style: theme.textTheme.bodyLarge?.copyWith(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            height: 1.5,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(ThemeData theme, String label) {
    return TranslatedText(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.primary,
        letterSpacing: 0.5,
        fontSize: 13,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ThemeData theme,
    required bool isDark,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[600],
              fontSize: 14,
            ),
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[700] : Colors.grey[400],
              fontSize: 14,
            ),
            prefixIcon: Icon(
              icon,
              color: isDark ? Colors.grey[600] : Colors.grey[500],
              size: 20,
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF1C1C1E)
                : const Color(0xFFF9FAFB),

            errorStyle: const TextStyle(
              height: 0,
              fontSize: 0,
            ), // Hidden, handled by border color usually or custom UI. keeping standard for now but cleaner. Actually lets keep text.
            // Reverting error style to default for UX safety, but styled.
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.error.withOpacity(0.5),
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildGenderOption(
            'Male',
            'male',
            Icons.male_rounded,
            theme,
            isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGenderOption(
            'Female',
            'female',
            Icons.female_rounded,
            theme,
            isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGenderOption(
            'Other',
            'other',
            Icons.transgender_rounded,
            theme,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildGenderOption(
    String label,
    String value,
    IconData icon,
    ThemeData theme,
    bool isDark,
  ) {
    final isSelected = _selectedGender == value;
    final activeColor = theme.colorScheme.primary;
    final inactiveBg = isDark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFF9FAFB);
    final activeBg = activeColor.withOpacity(0.1);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? activeColor
                  : (isDark ? Colors.grey[500] : Colors.grey[500]),
              size: 26,
            ),
            const SizedBox(height: 8),
            TranslatedText(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateOfBirthPicker(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(theme, 'Date of Birth'),
        const SizedBox(height: 16),
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
              color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TranslatedText(
                    _selectedDateOfBirth != null
                        ? '${_selectedDateOfBirth!.day.toString().padLeft(2, '0')}/${_selectedDateOfBirth!.month.toString().padLeft(2, '0')}/${_selectedDateOfBirth!.year}'
                        : 'Select Date',
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedDateOfBirth != null
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.grey[600] : Colors.grey[400]),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _completeProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                  const TranslatedText(
                    'Complete Profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 24,
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

          // Navigate to ProfileImageUploadScreen with Slide Transition
          Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const ProfileImageUploadScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOut;
                    var tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
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
