import 'package:connectivity_plus/connectivity_plus.dart';

/// Interface kiểm tra kết nối mạng
abstract class NetworkInfo {
  Future<bool> get isConnected;
}

/// Implementation kiểm tra kết nối mạng
class NetworkInfoImpl implements NetworkInfo {
  final Connectivity connectivity;

  NetworkInfoImpl(this.connectivity);

  @override
  Future<bool> get isConnected async {
    final result = await connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}
