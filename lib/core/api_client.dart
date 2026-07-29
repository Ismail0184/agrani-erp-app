import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/session_service.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final Map<String, dynamic> data;
  ApiException(this.message, this.statusCode, {this.data = const {}});
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Future<Map<String, dynamic>> get(
    String action, {
    Map<String, String>? query,
    String? authTokenOverride,
  }) async {
    final params = {'action': action, ...?query};
    final uri = Uri.parse(AppConfig.apiBaseUrl).replace(queryParameters: params);
    final res = await http
        .get(
          uri,
          headers: await _headers(
            json: false,
            authTokenOverride: authTokenOverride,
          ),
        )
        .timeout(AppConfig.apiTimeout);
    return _parse(res);
  }

  Future<Map<String, dynamic>> post(
    String action,
    Map<String, dynamic> body, {
    String? authTokenOverride,
  }) async {
    final uri = Uri.parse(AppConfig.apiBaseUrl).replace(queryParameters: {'action': action});
    final res = await http
        .post(
          uri,
          headers: await _headers(authTokenOverride: authTokenOverride),
          body: jsonEncode(body),
        )
        .timeout(AppConfig.apiTimeout);
    return _parse(res);
  }

  Future<Map<String, dynamic>> postMultipart(
    String action, {
    required Map<String, String> fields,
    String? fileField,
    String? filePath,
    String? authTokenOverride,
  }) async {
    final uri = Uri.parse(AppConfig.apiBaseUrl).replace(queryParameters: {'action': action});
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(
      await _headers(
        json: false,
        authTokenOverride: authTokenOverride,
      ),
    );
    request.fields.addAll(fields);

    if (fileField != null && filePath != null && filePath.trim().isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    }

    final streamed = await request.send().timeout(AppConfig.apiTimeout);
    final res = await http.Response.fromStream(streamed);
    return _parse(res);
  }

  Future<Map<String, String>> _headers({
    bool json = true,
    String? authTokenOverride,
  }) async {
    final token = authTokenOverride ?? await SessionService.instance.token();
    return {
      if (json) 'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      'User-Agent': 'AgraniERP-MobileApp/1.1 Android Flutter',
      'X-Requested-With': 'XMLHttpRequest',
      'Cache-Control': 'no-cache',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _parse(http.Response res) async {
    final body = res.body.trim().isEmpty ? '{}' : res.body;
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      final lower = body.toLowerCase();
      if (lower.contains('imunify360') || lower.contains('bot-protection') || lower.contains('access denied')) {
        throw ApiException(
          'Access denied by server bot-protection. Please whitelist the mobile API path or your current IP in hosting Imunify360.',
          res.statusCode,
        );
      }
      if ((res.statusCode == 401 || res.statusCode == 419) &&
          await SessionService.instance.isLoggedIn()) {
        await SessionService.instance.expireSession();
      }
      throw ApiException('Invalid server response: ${res.body}', res.statusCode);
    }

    final responseData = decoded['data'] is Map<String, dynamic>
        ? decoded['data'] as Map<String, dynamic>
        : <String, dynamic>{'data': decoded['data']};

    if (decoded['success'] != true) {
      final message = decoded['message']?.toString() ?? 'API failed';
      if (await _isExpiredAuthenticatedSession(res.statusCode, message, responseData)) {
        await SessionService.instance.expireSession();
      }
      throw ApiException(message, res.statusCode, data: responseData);
    }
    return responseData;
  }

  Future<bool> _isExpiredAuthenticatedSession(
    int statusCode,
    String message,
    Map<String, dynamic> data,
  ) async {
    if (!await SessionService.instance.isLoggedIn()) return false;

    if (statusCode == 401 || statusCode == 419) return true;

    final reason = '${data['reason'] ?? data['code'] ?? ''}'.toLowerCase();
    final text = '$message $reason'.toLowerCase();
    final explicitlyExpired = text.contains('session expired') ||
        text.contains('token expired') ||
        text.contains('invalid token') ||
        text.contains('unauthenticated') ||
        text.contains('authentication required');

    if (explicitlyExpired) return true;
    return false;
  }
}
