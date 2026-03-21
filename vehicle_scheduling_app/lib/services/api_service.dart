// ============================================
// FILE: lib/services/api_service.dart
//
// FIX (Bug 2): _handleResponse() is now resilient to non-Map responses.
//
// WHY THIS CAUSED THE BUG:
//   The PUT /api/job-assignments/:jobId/technicians endpoint (and others)
//   can return a response body where the top-level JSON is valid but
//   the cast `jsonDecode(body) as Map<String, dynamic>` throws a TypeError
//   if the server ever returns a JSON array or an unexpected shape.
//   When this happens, the assignment HAS already been saved to the DB,
//   but Flutter catches the TypeError and reports failure to the screen.
//   The user sees an error snackbar even though the driver was assigned.
//
// THE FIX:
//   If jsonDecode succeeds but the result isn't a Map, we wrap it in
//   { 'success': true, 'data': <decoded value> } instead of crashing.
//   This makes the service layer resilient to minor backend response
//   shape variations without hiding real errors.
// ============================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:vehicle_scheduling_app/config/app_config.dart';

class ApiService {
  // Singleton — all services share one instance so setAuthToken() only
  // needs to be called once at login.
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String baseUrl = AppConfig.baseUrl;
  final http.Client _client = http.Client();

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
  // PATCH
  // ==========================================
  Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? data,
  }) async {
    try {
      print('PATCH $baseUrl$endpoint');
      final response = await _client
          .patch(
            Uri.parse('$baseUrl$endpoint'),
            headers: _headers,
            body: data != null ? jsonEncode(data) : null,
          )
          .timeout(AppConfig.connectionTimeout);
      return _handleResponse(response);
    } catch (e) {
      print('PATCH error: $e');
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
  //
  // FIX (Bug 2): The original code did:
  //   return jsonDecode(response.body) as Map<String, dynamic>;
  //
  // If the backend returns a JSON array or any non-Map value,
  // that cast throws a TypeError at runtime. The assignment was
  // already saved to the DB at that point, so this was a false error.
  //
  // Now we check the decoded type first:
  //   - Map  → return it directly (normal path)
  //   - Other → wrap in { success: true, data: ... } (safe fallback)
  //   - Empty body → return { success: true }
  // ==========================================
  Map<String, dynamic> _handleResponse(http.Response response) {
    print('Response ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Empty body is fine — treat as success with no data
      if (response.body.isEmpty) {
        return {'success': true};
      }

      try {
        final decoded = jsonDecode(response.body);

        // Normal case: backend returned a JSON object
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }

        // Unusual case: backend returned a JSON array or primitive.
        // Wrap it so callers always get a Map without crashing.
        // The 'success: true' here is safe because we're in the 2xx branch.
        return {'success': true, 'data': decoded};
      } catch (e) {
        // jsonDecode itself failed — the body is not valid JSON.
        throw ApiException('Failed to parse server response', 500);
      }
    }

    // ── Error response (4xx / 5xx) ──────────────────────────────
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
        'Cannot reach server at ${AppConfig.baseUrl}. Check your connection.',
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
