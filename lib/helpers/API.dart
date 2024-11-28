import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SmsService {
  final String _apiUrl = 'http://localhost:3000/send-sms';
  final String _apikey = dotenv.env['APIKEY'] ?? '';
  final String _senderName = dotenv.env['SENDERNAME'] ?? 'Semaphore';

  Future<void> sendSms({required String number, required String message}) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'apikey': _apikey,
          'number': number,
          'message': message,
          'sendername': _senderName,
        }),
      );

      if (response.statusCode == 200) {
        print("SMS sent successfully!");
        print(response.body);
      } else {
        print("Failed to send SMS: ${response.body}");
      }
    } catch (e) {
      print("Error sending SMS: $e");
    }
  }
}
