import 'dart:async';
import '../utils/logger.dart';
import 'platform_connectivity_impl.dart';

/// Platform-aware connectivity manager that handles different platforms gracefully.
class PlatformConnectivity {
  final Logger _logger = Logger('PlatformConnectivity');
  late final PlatformConnectivityImpl _impl;

  /// Initializes connectivity monitoring for the current platform.
  Future<void> initialize() async {
    try {
      _impl = PlatformConnectivityImpl();
      await _impl.initialize();
      _logger.info('Platform connectivity initialized');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to initialize platform connectivity',
        e,
        stackTrace,
      );
    }
  }

  /// Gets the current connectivity status.
  Future<bool> getConnectivityStatus() async {
    try {
      return await _impl.getConnectivityStatus();
    } catch (e) {
      _logger.error('Failed to get connectivity status', e);
      // Assume online for platforms where connectivity check fails
      return true;
    }
  }

  /// Gets the current online status.
  bool get isOnline => _impl.isOnline;

  /// Stream of connectivity status changes.
  Stream<bool> get connectivityStream => _impl.connectivityStream;

  /// Disposes of the connectivity manager.
  Future<void> dispose() async {
    await _impl.dispose();
    _logger.info('Platform connectivity disposed');
  }
}
