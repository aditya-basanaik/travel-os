import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  final Dio dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Dynamic Base URL check for Android Emulator vs iOS Simulator/Web/Physical devices
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8001/api';
    }
    // Connect to host PC local network IP
    return 'http://172.19.47.12:8001/api';
  }

  ApiClient() {
    dio.options.baseUrl = baseUrl;
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 15);
    
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Read access token from secure storage
          final accessToken = await _storage.read(key: 'access_token');
          if (accessToken != null) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          final options = error.requestOptions;
          
          // If token expired (401) and we haven't retried yet
          if (error.response?.statusCode == 401 && 
              options.extra['retried'] != true && 
              !options.path.contains('/auth/')) {
            options.extra['retried'] = true;
            
            try {
              final renewed = await _refreshTokens();
              if (renewed) {
                // Read new access token and retry the original request
                final newAccessToken = await _storage.read(key: 'access_token');
                options.headers['Authorization'] = 'Bearer $newAccessToken';
                
                // Retry request
                final response = await dio.fetch(options);
                return handler.resolve(response);
              }
            } catch (e) {
              // Refresh failed, clear session
              await clearSession();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<bool> _refreshTokens() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) return false;

    try {
      // Create separate Dio instance to avoid interceptor loop
      final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));
      final response = await refreshDio.post(
        '/auth/refresh',
        options: Options(
          headers: {'Authorization': 'Bearer $refreshToken'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final newAccess = response.data['access_token'];
        final newRefresh = response.data['refresh_token'];
        
        if (newAccess != null) {
          await _storage.write(key: 'access_token', value: newAccess);
        }
        if (newRefresh != null) {
          await _storage.write(key: 'refresh_token', value: newRefresh);
        }
        return true;
      }
    } catch (e) {
      debugPrint('Token renewal failed: $e');
    }
    return false;
  }

  Future<void> saveSession(String accessToken, String refreshToken) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }
}
