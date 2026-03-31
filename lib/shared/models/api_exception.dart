/// Thrown by [DioClient] whenever the server returns an HTTP 4xx or 5xx.
/// The [code] field maps to the machine-readable code from the API error body:
///   { "error": "Human message", "code": "MACHINE_CODE" }
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String code;

  const ApiException({
    required this.statusCode,
    required this.message,
    required this.code,
  });

  // ── convenience getters ──────────────────────────────────────────────────

  bool get isUnauthorized        => statusCode == 401;
  bool get isForbidden           => statusCode == 403;
  bool get isNotFound            => statusCode == 404;

  bool get isDuplicateHash          => code == ApiErrorCodes.duplicateHash;
  bool get isDuplicateReciterSurah  => code == ApiErrorCodes.duplicateReciterSurah;
  bool get isValidationError        => code == ApiErrorCodes.validationError;
  bool get isInternalError          => code == ApiErrorCodes.internalError;
  bool get isMaxActiveJourneys      => code == ApiErrorCodes.maxActiveJourneys;
  bool get isJourneyCompleted       => code == ApiErrorCodes.journeyCompleted;
  bool get isJourneyAbandoned       => code == ApiErrorCodes.journeyAbandoned;
  bool get isUsernameTaken          => code == ApiErrorCodes.usernameTaken;
  bool get isAlreadyCompanions      => code == ApiErrorCodes.alreadyCompanions;
  bool get isRequestAlreadySent     => code == ApiErrorCodes.requestAlreadySent;
  bool get isAlreadyBlocked         => code == ApiErrorCodes.alreadyBlocked;
  bool get isAlreadyMember          => code == ApiErrorCodes.alreadyMember;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// Machine-readable error codes as defined in API.md.
class ApiErrorCodes {
  static const String validationError        = 'VALIDATION_ERROR';
  static const String unauthorized           = 'UNAUTHORIZED';
  static const String forbidden              = 'FORBIDDEN';
  static const String notFound               = 'NOT_FOUND';
  static const String duplicateHash          = 'DUPLICATE_HASH';
  static const String duplicateReciterSurah  = 'DUPLICATE_RECITER_SURAH';
  static const String internalError          = 'INTERNAL_ERROR';
  static const String maxActiveJourneys      = 'MAX_ACTIVE_JOURNEYS';
  static const String journeyCompleted       = 'JOURNEY_COMPLETED';
  static const String journeyAbandoned       = 'JOURNEY_ABANDONED';
  static const String usernameTaken          = 'USERNAME_TAKEN';
  static const String alreadyCompanions      = 'ALREADY_COMPANIONS';
  static const String requestAlreadySent     = 'REQUEST_ALREADY_SENT';
  static const String alreadyBlocked         = 'ALREADY_BLOCKED';
  static const String alreadyMember          = 'ALREADY_MEMBER';
  static const String unknown                = 'UNKNOWN';
}
