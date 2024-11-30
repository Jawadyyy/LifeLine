import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _apiBaseUrl = 'https://9k1m63.api.infobip.com';
  static const String _apiKey = 'ff217b30ac1fd7a739d51caa41c7b2e0-d35ab923-3ec8-4e3c-b21b-ca8efb7e0b84'; // Secure this key in production

  // Validate phone number format
  static bool _isValidPhoneNumber(String phoneNumber) {
    final RegExp phoneRegExp = RegExp(r'^\+?[1-9]\d{1,14}$'); // E.164 format
    return phoneRegExp.hasMatch(phoneNumber);
  }

  // Method to send OTP
  static Future<bool> sendOTP(String phoneNumber, int otp) async {
    if (!_isValidPhoneNumber(phoneNumber)) {
      print('Error: Invalid phone number format');
      return false;
    }

    final String formattedPhoneNumber = phoneNumber.startsWith('+') ? phoneNumber : '+$phoneNumber';

    final String url = '$_apiBaseUrl/sms/2/text/advanced';

    final Map<String, dynamic> requestBody = {
      "messages": [
        {
          "from": "LifeLine",
          "destinations": [
            {
              "to": formattedPhoneNumber
            }
          ],
          "text": "Your OTP Code is: $otp",
        }
      ]
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'App $_apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('OTP sent successfully');
        return true;
      } else {
        print('Error: ${json.decode(response.body)['requestError']['serviceException']['text']}');
        return false;
      }
    } catch (e) {
      print('Error: $e');
      return false;
    }
  }
}
