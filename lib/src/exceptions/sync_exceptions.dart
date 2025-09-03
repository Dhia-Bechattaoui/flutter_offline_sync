/// Base class for all sync-related exceptions.
abstract class SyncException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const SyncException(this.message, {this.code, this.details});

  @override
  String toString() {
    if (code != null) {
      return 'SyncException($code): $message';
    }
    return 'SyncException: $message';
  }
}

/// Exception thrown when the sync manager is not initialized.
class SyncNotInitializedException extends SyncException {
  const SyncNotInitializedException() : super('Sync manager not initialized');
}

/// Exception thrown when a sync operation fails.
class SyncOperationException extends SyncException {
  const SyncOperationException(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

/// Exception thrown when there's a network error during sync.
class SyncNetworkException extends SyncException {
  const SyncNetworkException(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

/// Exception thrown when there's a database error during sync.
class SyncDatabaseException extends SyncException {
  const SyncDatabaseException(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

/// Exception thrown when there's a conflict that cannot be resolved.
class SyncConflictException extends SyncException {
  const SyncConflictException(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

/// Exception thrown when an entity is not found.
class EntityNotFoundException extends SyncException {
  const EntityNotFoundException(
    String entityId, {
    String? code,
    dynamic details,
  }) : super('Entity not found: $entityId', code: code, details: details);
}

/// Exception thrown when there's a validation error.
class ValidationException extends SyncException {
  const ValidationException(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

/// Exception thrown when there's an authentication error.
class AuthenticationException extends SyncException {
  const AuthenticationException(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

/// Exception thrown when there's an authorization error.
class AuthorizationException extends SyncException {
  const AuthorizationException(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

/// Exception thrown when there's a rate limiting error.
class RateLimitException extends SyncException {
  const RateLimitException(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

/// Exception thrown when there's a timeout error.
class TimeoutException extends SyncException {
  const TimeoutException(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}
