import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:travel_os/core/network/api_client.dart';

class AuthUser {
  final String id;
  final String name;
  final String email;
  final String authProvider;
  final String? picture;
  final String role;

  AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.authProvider,
    this.picture,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      authProvider: json['auth_provider'] ?? 'email',
      picture: json['picture'],
      role: json['role'] ?? 'user',
    );
  }
}

class AuthRepository extends ChangeNotifier {
  final ApiClient _client = ApiClient();
  AuthUser? _currentUser;
  bool _initialized = false;

  AuthRepository() {
    _initSession();
  }

  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _initialized;
  AuthUser? get currentUser => _currentUser;

  Future<void> _initSession() async {
    try {
      final response = await _client.dio.get('/auth/me');
      if (response.statusCode == 200 && response.data != null) {
        _currentUser = AuthUser.fromJson(response.data);
      }
    } catch (e) {
      // Session expired or no internet, token might be cleared
      debugPrint('No current session: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final response = await _client.dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        _currentUser = AuthUser.fromJson(data);
        
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];
        if (accessToken != null && refreshToken != null) {
          await _client.saveSession(accessToken, refreshToken);
        }
        notifyListeners();
        return null; // success
      }
      return 'Authentication failed';
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'];
      return msg is String ? msg : 'Invalid email or password';
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<String?> register(String name, String email, String password) async {
    try {
      final response = await _client.dio.post(
        '/auth/register',
        data: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        _currentUser = AuthUser.fromJson(data);
        
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];
        if (accessToken != null && refreshToken != null) {
          await _client.saveSession(accessToken, refreshToken);
        }
        notifyListeners();
        return null; // success
      }
      return 'Registration failed';
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'];
      return msg is String ? msg : 'An account with this email already exists';
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<String?> loginWithGoogleSession(String sessionId) async {
    try {
      final response = await _client.dio.post(
        '/auth/google/session',
        data: {'session_id': sessionId},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        _currentUser = AuthUser.fromJson(data);

        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];
        if (accessToken != null && refreshToken != null) {
          await _client.saveSession(accessToken, refreshToken);
        }
        notifyListeners();
        return null;
      }
      return 'Google session verification failed';
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'];
      return msg is String ? msg : 'Google login failed';
    } catch (e) {
      return 'Something went wrong';
    }
  }

  Future<void> logout() async {
    try {
      await _client.dio.post('/auth/logout');
    } catch (e) {
      debugPrint('Logout api error: $e');
    } finally {
      _currentUser = null;
      await _client.clearSession();
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _client.dio.post(
        '/auth/forgot-password',
        data: {'email': email.trim().toLowerCase()},
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Reset link generated',
          'dev_reset_link': response.data['dev_reset_link']
        };
      }
    } catch (e) {
      debugPrint('Forgot password error: $e');
    }
    return {
      'success': false,
      'message': 'Failed to request reset link.'
    };
  }

  ApiClient get apiClient => _client;
}

final authRepositoryPrv = ChangeNotifierProvider<AuthRepository>((ref) {
  return AuthRepository();
});
