import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/leaderboard_entry.dart';
import '../models/post.dart';

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

/// Result of a call that returns leaderboard rows.
class LeaderboardResult {
  final bool ok;
  final int statusCode;
  final List<LeaderboardEntry> entries;
  final String message;

  LeaderboardResult({
    required this.ok,
    required this.statusCode,
    this.entries = const [],
    this.message = '',
  });
}

/// Result of a call that returns a list of posts.
class FeedResult {
  final bool ok;
  final int statusCode;
  final List<Post> posts;
  final String message;

  FeedResult({
    required this.ok,
    required this.statusCode,
    this.posts = const [],
    this.message = '',
  });
}

/// Talks to the Natural Beauty backend.
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

  // ------------------------------------------------------------ health

  /// Checks that a backend is reachable at [url].
  ///
  /// There is no dedicated health endpoint, so this POSTs an empty body to
  /// /auth/login. Any HTTP response at all — including the 400 or 401 that
  /// an empty login produces — proves the server is up and answering.
  /// Only a socket-level failure means unreachable.
  static Future<ApiResult> ping(String url) async {
    try {
      final res = await http
          .post(
            Uri.parse('$url/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({}),
          )
          .timeout(const Duration(seconds: 10));

      return ApiResult(
        ok: true,
        statusCode: res.statusCode,
        message: 'Connected — server answered with ${res.statusCode}',
      );
    } on SocketException catch (e) {
      return ApiResult(
        ok: false,
        statusCode: 0,
        message: 'No route to $url\n\n${e.message}\n\n'
            'Check the IP, the Wi-Fi network, and the firewall.',
      );
    } on TimeoutException {
      return ApiResult(
        ok: false,
        statusCode: 0,
        message: 'Timed out reaching $url\n\n'
            'Usually the Windows Firewall blocking port 3000.',
      );
    } catch (e) {
      return ApiResult(ok: false, statusCode: 0, message: 'Failed: $e');
    }
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

  /// GET /posts/feed — all posts, newest first.
  ///
  /// This endpoint does NOT exist on the backend yet; `getPost` and
  /// `getUserPost` are still empty stubs. Until it does, this returns a
  /// failure and the feed screen falls back to placeholder posts.
  ///
  /// It accepts either shape, so no change is needed here when the
  /// endpoint lands:
  ///     [ {...}, {...} ]            a bare array
  ///     { "posts": [ {...} ] }      wrapped in an object
  static Future<FeedResult> getFeed() async {
    try {
      final token = await getToken();
      if (token == null) {
        return FeedResult(
            ok: false, statusCode: 401, message: 'Not logged in');
      }

      final res = await http.get(
        Uri.parse('${Config.baseUrl}/posts/feed'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return FeedResult(
          ok: false,
          statusCode: res.statusCode,
          message: res.statusCode == 404
              ? 'GET /posts/feed returned 404 — the endpoint does not exist yet'
              : 'Feed request failed (${res.statusCode})',
        );
      }

      final decoded = jsonDecode(res.body);
      final List<dynamic> raw = decoded is List
          ? decoded
          : (decoded['posts'] ?? decoded['data'] ?? []) as List<dynamic>;

      return FeedResult(
        ok: true,
        statusCode: res.statusCode,
        posts: raw
            .whereType<Map<String, dynamic>>()
            .map(Post.fromJson)
            .toList(),
      );
    } on SocketException {
      return FeedResult(
        ok: false,
        statusCode: 0,
        message: 'Cannot reach ${Config.baseUrl}',
      );
    } on TimeoutException {
      return FeedResult(
        ok: false,
        statusCode: 0,
        message: 'Timed out reaching ${Config.baseUrl}',
      );
    } catch (e) {
      return FeedResult(ok: false, statusCode: 0, message: 'Feed error: $e');
    }
  }

  /// GET /posts/user/:userId — one user's posts, for the profile grid.
  static Future<FeedResult> getUserPosts(int userId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return FeedResult(ok: false, statusCode: 401, message: 'Not logged in');
      }

      final res = await http.get(
        Uri.parse('${Config.baseUrl}/posts/user/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return FeedResult(
          ok: false,
          statusCode: res.statusCode,
          message: 'Could not load posts (${res.statusCode})',
        );
      }

      final decoded = jsonDecode(res.body);
      final List<dynamic> raw = decoded is List
          ? decoded
          : (decoded['posts'] ?? decoded['data'] ?? []) as List<dynamic>;

      return FeedResult(
        ok: true,
        statusCode: res.statusCode,
        posts:
            raw.whereType<Map<String, dynamic>>().map(Post.fromJson).toList(),
      );
    } on SocketException {
      return FeedResult(
          ok: false, statusCode: 0, message: 'Cannot reach ${Config.baseUrl}');
    } on TimeoutException {
      return FeedResult(ok: false, statusCode: 0, message: 'Timed out');
    } catch (e) {
      return FeedResult(ok: false, statusCode: 0, message: 'Error: $e');
    }
  }

  /// GET /leaderboard — top users by average likes per post.
  ///
  /// [minPosts] is the floor for appearing at all; the server defaults to
  /// 2 so a single lucky post cannot top the board.
  static Future<LeaderboardResult> getLeaderboard({
    int limit = 5,
    int minPosts = 1,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return LeaderboardResult(
            ok: false, statusCode: 401, message: 'Not logged in');
      }

      final res = await http.get(
        Uri.parse(
            '${Config.baseUrl}/leaderboard?limit=$limit&minPosts=$minPosts'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return LeaderboardResult(
          ok: false,
          statusCode: res.statusCode,
          message: res.statusCode == 404
              ? 'Leaderboard endpoint not found — is the server up to date?'
              : 'Could not load leaderboard (${res.statusCode})',
        );
      }

      final decoded = jsonDecode(res.body);
      final List<dynamic> raw = decoded is List
          ? decoded
          : (decoded['leaderboard'] ?? decoded['data'] ?? []) as List<dynamic>;

      return LeaderboardResult(
        ok: true,
        statusCode: res.statusCode,
        entries: raw
            .whereType<Map<String, dynamic>>()
            .map(LeaderboardEntry.fromJson)
            .toList(),
      );
    } on SocketException {
      return LeaderboardResult(
          ok: false, statusCode: 0, message: 'Cannot reach ${Config.baseUrl}');
    } on TimeoutException {
      return LeaderboardResult(
          ok: false, statusCode: 0, message: 'Timed out');
    } catch (e) {
      return LeaderboardResult(ok: false, statusCode: 0, message: 'Error: $e');
    }
  }

  /// GET /auth/me — the logged-in user's profile.
  static Future<ApiResult> getMe() async {
    try {
      final token = await getToken();
      if (token == null) {
        return ApiResult(ok: false, statusCode: 401, message: 'Not logged in');
      }

      final res = await http.get(
        Uri.parse('${Config.baseUrl}/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 20));

      return _result(res);
    } catch (e) {
      return _networkError(e);
    }
  }

  /// DELETE /posts/:id — the server refuses posts that are not yours.
  static Future<ApiResult> deletePost(int postId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return ApiResult(ok: false, statusCode: 401, message: 'Not logged in');
      }

      final res = await http.delete(
        Uri.parse('${Config.baseUrl}/posts/$postId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 20));

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
