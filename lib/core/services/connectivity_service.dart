import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Connectivity status enum
enum NetworkStatus {
  online,
  offline,
  weak, // For slow connections
}

/// Service for monitoring network connectivity
class ConnectivityService {
  static ConnectivityService? _instance;
  
  final Connectivity _connectivity = Connectivity();
  final StreamController<NetworkStatus> _statusController = 
      StreamController<NetworkStatus>.broadcast();
  
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  NetworkStatus _currentStatus = NetworkStatus.online;

  ConnectivityService._() {
    _init();
  }

  static ConnectivityService get instance {
    _instance ??= ConnectivityService._();
    return _instance!;
  }

  /// Stream of network status changes
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  /// Current network status
  NetworkStatus get currentStatus => _currentStatus;

  /// Check if currently online
  bool get isOnline => _currentStatus == NetworkStatus.online;

  /// Check if currently offline
  bool get isOffline => _currentStatus == NetworkStatus.offline;

  void _init() {
    // Check initial status
    _checkStatus();

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_handleChange);
  }

  Future<void> _checkStatus() async {
    final results = await _connectivity.checkConnectivity();
    _handleChange(results);
  }

  void _handleChange(List<ConnectivityResult> results) {
    NetworkStatus newStatus;

    if (results.contains(ConnectivityResult.none) || results.isEmpty) {
      newStatus = NetworkStatus.offline;
    } else if (results.contains(ConnectivityResult.wifi) ||
               results.contains(ConnectivityResult.ethernet)) {
      newStatus = NetworkStatus.online;
    } else if (results.contains(ConnectivityResult.mobile)) {
      // Mobile data - could be slow
      newStatus = NetworkStatus.online;
    } else {
      newStatus = NetworkStatus.weak;
    }

    if (newStatus != _currentStatus) {
      _currentStatus = newStatus;
      _statusController.add(newStatus);
    }
  }

  /// Force refresh connectivity status
  Future<NetworkStatus> refresh() async {
    await _checkStatus();
    return _currentStatus;
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}

/// Provider for connectivity service
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService.instance;
});

/// Provider for current network status
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.statusStream;
});

/// Provider for checking if online
final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(networkStatusProvider);
  return status.maybeWhen(
    data: (s) => s != NetworkStatus.offline,
    orElse: () => true, // Assume online by default
  );
});

