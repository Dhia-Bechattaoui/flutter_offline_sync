import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_offline_sync/src/network/network_manager.dart';

void main() {
  group('NetworkManager', () {
    late NetworkManager networkManager;

    setUp(() {
      networkManager = NetworkManager();
    });

    tearDown(() {
      networkManager.dispose();
    });

    group('initialization', () {
      test('should initialize with default values', () async {
        await networkManager.initialize();
        expect(networkManager.isOnline, isA<bool>());
      });

      test('should initialize with custom values', () async {
        await networkManager.initialize(
          baseUrl: 'https://api.example.com',
          defaultHeaders: {'Content-Type': 'application/json'},
          timeout: const Duration(seconds: 60),
        );
        expect(networkManager.isOnline, isA<bool>());
      });
    });

    group('connectivity', () {
      test('should have isOnline property', () async {
        await networkManager.initialize();
        expect(networkManager.isOnline, isA<bool>());
      });

      test('should have connectivityStream property', () async {
        await networkManager.initialize();
        expect(networkManager.connectivityStream, isA<Stream<bool>>());
      });

      test('should get connectivity status', () async {
        await networkManager.initialize();
        final status = await networkManager.getConnectivityStatus();
        expect(status, isA<bool>());
      });
    });

    group('HTTP methods', () {
      test('should handle GET requests', () async {
        await networkManager.initialize();
        expect(
          () => networkManager.get('https://api.example.com/test'),
          returnsNormally,
        );
      });

      test('should handle POST requests', () async {
        await networkManager.initialize();
        expect(
          () => networkManager.post(
            'https://api.example.com/test',
            data: {'key': 'value'},
          ),
          returnsNormally,
        );
      });

      test('should handle PUT requests', () async {
        await networkManager.initialize();
        expect(
          () => networkManager.put(
            'https://api.example.com/test',
            data: {'key': 'value'},
          ),
          returnsNormally,
        );
      });

      test('should handle DELETE requests', () async {
        await networkManager.initialize();
        expect(
          () => networkManager.delete('https://api.example.com/test'),
          returnsNormally,
        );
      });
    });

    group('configuration', () {
      test('should set base URL', () async {
        await networkManager.initialize();
        expect(
          () => networkManager.setBaseUrl('https://api.example.com'),
          returnsNormally,
        );
      });

      test('should set default headers', () async {
        await networkManager.initialize();
        expect(
          () => networkManager.setDefaultHeaders({
            'Content-Type': 'application/json',
          }),
          returnsNormally,
        );
      });

      test('should set timeout', () async {
        await networkManager.initialize();
        expect(
          () => networkManager.setTimeout(const Duration(seconds: 30)),
          returnsNormally,
        );
      });
    });

    group('disposal', () {
      test('should dispose properly', () async {
        await networkManager.initialize();
        expect(() => networkManager.dispose(), returnsNormally);
      });
    });
  });
}
