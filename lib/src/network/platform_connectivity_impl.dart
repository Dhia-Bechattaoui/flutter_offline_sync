import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import '../utils/logger.dart';

/// Platform-agnostic connectivity implementation.
class PlatformConnectivityImpl {
  final Logger _logger = Logger('PlatformConnectivityImpl');
  final Connectivity _connectivity;
  final InternetConnection _connectionChecker;

  StreamController<bool>? _connectivityController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<InternetStatus>? _internetSubscription;

  bool _isOnline = false;

  PlatformConnectivityImpl({
    Connectivity? connectivity,
    InternetConnection? connectionChecker,
  }) : _connectivity = connectivity ?? Connectivity(),
       _connectionChecker = connectionChecker ?? InternetConnection();

  /// Initializes connectivity monitoring for the current platform.
  Future<void> initialize() async {
    try {
      _connectivityController = StreamController<bool>.broadcast();
      await _refreshStatus();

      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
      );

      _internetSubscription = _connectionChecker.onStatusChange.listen(
        (status) => _updateOnline(status == InternetStatus.connected),
        onError: (error, stackTrace) {
          _logger.error('Internet status listener failed', error, stackTrace);
        },
      );

      _logger.info('Platform connectivity initialized');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to initialize platform connectivity',
        e,
        stackTrace,
      );
      _updateOnline(true);
    }
  }

  /// Gets the current connectivity status.
  Future<bool> getConnectivityStatus() async {
    try {
      await _refreshStatus();
      return _isOnline;
    } catch (e) {
      _logger.error('Failed to get connectivity status', e);
      return _isOnline;
    }
  }

  /// Gets the current online status.
  bool get isOnline => _isOnline;

  /// Stream of connectivity status changes.
  Stream<bool> get connectivityStream =>
      _connectivityController?.stream ?? Stream.value(_isOnline);

  /// Disposes of the connectivity manager.
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _internetSubscription?.cancel();
    await _connectivityController?.close();
    _logger.info('Platform connectivity disposed');
  }

  Future<void> _refreshStatus() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    if (!_hasConnectivity(connectivityResult)) {
      _updateOnline(false);
      return;
    }

    final hasInternet = await _connectionChecker.hasInternetAccess;
    _updateOnline(hasInternet);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) async {
    if (!_hasConnectivity(results)) {
      _updateOnline(false);
      return;
    }

    // Perform a lightweight internet reachability check
    try {
      final hasInternet = await _connectionChecker.hasInternetAccess;
      _updateOnline(hasInternet);
    } catch (e, stackTrace) {
      _logger.error('Internet reachability check failed', e, stackTrace);
    }
  }

  void _updateOnline(bool online) {
    if (_isOnline == online) {
      return;
    }

    _isOnline = online;
    _logger.debug('Connectivity status changed: $_isOnline');
    _connectivityController?.add(_isOnline);
  }

  bool _hasConnectivity(dynamic result) {
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    if (result is List<ConnectivityResult>) {
      return result.any((value) => value != ConnectivityResult.none);
    }
    return true;
  }
}
