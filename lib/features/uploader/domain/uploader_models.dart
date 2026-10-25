class UploadTypeModel {
  final int id;
  final String code;
  final String name;

  UploadTypeModel({required this.id, required this.code, required this.name});

  factory UploadTypeModel.fromJson(Map<String, dynamic> json) => UploadTypeModel(
        id: json['id'] ?? 0,
        code: json['code'] ?? '',
        name: json['name'] ?? '',
      );
}

class UploadBatchStatus {
  final String batchId;
  final String typeCode;
  final String fileName;
  final int totalRows;
  final int successRows;
  final int errorRows;
  final String status; // Uploaded, Validating, Syncing, Completed, Failed
  final String? errorMessage;

  UploadBatchStatus({
    required this.batchId,
    required this.typeCode,
    required this.fileName,
    required this.totalRows,
    required this.successRows,
    required this.errorRows,
    required this.status,
    this.errorMessage,
  });

  factory UploadBatchStatus.fromJson(Map<String, dynamic> json) => UploadBatchStatus(
        batchId: json['batchId'] ?? '',
        typeCode: json['typeCode'] ?? '',
        fileName: json['fileName'] ?? '',
        totalRows: json['totalRows'] ?? 0,
        successRows: json['successRows'] ?? 0,
        errorRows: json['errorRows'] ?? 0,
        status: json['status'] ?? 'Uploaded',
        errorMessage: json['errorMessage'],
      );
}

class BatchRowResult {
  final int rowNo;
  final String keyValue;
  final String status;
  final String? message;

  BatchRowResult({
    required this.rowNo,
    required this.keyValue,
    required this.status,
    this.message,
  });

  factory BatchRowResult.fromJson(Map<String, dynamic> json) => BatchRowResult(
        rowNo: json['rowNo'] ?? 0,
        keyValue: json['keyValue'] ?? '',
        status: json['status'] ?? '',
        message: json['message'],
      );
}
