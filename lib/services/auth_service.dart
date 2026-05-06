import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../Config/app_config.dart';
import '../models/user_model.dart';

class AuthService {
  static const _storage     = FlutterSecureStorage();
  static const _keyAccess   = 'access_token';
  static const _keyRefresh  = 'refresh_token';

  // ── TOKENS ──────────────────────────────────────────
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _keyAccess,  value: access);
    await _storage.write(key: _keyRefresh, value: refresh);
  }

  Future<String?> getAccessToken()  => _storage.read(key: _keyAccess);
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefresh);

  Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccess);
    await _storage.delete(key: _keyRefresh);
  }

  Future<bool> hasSession() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ── AUTH HEADERS ────────────────────────────────────
  Future<Map<String, String>> authHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type':  'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── REGISTER ────────────────────────────────────────
  Future<UserModel> register({
    required String email,
    required String name,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'name': name, 'password': password}),
    );

    final data = jsonDecode(utf8.decode(res.bodyBytes));

    if (res.statusCode == 201) {
      await saveTokens(access: data['access'], refresh: data['refresh']);
      return UserModel.fromJson(data['user']);
    }

    // Extraer mensaje de error del backend
    throw Exception(_parseError(data));
  }

  // ── LOGIN ───────────────────────────────────────────
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(utf8.decode(res.bodyBytes));

    if (res.statusCode == 200) {
      await saveTokens(access: data['access'], refresh: data['refresh']);
      return await getMe();
    }

    throw Exception(_parseError(data));
  }

  // ── ME ──────────────────────────────────────────────
  Future<UserModel> getMe() async {
    final res = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/auth/me/'),
      headers: await authHeaders(),
    );

    if (res.statusCode == 200) {
      return UserModel.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }

    throw Exception('Sesión expirada');
  }

  // ── LOGOUT ──────────────────────────────────────────
  Future<void> logout() => clearTokens();

  // ── HELPER ──────────────────────────────────────────
  String _parseError(Map<String, dynamic> data) {
    if (data.containsKey('detail')) return data['detail'];
    // DRF devuelve errores por campo: {"email": ["already exists"]}
    for (final val in data.values) {
      if (val is List && val.isNotEmpty) return val.first.toString();
    }
    return 'Error desconocido';
  }
}