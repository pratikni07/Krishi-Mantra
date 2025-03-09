class OTPVerificationResult {
  final bool isRegistered;
  final String? message;
  final String? phoneNo;

  OTPVerificationResult({
    required this.isRegistered,
    this.message,
    this.phoneNo,
  });

  factory OTPVerificationResult.fromJson(Map<String, dynamic> json) {
    return OTPVerificationResult(
      isRegistered: json['isRegistered'] ?? false,
      message: json['message'],
      phoneNo: json['phoneNo'],
    );
  }
}
