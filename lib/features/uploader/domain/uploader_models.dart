class UploadTypeModel {
  final int id;
  final String code;
  final String name;
  final String groupType;

  UploadTypeModel({
    required this.id,
    required this.code,
    required this.name,
    this.groupType = 'Master',
  });

  factory UploadTypeModel.fromJson(Map<String, dynamic> json) => UploadTypeModel(
        id: json['id'] ?? 0,
        code: json['code'] ?? '',
        name: json['name'] ?? '',
        groupType: json['groupType'] ?? 'Master',
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

class BatchRowsPageResult {
  final int total;
  final int page;
  final int pageSize;
  final List<BatchRowResult> rows;

  BatchRowsPageResult({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.rows,
  });

  factory BatchRowsPageResult.fromJson(Map<String, dynamic> json) {
    final rawList = json['rows'] as List? ?? [];
    return BatchRowsPageResult(
      total: (json['total'] is num)
          ? (json['total'] as num).toInt()
          : (json['totalCount'] is num ? (json['totalCount'] as num).toInt() : rawList.length),
      page: (json['page'] is num) ? (json['page'] as num).toInt() : 1,
      pageSize: (json['pageSize'] is num) ? (json['pageSize'] as num).toInt() : 50,
      rows: rawList.map((x) => BatchRowResult.fromJson(x as Map<String, dynamic>)).toList(),
    );
  }
}
