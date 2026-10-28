import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/utils/app_logger.dart';

/// Result of asking the server for a new verification email.
enum EmailVerificationSendResult { sent, alreadyVerified }

/// Why a resend failed, so the view can pick the message.
enum EmailVerificationSendError { tooManyRequests, unavailable }

class EmailVerificationSendException implements Exception {
  const EmailVerificationSendException(this.reason);
  final EmailVerificationSendError reason;
}

/// `POST /auth/verify-email/send`: emails a new 24 h link to the signed-in
/// user. The link opens the admin page `/verify-email`.
class EmailVerificationRemoteDataSource {
  EmailVerificationRemoteDataSource({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'EmailVerificationDS';

  Future<EmailVerificationSendResult> send() async {
    try {
      final response =
          await _dio.post('$_baseUrl${ApiEndpoints.auth}/verify-email/send');
      final data = response.data;
      final alreadyVerified = data is Map && data['alreadyVerified'] == true;
      return alreadyVerified
          ? EmailVerificationSendResult.alreadyVerified
          : EmailVerificationSendResult.sent;
    } on DioException catch (e) {
      AppLogger.w('Verification email not sent', tag: _tag, error: e);
      throw EmailVerificationSendException(
        e.response?.statusCode == 429
            ? EmailVerificationSendError.tooManyRequests
            : EmailVerificationSendError.unavailable,
      );
    }
  }
}
