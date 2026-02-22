import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = "http://10.0.2.2:8000";

  static Future<http.Response> register(String name, String email, String password) async {
    return await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "full_name": name,
        "email": email,
        "password": password,
      }),
    );
  }

  static Future<http.Response> login(String email, String password) async {
    return await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );
  }
}