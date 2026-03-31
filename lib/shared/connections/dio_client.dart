import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:tahfeex/shared/constants/constants.dart';
import 'package:tahfeex/shared/models/models.dart';

const _connectTimeout = Duration(seconds: 15);
const _receiveTimeout = Duration(seconds: 30);

/// Singleton Dio wrapper.
///
/// Configure at app start:
///   DioClient().setBaseUrl(ApiConstants.devBaseUrl);
///
/// The token provider is wired automatically by [AuthService] — you do not
/// need to call anything on DioClient directly after that.
class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio _dio;

  /// Async provider called before every request.  Returns the current Firebase
  /// ID token (or null when signed out).  Set once in AuthService after sign-in.
  Future<String?> Function()? _tokenProvider;

  DioClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.devBaseUrl,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      headers: const {'Content-Type': 'application/json; charset=UTF-8'},
      // Accept all status codes so we can always read the error body.
      validateStatus: (_) => true,
    ));

    // ── Logger middleware ────────────────────────────────────────────────────
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (obj) => debugPrint('[HTTP] $obj'),
      ));
    }

    // ── Auth + error-parsing middleware ──────────────────────────────────────
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_tokenProvider != null) {
          final token = await _tokenProvider!();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        final status = response.statusCode ?? 0;
        if (status >= 400) {
          handler.reject(_toException(response));
        } else {
          handler.next(response);
        }
      },
      onError: (error, handler) {
        // Already an ApiException — pass through.
        if (error.error is ApiException) {
          handler.next(error);
          return;
        }
        handler.reject(_wrapNetworkError(error));
      },
    ));
  }

  // ── Public configuration ─────────────────────────────────────────────────

  /// Switch base URL at runtime (e.g. dev ↔ prod).
  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  /// Register an async provider that returns a fresh Firebase ID token before
  /// every authenticated request.  Pass `null` to clear (e.g. on sign-out).
  ///
  /// Usage (called once in AuthService after sign-in):
  ///   DioClient().setTokenProvider(
  ///     () => FirebaseAuth.instance.currentUser?.getIdToken(),
  ///   );
  void setTokenProvider(Future<String?> Function()? provider) {
    _tokenProvider = provider;
  }

  // ── HTTP methods ──────────────────────────────────────────────────────────

  Future<dynamic> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final r = await _dio.get(uri,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress);
      return r.data;
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<dynamic> post(
    String uri, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final r = await _dio.post(uri,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress);
      return r.data;
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<dynamic> put(
    String uri, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final r = await _dio.put(uri,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress);
      return r.data;
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<dynamic> patch(
    String uri, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final r = await _dio.patch(uri,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
          onSendProgress: onSendProgress);
      return r.data;
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<dynamic> delete(
    String uri, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final r = await _dio.delete(uri,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken);
      return r.data;
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Convert a 4xx/5xx [Response] into a [DioException] carrying an [ApiException].
  DioException _toException(Response response) {
    final data = response.data;
    final message = (data is Map)
        ? (data['error'] as String? ?? 'Unknown error')
        : 'Unknown error';
    final code = (data is Map)
        ? (data['code'] as String? ?? ApiErrorCodes.unknown)
        : ApiErrorCodes.unknown;
    return DioException(
      requestOptions: response.requestOptions,
      response: response,
      error: ApiException(
          statusCode: response.statusCode ?? 0,
          message: message,
          code: code),
    );
  }

  DioException _wrapNetworkError(DioException e) {
    String message;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timed out. Please try again.';
      case DioExceptionType.connectionError:
        message = 'No connection. Please check your internet.';
      case DioExceptionType.cancel:
        message = 'Request was cancelled.';
      default:
        message = e.message ?? 'An unknown error occurred.';
    }
    return DioException(
      requestOptions: e.requestOptions,
      error: ApiException(
          statusCode: 0, message: message, code: ApiErrorCodes.unknown),
    );
  }

  /// Unwrap the [ApiException] from a [DioException], or rethrow network errors.
  Exception _unwrap(DioException e) {
    if (e.error is ApiException) return e.error as ApiException;
    if (e.error is SocketException) {
      return ApiException(
          statusCode: 0,
          message: 'No connection. Please check your internet.',
          code: ApiErrorCodes.unknown);
    }
    return ApiException(
        statusCode: 0,
        message: e.message ?? 'An unknown error occurred.',
        code: ApiErrorCodes.unknown);
  }
}
