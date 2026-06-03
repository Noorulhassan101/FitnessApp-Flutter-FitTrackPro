import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      // 10.0.2.2 points to localhost of host machine from Android Emulator
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: Platform.isAndroid ? 'http://10.0.2.2:5005/api/v1' : 'http://localhost:5005/api/v1',
      ),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  final storage = ref.read(secureStorageProvider);

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read(key: 'accessToken');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        if (error.response?.statusCode == 401 && 
            error.requestOptions.path != '/auth/login' && 
            error.requestOptions.path != '/auth/register' &&
            error.requestOptions.path != '/auth/refresh') {
          
          final refreshToken = await storage.read(key: 'refreshToken');
          if (refreshToken != null) {
            try {
              // Create clean dio client for refresh request to avoid recursion
              final refreshDio = Dio(BaseOptions(baseUrl: dio.options.baseUrl));
              final response = await refreshDio.post<Map<String, dynamic>>(
                '/auth/refresh',
                data: {'refreshToken': refreshToken},
              );

              if (response.statusCode == 200 || response.statusCode == 201) {
                final newAccessToken = response.data!['accessToken'] as String;
                final newRefreshToken = response.data!['refreshToken'] as String;

                await storage.write(key: 'accessToken', value: newAccessToken);
                await storage.write(key: 'refreshToken', value: newRefreshToken);

                // Retry original request with new token
                final options = error.requestOptions;
                options.headers['Authorization'] = 'Bearer $newAccessToken';

                final retryResponse = await dio.fetch<Map<String, dynamic>>(options);
                return handler.resolve(retryResponse);
              }
            } catch (refreshError) {
              // Refresh token is expired or invalid, log user out
              await storage.delete(key: 'accessToken');
              await storage.delete(key: 'refreshToken');
              // Clear state via auth provider if needed, or let app react to empty token
            }
          }
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
});
