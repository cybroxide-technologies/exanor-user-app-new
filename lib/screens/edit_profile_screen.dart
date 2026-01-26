import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/user_service.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedGender = 'male'; // Default gender
  String? _userImage;
  File? _selectedImageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData({bool forceRefresh = false}) async {
    try {
      // Always fetch from API to get latest data including profile image
      await UserService.viewUserData();

      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _firstNameController.text = prefs.getString('first_name') ?? '';
          _lastNameController.text = prefs.getString('last_name') ?? '';
          _emailController.text = prefs.getString('user_email') ?? '';

          _phoneController.text = prefs.getString('user_phone') ?? '';
          _userImage = prefs.getString('user_image');

          final savedGender = prefs.getString('user_gender');
          if (savedGender != null &&
              (savedGender == 'male' ||
                  savedGender == 'female' ||
                  savedGender == 'other')) {
            _selectedGender = savedGender;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText(
              'Failed to load user data: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = File(pickedFile.path);
        });

        // Upload deferred to save button
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Failed to pick image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // 1. Upload Profile Image if selected
        Map<String, dynamic>? uploadResponse;
        if (_selectedImageFile != null) {
          try {
            print('📸 EDIT PROFILE: Starting image upload...');
            uploadResponse = await UserService.uploadProfileImage(
              imagePath: _selectedImageFile!.path,
            );
            print('📸 EDIT PROFILE: Upload response: $uploadResponse');
          } catch (e) {
            print('❌ EDIT PROFILE: Upload error: $e');
            throw ApiException('Failed to upload image: ${e.toString()}');
          }
        }

        // 2. Update Profile Details
        final response = await UserService.updateUserProfile(
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          email: _emailController.text,
          gender: _selectedGender,
        );

        if (response['status'] == 200) {
          // Update local data
          final prefs = await SharedPreferences.getInstance();
          final userData = response['user_data'];
          final tokens = response['tokens'];

          if (userData != null) {
            await prefs.setString('first_name', userData['first_name'] ?? '');
            await prefs.setString('last_name', userData['last_name'] ?? '');
            await prefs.setString('user_email', userData['email'] ?? '');
            if (userData['phone_number'] != null) {
              await prefs.setString(
                'user_phone',
                userData['phone_number'].toString(),
              );
            }
            await prefs.setString('user_gender', _selectedGender);
          }

          if (tokens != null) {
            await prefs.setString('access_token', tokens['access_token'] ?? '');
            await prefs.setString(
              'refresh_token',
              tokens['refresh_token'] ?? '',
            );
            await prefs.setString('csrf_token', tokens['csrf_token'] ?? '');
          }

          // Handle Image Update
          if (uploadResponse != null) {
            String? newImgUrl = uploadResponse['img_url'];
            if (newImgUrl == null && uploadResponse['data'] != null) {
              newImgUrl = uploadResponse['data']['img_url'];
            }

            if (newImgUrl != null) {
              await prefs.setString('user_image', newImgUrl);
            }
          }

          // Force a reload of user data to ensure everything is synced including image url if changed
          print('🔄 EDIT PROFILE: Calling viewUserData...');
          await UserService.viewUserData();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: TranslatedText('Profile updated successfully'),
                backgroundColor: Colors.green,
              ),
            );

            setState(() {
              _selectedImageFile = null;

              if (uploadResponse != null) {
                String? newImgUrl = uploadResponse['img_url'];
                if (newImgUrl == null && uploadResponse['data'] != null) {
                  newImgUrl = uploadResponse['data']['img_url'];
                }
                if (newImgUrl != null) {
                  _userImage = newImgUrl;
                }
              }
            });

            if (_userImage != null && _userImage!.isNotEmpty) {
              try {
                await NetworkImage(_userImage!).evict();
              } catch (e) {
                print('Error evicting image cache: $e');
              }
            }

            print('🔄 EDIT PROFILE: Reloading user data...');
            await _loadUserData(forceRefresh: true);
            print(
              '✅ EDIT PROFILE: Data reloaded. Current _userImage: $_userImage',
            );
          }
        } else {
          throw ApiException(response['response'] ?? 'Update failed');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: TranslatedText(
                'Failed to update profile: ${e.toString()}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const TranslatedText('Edit Profile'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadUserData(forceRefresh: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Picture Section
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.1,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 3,
                                ),
                                image: _selectedImageFile != null
                                    ? DecorationImage(
                                        image: FileImage(_selectedImageFile!),
                                        fit: BoxFit.cover,
                                      )
                                    : (_userImage != null &&
                                              _userImage!.isNotEmpty
                                          ? DecorationImage(
                                              image: NetworkImage(_userImage!),
                                              fit: BoxFit.cover,
                                            )
                                          : null),
                              ),
                              child:
                                  (_selectedImageFile == null &&
                                      (_userImage == null ||
                                          _userImage!.isEmpty))
                                  ? Icon(
                                      Icons.person_rounded,
                                      size: 60,
                                      color: theme.colorScheme.primary,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.colorScheme.surface,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.edit_rounded),
                          label: const TranslatedText('Change Photo'),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // First Name Field
                      TranslatedText(
                        'First Name',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          hintText: 'Enter your first name',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withOpacity(0.3),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your first name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Last Name Field
                      TranslatedText(
                        'Last Name',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          hintText: 'Enter your last name',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withOpacity(0.3),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your last name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Email Field
                      TranslatedText(
                        'Email',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Enter your email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withOpacity(0.3),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Phone Field
                      TranslatedText(
                        'Phone Number',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        readOnly: true, // Phone not editable
                        decoration: InputDecoration(
                          hintText: 'Enter your phone number',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          suffixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            size: 20,
                            color: Colors.grey,
                          ),
                          hintStyle: const TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withOpacity(0.1),
                        ),
                        validator: (value) {
                          // Removed validation since it's read only
                          return null;
                        },
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: TranslatedText(
                                'Phone number cannot be changed here.',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Gender Field
                      TranslatedText(
                        'Gender',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedGender,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down_rounded),
                            items: ['male', 'female', 'other'].map((
                              String value,
                            ) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value[0].toUpperCase() + value.substring(1),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                if (newValue != null)
                                  _selectedGender = newValue;
                              });
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const TranslatedText(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
