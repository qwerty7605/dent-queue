class StatusResponse {
  final String? status;
  final String? message;

  StatusResponse({this.status, this.message});

  factory StatusResponse.fromJson(Map<String, dynamic> json) {
    return StatusResponse(
      status: json['status'] as String?,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
    };
  }
}
