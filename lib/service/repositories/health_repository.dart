import 'package:tahfeex/shared/connections/connections.dart';
import 'package:tahfeex/shared/constants/constants.dart';

class HealthStatus {
  final String status;
  final DateTime timestamp;

  const HealthStatus({required this.status, required this.timestamp});

  bool get isOk => status == 'ok';

  static HealthStatus fromMap(Map<String, dynamic> map) => HealthStatus(
        status: map['status'] as String? ?? 'unknown',
        timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Wraps `GET /health` — no auth required.
class HealthRepository {
  final _client = DioClient();

  Future<HealthStatus> checkHealth() async {
    final data = await _client.get(ApiConstants.health);
    return HealthStatus.fromMap(data as Map<String, dynamic>);
  }
}
