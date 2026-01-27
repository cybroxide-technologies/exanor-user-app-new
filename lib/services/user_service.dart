import 'dart:io';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  // Cache all users to implement pagination
  static List<User>? _cachedUsers;
  static const int _itemsPerPage = 6; // Show 6 users per page

  /// Fetch users from the API with pagination
  /// [page] - Page number to fetch (default: 1)
  static Future<UsersResponse> getUsers({int page = 1}) async {
    try {
      // If we don't have cached users, fetch them all
      if (_cachedUsers == null) {
        final response = await ApiService.get('/users');

        if (response['data'] != null && response['data'] is List) {
          _cachedUsers = (response['data'] as List<dynamic>)
              .map(
                (userJson) => User.fromJson(userJson as Map<String, dynamic>),
              )
              .toList();
        } else {
          throw ApiException('Invalid response format');
        }
      }

      // Return paginated response
      return UsersResponse.paginated(_cachedUsers!, page, _itemsPerPage);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      } else {
        throw ApiException('Failed to fetch users: ${e.toString()}');
      }
    }
  }

  /// Get a single user by ID
  static Future<User> getUser(int id) async {
    try {
      final response = await ApiService.get('/users/$id');

      if (response['data'] != null) {
        return User.fromJson(response['data'] as Map<String, dynamic>);
      } else {
        throw ApiException('User not found');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      } else {
        throw ApiException('Failed to fetch user: ${e.toString()}');
      }
    }
  }

  /// Create a new user
  static Future<User> createUser({
    required String name,
    required String username,
    required String email,
    String phone = '',
    String website = '',
  }) async {
    try {
      final response = await ApiService.post(
        '/users',
        body: {
          'name': name,
          'username': username,
          'email': email,
          'phone': phone,
          'website': website,
        },
      );

      if (response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        return User(
          id: int.tryParse(data['id']?.toString() ?? '0') ?? 0,
          name: name,
          username: username,
          email: email,
          phone: phone,
          website: website,
        );
      } else {
        throw ApiException('Failed to create user');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      } else {
        throw ApiException('Failed to create user: ${e.toString()}');
      }
    }
  }

  /// Update a user
  static Future<User> updateUser({
    required int id,
    required String name,
    required String username,
    required String email,
    String phone = '',
    String website = '',
  }) async {
    try {
      final response = await ApiService.put(
        '/users/$id',
        body: {
          'name': name,
          'username': username,
          'email': email,
          'phone': phone,
          'website': website,
        },
      );

      if (response['data'] != null) {
        return User(
          id: id,
          name: name,
          username: username,
          email: email,
          phone: phone,
          website: website,
        );
      } else {
        throw ApiException('Failed to update user');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      } else {
        throw ApiException('Failed to update user: ${e.toString()}');
      }
    }
  }

  /// Delete a user
  static Future<bool> deleteUser(int id) async {
    try {
      final response = await ApiService.delete('/users/$id');
      return response['statusCode'] == 200 || response['statusCode'] == 204;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      } else {
        throw ApiException('Failed to delete user: ${e.toString()}');
      }
    }
  }

  /// Clear cached users (useful for refresh)
  static void clearCache() {
    _cachedUsers = null;
  }

  /// Update current user profile
  ///
  /// Sends a PUT request to update-user-data/ with the provided fields.
  /// Returns the full response map which includes status, response message, tokens, and user_data.
  static Future<Map<String, dynamic>> updateUserProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String gender,
  }) async {
    try {
      final response = await ApiService.put(
        '/update-user-data/',
        body: {
          'data': {
            'first_name': firstName,
            'last_name': lastName,
            'email': email,
            'gender': gender,
            // "date_of_birth_time_since_epoch": "" // Optional as per requirement
          },
        },
        useBearerToken: true,
      );

      if (response['data'] != null &&
          response['data'] is Map<String, dynamic>) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw ApiException(
          'Invalid response format from server: ${response['statusCode']}',
        );
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      } else {
        throw ApiException('Failed to update profile: ${e.toString()}');
      }
    }
  }

  /// Upload profile image
  ///
  /// Uploads a profile image file to the server using PUT /update-user-img-url/
  /// Returns the updated user data or success response
  static Future<Map<String, dynamic>> uploadProfileImage({
    required String imagePath,
    String? caption,
  }) async {
    try {
      print('🖼️ DEBUG: Starting image upload...');
      print('📁 DEBUG: Image path: $imagePath');

      final response = await ApiService.uploadFile(
        '/update-user-img-url/',
        file: File(imagePath),
        fieldName: 'file',
        additionalFields: caption != null ? {'caption': caption} : null,
        useBearerToken: true,
      );

      print('📦 DEBUG: Raw API Response:');
      print('   StatusCode: ${response['statusCode']}');
      print('   Full Response: $response');
      print('   Data type: ${response['data']?.runtimeType}');
      print('   Data content: ${response['data']}');

      // Check for success status in body or status code
      if (response['statusCode'] == 200) {
        // Update local storage with new image URL if present in response
        if (response['data'] != null &&
            response['data'] is Map<String, dynamic>) {
          final responseData = response['data'] as Map<String, dynamic>;

          print('🔍 DEBUG: Response data keys: ${responseData.keys.toList()}');

          // Check multiple possible locations for the image URL
          String? imgUrl;

          // Direct img_url
          if (responseData['img_url'] != null) {
            imgUrl = responseData['img_url'].toString();
            print('✅ DEBUG: Found img_url at root: $imgUrl');
          }
          // Nested in 'data'
          else if (responseData['data'] != null) {
            final nestedData = responseData['data'];
            print('🔍 DEBUG: Nested data type: ${nestedData.runtimeType}');
            print('🔍 DEBUG: Nested data: $nestedData');

            if (nestedData is Map<String, dynamic> &&
                nestedData['img_url'] != null) {
              imgUrl = nestedData['img_url'].toString();
              print('✅ DEBUG: Found img_url in nested data: $imgUrl');
            }
          }
          // Check for 'image_url' alternative
          else if (responseData['image_url'] != null) {
            imgUrl = responseData['image_url'].toString();
            print('✅ DEBUG: Found image_url: $imgUrl');
          }
          // Check response field
          else if (responseData['response'] != null) {
            final responseField = responseData['response'];
            print(
              '🔍 DEBUG: Response field type: ${responseField.runtimeType}',
            );
            print('🔍 DEBUG: Response field: $responseField');

            if (responseField is Map<String, dynamic> &&
                responseField['img_url'] != null) {
              imgUrl = responseField['img_url'].toString();
              print('✅ DEBUG: Found img_url in response field: $imgUrl');
            }
          }

          if (imgUrl != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_image', imgUrl);
            print('💾 DEBUG: Saved image URL to SharedPreferences: $imgUrl');

            // Return with the found URL
            return {...responseData, 'img_url': imgUrl, 'status': 200};
          } else {
            print('⚠️ DEBUG: No image URL found in response!');
          }

          return responseData;
        }

        print('⚠️ DEBUG: Response data is null or not a Map');
        return {'status': 200, 'message': 'Image updated successfully'};
      } else {
        throw ApiException(
          'Failed to upload image. Status: ${response['statusCode']}',
        );
      }
    } catch (e) {
      print('❌ DEBUG: Upload error: $e');
      if (e is ApiException) {
        rethrow;
      } else {
        throw ApiException('Failed to upload profile image: ${e.toString()}');
      }
    }
  }

  /// Fetch user profile from API and update local storage using POST /view-user-data/
  static Future<void> viewUserData() async {
    try {
      final response = await ApiService.post(
        '/view-user-data/',
        body: {}, // Empty body as per sample request
        useBearerToken: true,
      );

      if (response['data'] != null &&
          response['data']['response'] is List &&
          (response['data']['response'] as List).isNotEmpty) {
        final userData =
            (response['data']['response'] as List).first
                as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('first_name', userData['first_name'] ?? '');
        await prefs.setString('last_name', userData['last_name'] ?? '');
        await prefs.setString('user_email', userData['email'] ?? '');
        await prefs.setString('user_id', userData['id']?.toString() ?? '');

        if (userData['img_url'] != null) {
          await prefs.setString('user_image', userData['img_url']);
        }

        if (userData['phone_number'] != null) {
          await prefs.setString(
            'user_phone',
            userData['phone_number'].toString(),
          );
        }

        if (userData['gender'] != null) {
          await prefs.setString('user_gender', userData['gender'].toString());
        }

        if (userData['date_of_birth'] != null) {
          await prefs.setString(
            'date_of_birth',
            userData['date_of_birth'].toString(),
          );
        }
      } else {
        throw ApiException('Invalid response format or empty user data');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      } else {
        throw ApiException('Failed to fetch user data: ${e.toString()}');
      }
    }
  }
}
