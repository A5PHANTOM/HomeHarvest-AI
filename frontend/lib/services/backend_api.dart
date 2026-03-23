import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class BackendApi {
  static Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      ApiConfig.uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final decoded = response.body.isNotEmpty
        ? jsonDecode(response.body) as Object
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    }

    String message = 'Request failed (${response.statusCode})';
    if (decoded is Map && decoded['detail'] != null) {
      message = decoded['detail'].toString();
    }
    throw Exception(message);
  }

  static Future<List<dynamic>> getList(String path) async {
    final response = await http.get(ApiConfig.uri(path));

    final decoded = response.body.isNotEmpty
        ? jsonDecode(response.body) as Object
        : <dynamic>[];

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is List<dynamic>) return decoded;
      return <dynamic>[];
    }

    String message = 'Request failed (${response.statusCode})';
    if (decoded is Map && decoded['detail'] != null) {
      message = decoded['detail'].toString();
    }
    throw Exception(message);
  }
}
