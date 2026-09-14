class PostResponse {
  final String viewAsString;
  final bool status;
  final int statusCode;
  final String message;
  final String redirectURL;
  final int id;
  final String additionalMessage;

  PostResponse({
    required this.viewAsString,
    required this.status,
    required this.statusCode,
    required this.message,
    required this.redirectURL,
    required this.id,
    required this.additionalMessage,
  });

  factory PostResponse.fromJson(Map<String, dynamic> json) {
    return PostResponse(
      viewAsString: json['viewAsString'] ?? '',
      status: json['status'] ?? false,
      statusCode: json['statusCode'] ?? 500,
      message: json['message'] ?? '',
      redirectURL: json['redirectURL'] ?? '',
      id: json['id'] ?? 0,
      additionalMessage: json['additionalMessage'] ?? '',
    );
  }
}
