import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

/// Result of an API call: either data or an error message.
class ApiResult {
  final bool ok;
  final int statusCode;
  final Map<String, dynamic> data;
  final String message;

  ApiResult({
    required this.ok,
    required this.statusCode,
    this.data = const {},
    this.message = '',
  });
}

/// Talks to the NaturalBeauty backend.
///
/// Mirrors exactly the endpoints that exist on the server:
///   POST   /auth/signup
///   POST   /auth/login
///   POST   /posts/create      (multipart)
///   POST   /likes/:id/like
///   DELETE /likes/:id/unlike
class ApiService {
  static const _tokenKey = 'auth_token';

  // ---------------------------------------------------------------- token

  /// The JWT is stored on the device after login and sent with every
  /// protected request as `Authorization: Bearer <token>`.
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ----------------------------------------------------------- helpers

  static Map<String, dynamic> _decode(http.Response res) {
    if (res.body.isEmpty) return {};
    try {
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    } catch (_) {
      // Server returned HTML (e.g. an unhandled error page), not JSON.
      return {'message': 'Unexpected server response'};
    }
  }

  static ApiResult _result(http.Response res) {
    final body = _decode(res);
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    return ApiResult(
      ok: ok,
      statusCode: res.statusCode,
      data: body,
      message: (body['message'] ?? (ok ? 'Success' : 'Request failed')).toString(),
    );
  }

  static ApiResult _networkError(Object e) {
    return ApiResult(
      ok: false,
      statusCode: 0,
      message: 'Cannot reach server at ${Config.baseUrl}\n\n$e',
    );
  }

  // -------------------------------------------------------------- auth

  /// POST /auth/signup — JSON body.
  static Future<ApiResult> signup({
    required String username,
    required String name,
    required String email,
    required String password,
    required String phone,
    required String gender,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('${Config.baseUrl}/auth/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'name': name,
              'email': email,
              'password': password,
              'phone': phone,
              'gender': gender,
            }),
          )
          .timeout(const Duration(seconds: 20));
      return _result(res);
    } catch (e) {
      return _networkError(e);
    }
  }

  /// POST /auth/login — returns a JWT, which we store on success.
  static Future<ApiResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('${Config.baseUrl}/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 20));

      final result = _result(res);
      if (result.ok && result.data['token'] != null) {
        await saveToken(result.data['token'].toString());
      }
      return result;
    } catch (e) {
      return _networkError(e);
    }
  }

  // ------------------------------------------------------------- posts

  /// POST /posts/create — multipart/form-data.
  ///
  /// The image cannot travel in a JSON body, so this is a multipart
  /// request: the file goes in the `image` field (matching
  /// `upload.single('image')` on the server) alongside the text fields.
  static Future<ApiResult> createPost({
    required File image,
    String? caption,
    String? location,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return ApiResult(ok: false, statusCode: 401, message: 'Not logged in');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${Config.baseUrl}/posts/create'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      // Note: do NOT set Content-Type here — http generates the
      // multipart boundary itself, and overriding it breaks the request.

      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      if (caption != null && caption.isNotEmpty) {
        request.fields['caption'] = caption;
      }
      if (location != null && location.isNotEmpty) {
        request.fields['location'] = location;
      }

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);
      return _result(res);
    } catch (e) {
      return _networkError(e);
    }
  }

  // ------------------------------------------------------------- likes

  /// POST /likes/:id/like
  static Future<ApiResult> likePost(int postId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return ApiResult(ok: false, statusCode: 401, message: 'Not logged in');
      }

      final res = await http.post(
        Uri.parse('${Config.baseUrl}/likes/$postId/like'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 20));

      return _result(res);
    } catch (e) {
      return _networkError(e);
    }
  }

  /// DELETE /likes/:id/unlike
  static Future<ApiResult> unlikePost(int postId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return ApiResult(ok: false, statusCode: 401, message: 'Not logged in');
      }

      final res = await http.delete(
        Uri.parse('${Config.baseUrl}/likes/$postId/unlike'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 20));

      return _result(res);
    } catch (e) {
      return _networkError(e);
    }
  }
}
