// ============================================
// FILE: lib/services/api_service.dart
// PURPOSE: Base HTTP client - all services use this
// FIX:     Added setAuthToken() — JWT is now sent with every request
// ============================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:vehicle_scheduling_app/config/app_config.dart';

class ApiService {
  // ── Singleton ──────────────────────────────────────────────
  // Every service shares the same instance, so setAuthToken()
  // only needs to be called once (at login / app start) and all
  // subsequent requests across ALL services automatically carry
  // the token. No per-screen injection needed.
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String baseUrl = AppConfig.baseUrl;
  final http.Client _client = http.Client();

  // ==========================================
  // AUTH TOKEN — set once after login
  // Every request will then include:
  //   Authorization: Bearer <token>
  // ==========================================
  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> get _headers {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_authToken';
    }
    return h;
  }

  // ==========================================
  // GET
  // ==========================================
  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      print('GET $baseUrl$endpoint');
      final response = await _client
          .get(Uri.parse('$baseUrl$endpoint'), headers: _headers)
          .timeout(AppConfig.connectionTimeout);
      return _handleResponse(response);
    } catch (e) {
      print('GET error: $e');
      throw _handleError(e);
    }
  }

  // ==========================================
  // POST
  // ==========================================
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? data,
  }) async {
    try {
      print('POST $baseUrl$endpoint');
      final response = await _client
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: _headers,
            body: data != null ? jsonEncode(data) : null,
          )
          .timeout(AppConfig.connectionTimeout);
      return _handleResponse(response);
    } catch (e) {
      print('POST error: $e');
      throw _handleError(e);
    }
  }

  // ==========================================
  // PUT
  // ==========================================
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? data,
  }) async {
    try {
      print('PUT $baseUrl$endpoint');
      final response = await _client
          .put(
            Uri.parse('$baseUrl$endpoint'),
            headers: _headers,
            body: data != null ? jsonEncode(data) : null,
          )
          .timeout(AppConfig.connectionTimeout);
      return _handleResponse(response);
    } catch (e) {
      print('PUT error: $e');
      throw _handleError(e);
    }
  }

  // ==========================================
  // DELETE
  // ==========================================
  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      print('DELETE $baseUrl$endpoint');
      final response = await _client
          .delete(Uri.parse('$baseUrl$endpoint'), headers: _headers)
          .timeout(AppConfig.connectionTimeout);
      return _handleResponse(response);
    } catch (e) {
      print('DELETE error: $e');
      throw _handleError(e);
    }
  }

  // ==========================================
  // HANDLE RESPONSE
  // ==========================================
  Map<String, dynamic> _handleResponse(http.Response response) {
    print('Response ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw ApiException('Failed to parse server response', 500);
      }
    }

    String errorMessage = 'Request failed (${response.statusCode})';
    try {
      final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
      errorMessage = errorJson['message'] ?? errorJson['error'] ?? errorMessage;
    } catch (_) {
      if (response.body.isNotEmpty) errorMessage = response.body;
    }

    throw ApiException(errorMessage, response.statusCode);
  }

  // ==========================================
  // HANDLE ERROR
  // ==========================================
  Exception _handleError(dynamic error) {
    if (error is ApiException) return error;

    if (error.toString().contains('SocketException') ||
        error.toString().contains('Failed host lookup')) {
      return ApiException(
        'Cannot reach server. Make sure your backend is running on port 3000.',
        0,
      );
    }

    if (error.toString().contains('TimeoutException')) {
      return ApiException('Request timed out. Please try again.', 0);
    }

    return ApiException('Unexpected error: ${error.toString()}', 0);
  }

  void dispose() {
    _client.close();
  }
}

// ============================================
// API EXCEPTION
// ============================================
class ApiException implements Exception {
  final String message;
  final int statusCode;

  const ApiException(this.message, this.statusCode);

  @override
  String toString() => message;

  bool get isValidationError => statusCode == 400;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isServerError => statusCode >= 500;
  bool get isNetworkError => statusCode == 0;
}
