import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_wallet/services/api_client.dart';

/// Only the server may end a session. Anything transport-related has to be
/// treated as retryable, otherwise a flaky connection signs the user out and
/// they have to redo login + email OTP.
void main() {
  group('counts as session expiry', () {
    test('401 with a session message', () {
      expect(
        ApiClient.isSessionExpiredError(
          ApiException('Login required', statusCode: 401),
        ),
        isTrue,
      );
    });

    test('401 with an unrelated message still logs out', () {
      expect(
        ApiClient.isSessionExpiredError(
          ApiException('Token rotated', statusCode: 401),
        ),
        isTrue,
      );
    });

    test('login required without a status code', () {
      expect(
        ApiClient.isSessionExpiredError(ApiException('Login required')),
        isTrue,
      );
    });
  });

  group('keeps the session', () {
    test('connection timeout', () {
      expect(
        ApiClient.isSessionExpiredError(
          ApiException(
            'Server timed out. Check your connection or API URL.',
          ),
        ),
        isFalse,
      );
    });

    test('api unreachable', () {
      expect(
        ApiClient.isSessionExpiredError(
          ApiException('Cannot reach API at https://backend.nexwallet.com.'),
        ),
        isFalse,
      );
    });

    test('socket failure', () {
      expect(
        ApiClient.isSessionExpiredError(
          const SocketException('Network is unreachable'),
        ),
        isFalse,
      );
    });

    test('dio connection error', () {
      expect(
        ApiClient.isSessionExpiredError(
          DioException(
            requestOptions: RequestOptions(path: '/api/me'),
            type: DioExceptionType.connectionError,
          ),
        ),
        isFalse,
      );
    });

    test('server error', () {
      expect(
        ApiClient.isSessionExpiredError(
          ApiException('Internal Server Error', statusCode: 500),
        ),
        isFalse,
      );
    });

    test('unreadable cookie file', () {
      expect(
        ApiClient.isSessionExpiredError(
          const FormatException('Unexpected end of input'),
        ),
        isFalse,
      );
    });
  });
}
