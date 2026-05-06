enum HealthStatus { healthy, degraded, down }

class HealthReport {
  const HealthReport({
    required this.status,
    required this.component,
    required this.message,
  });

  final HealthStatus status;
  final String component;
  final String message;

  bool get isHealthy => status == HealthStatus.healthy;
}

abstract interface class HealthCheckable {
  HealthReport healthCheck();
}
