import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_offline_sync/src/exceptions/sync_exceptions.dart';

void main() {
  group('SyncException', () {
    test('should create with message only', () {
      const exception = SyncOperationException('Test message');

      expect(exception.message, 'Test message');
      expect(exception.code, isNull);
      expect(exception.details, isNull);
      expect(exception.toString(), 'SyncException: Test message');
    });

    test('should create with message and code', () {
      const exception = SyncOperationException(
        'Test message',
        code: 'TEST_CODE',
      );

      expect(exception.message, 'Test message');
      expect(exception.code, 'TEST_CODE');
      expect(exception.details, isNull);
      expect(exception.toString(), 'SyncException(TEST_CODE): Test message');
    });

    test('should create with message, code and details', () {
      const details = {'key': 'value'};
      const exception = SyncOperationException(
        'Test message',
        code: 'TEST_CODE',
        details: details,
      );

      expect(exception.message, 'Test message');
      expect(exception.code, 'TEST_CODE');
      expect(exception.details, details);
      expect(exception.toString(), 'SyncException(TEST_CODE): Test message');
    });
  });

  group('SyncNotInitializedException', () {
    test('should create with default message', () {
      const exception = SyncNotInitializedException();

      expect(exception.message, 'Sync manager not initialized');
      expect(exception.code, isNull);
      expect(exception.details, isNull);
      expect(
        exception.toString(),
        'SyncException: Sync manager not initialized',
      );
    });
  });

  group('SyncOperationException', () {
    test('should create with custom message', () {
      const exception = SyncOperationException('Operation failed');

      expect(exception.message, 'Operation failed');
      expect(exception.toString(), 'SyncException: Operation failed');
    });

    test('should create with code', () {
      const exception = SyncOperationException(
        'Operation failed',
        code: 'OP_FAILED',
      );

      expect(exception.message, 'Operation failed');
      expect(exception.code, 'OP_FAILED');
      expect(
        exception.toString(),
        'SyncException(OP_FAILED): Operation failed',
      );
    });
  });

  group('SyncNetworkException', () {
    test('should create with network error message', () {
      const exception = SyncNetworkException('Network connection failed');

      expect(exception.message, 'Network connection failed');
      expect(exception.toString(), 'SyncException: Network connection failed');
    });

    test('should create with HTTP status code', () {
      const exception = SyncNetworkException(
        'HTTP 500 error',
        code: 'HTTP_500',
        details: {'statusCode': 500},
      );

      expect(exception.message, 'HTTP 500 error');
      expect(exception.code, 'HTTP_500');
      expect(exception.details, {'statusCode': 500});
    });
  });

  group('SyncDatabaseException', () {
    test('should create with database error message', () {
      const exception = SyncDatabaseException('Database connection failed');

      expect(exception.message, 'Database connection failed');
      expect(exception.toString(), 'SyncException: Database connection failed');
    });

    test('should create with SQL error details', () {
      const exception = SyncDatabaseException(
        'SQL syntax error',
        code: 'SQL_ERROR',
        details: {'query': 'SELECT * FROM invalid_table'},
      );

      expect(exception.message, 'SQL syntax error');
      expect(exception.code, 'SQL_ERROR');
      expect(exception.details, {'query': 'SELECT * FROM invalid_table'});
    });
  });

  group('SyncConflictException', () {
    test('should create with conflict message', () {
      const exception = SyncConflictException('Data conflict detected');

      expect(exception.message, 'Data conflict detected');
      expect(exception.toString(), 'SyncException: Data conflict detected');
    });

    test('should create with conflict details', () {
      const exception = SyncConflictException(
        'Version conflict',
        code: 'VERSION_CONFLICT',
        details: {'localVersion': 5, 'remoteVersion': 7},
      );

      expect(exception.message, 'Version conflict');
      expect(exception.code, 'VERSION_CONFLICT');
      expect(exception.details, {'localVersion': 5, 'remoteVersion': 7});
    });
  });

  group('EntityNotFoundException', () {
    test('should create with entity ID', () {
      const exception = EntityNotFoundException('entity-123');

      expect(exception.message, 'Entity not found: entity-123');
      expect(
        exception.toString(),
        'SyncException: Entity not found: entity-123',
      );
    });

    test('should create with code and details', () {
      const exception = EntityNotFoundException(
        'entity-456',
        code: 'ENTITY_NOT_FOUND',
        details: {'table': 'users'},
      );

      expect(exception.message, 'Entity not found: entity-456');
      expect(exception.code, 'ENTITY_NOT_FOUND');
      expect(exception.details, {'table': 'users'});
    });
  });

  group('ValidationException', () {
    test('should create with validation message', () {
      const exception = ValidationException('Invalid email format');

      expect(exception.message, 'Invalid email format');
      expect(exception.toString(), 'SyncException: Invalid email format');
    });

    test('should create with field validation details', () {
      const exception = ValidationException(
        'Required field missing',
        code: 'REQUIRED_FIELD',
        details: {'field': 'email', 'value': null},
      );

      expect(exception.message, 'Required field missing');
      expect(exception.code, 'REQUIRED_FIELD');
      expect(exception.details, {'field': 'email', 'value': null});
    });
  });

  group('AuthenticationException', () {
    test('should create with auth message', () {
      const exception = AuthenticationException('Invalid credentials');

      expect(exception.message, 'Invalid credentials');
      expect(exception.toString(), 'SyncException: Invalid credentials');
    });

    test('should create with token details', () {
      const exception = AuthenticationException(
        'Token expired',
        code: 'TOKEN_EXPIRED',
        details: {'expiresAt': '2024-01-01T00:00:00Z'},
      );

      expect(exception.message, 'Token expired');
      expect(exception.code, 'TOKEN_EXPIRED');
      expect(exception.details, {'expiresAt': '2024-01-01T00:00:00Z'});
    });
  });

  group('AuthorizationException', () {
    test('should create with authorization message', () {
      const exception = AuthorizationException('Insufficient permissions');

      expect(exception.message, 'Insufficient permissions');
      expect(exception.toString(), 'SyncException: Insufficient permissions');
    });

    test('should create with permission details', () {
      const exception = AuthorizationException(
        'Access denied',
        code: 'ACCESS_DENIED',
        details: {'requiredRole': 'admin', 'userRole': 'user'},
      );

      expect(exception.message, 'Access denied');
      expect(exception.code, 'ACCESS_DENIED');
      expect(exception.details, {'requiredRole': 'admin', 'userRole': 'user'});
    });
  });

  group('RateLimitException', () {
    test('should create with rate limit message', () {
      const exception = RateLimitException('Rate limit exceeded');

      expect(exception.message, 'Rate limit exceeded');
      expect(exception.toString(), 'SyncException: Rate limit exceeded');
    });

    test('should create with rate limit details', () {
      const exception = RateLimitException(
        'Too many requests',
        code: 'RATE_LIMIT',
        details: {
          'limit': 100,
          'remaining': 0,
          'resetAt': '2024-01-01T01:00:00Z',
        },
      );

      expect(exception.message, 'Too many requests');
      expect(exception.code, 'RATE_LIMIT');
      expect(exception.details, {
        'limit': 100,
        'remaining': 0,
        'resetAt': '2024-01-01T01:00:00Z',
      });
    });
  });

  group('TimeoutException', () {
    test('should create with timeout message', () {
      const exception = TimeoutException('Request timed out');

      expect(exception.message, 'Request timed out');
      expect(exception.toString(), 'SyncException: Request timed out');
    });

    test('should create with timeout details', () {
      const exception = TimeoutException(
        'Connection timeout',
        code: 'CONNECTION_TIMEOUT',
        details: {'timeout': 30000, 'attempts': 3},
      );

      expect(exception.message, 'Connection timeout');
      expect(exception.code, 'CONNECTION_TIMEOUT');
      expect(exception.details, {'timeout': 30000, 'attempts': 3});
    });
  });

  group('Exception inheritance', () {
    test('all exceptions should implement SyncException', () {
      const exceptions = [
        SyncNotInitializedException(),
        SyncOperationException('test'),
        SyncNetworkException('test'),
        SyncDatabaseException('test'),
        SyncConflictException('test'),
        EntityNotFoundException('test'),
        ValidationException('test'),
        AuthenticationException('test'),
        AuthorizationException('test'),
        RateLimitException('test'),
        TimeoutException('test'),
      ];

      for (final exception in exceptions) {
        expect(exception, isA<SyncException>());
        expect(exception, isA<Exception>());
      }
    });
  });
}
