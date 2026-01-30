import 'package:exanor/services/api_service.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactService {
  /// Request permission and fetch all contacts
  static Future<List<Contact>> getAllContacts() async {
    final status = await Permission.contacts.request();
    if (status.isGranted) {
      return await FastContacts.getAllContacts();
    } else {
      throw Exception('Contact permission denied');
    }
  }

  /// Format contacts and sync to backend
  static Future<void> syncContacts(List<Contact> contacts) async {
    try {
      // Format contacts for the API
      // We'll send name, phones, and emails
      final formattedContacts = contacts.map((contact) {
        return {
          'displayName': contact.displayName,
          'phones': contact.phones.map((p) => p.number).toList(),
          'emails': contact.emails.map((e) => e.address).toList(),
        };
      }).toList();

      // Send to backend
      // Using a batch size if necessary, but for now sending all at once
      await ApiService.post(
        '/create-user-contacts-bulk/',
        body: {
          'contacts': formattedContacts,
          'count': formattedContacts.length,
        },
        useBearerToken: true,
      );
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Failed to sync contacts: $e');
    }
  }
}
