import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'constants.dart';

class JwtHelper {
  final _authService = AuthService();
  final _client = http.Client();

  Future<int?> getCurrentUserId() async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _client.get(
        Uri.parse('${AppConstants.baseUrl}/me'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final user = jsonDecode(response.body);
        return user['id'] as int;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}

