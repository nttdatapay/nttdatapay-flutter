class NdpsPaymentResult {
  final bool success;
  final String status;
  final String description;
  final Map<String, dynamic> rawResponse;

  NdpsPaymentResult({
    required this.success,
    required this.status,
    required this.description,
    required this.rawResponse,
  });
}
