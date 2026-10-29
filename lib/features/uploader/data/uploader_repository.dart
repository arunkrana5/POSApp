import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../../config/api_config.dart';
import '../domain/uploader_models.dart';

class UploaderRepository {
  final String? token;
  final int? tenantId;

  UploaderRepository({this.token, this.tenantId});

  Map<String, String> get _headers {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token!.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }
    if (tenantId != null && tenantId! > 0) {
      map['X-Tenant-Id'] = tenantId.toString();
    }
    return map;
  }

  Future<List<UploadTypeModel>> fetchTypes() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/uploader/types');
    final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((x) => UploadTypeModel.fromJson(x)).toList();
    } else {
      throw Exception('Failed to load upload types: ${response.statusCode}');
    }
  }

  Future<String> uploadExcel(String typeCode, PlatformFile file) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/uploader/upload/$typeCode');
    final request = http.MultipartRequest('POST', uri);

    if (token != null && token!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (tenantId != null && tenantId! > 0) {
      request.headers['X-Tenant-Id'] = tenantId.toString();
    }

    if (file.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
        ),
      );
    } else if (file.path != null && file.path!.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path!,
          filename: file.name,
        ),
      );
    } else {
      throw Exception('Selected file has no data or path available.');
    }

    final streamedResponse = await request.send().timeout(const Duration(minutes: 2));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['batchId']?.toString() ?? '';
    } else {
      final json = jsonDecode(response.body);
      throw Exception(json['message'] ?? 'Upload failed with code ${response.statusCode}');
    }
  }

  Future<void> startProcessing(String batchId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/uploader/batch/$batchId/process');
    final response = await http.post(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 202) {
      final json = jsonDecode(response.body);
      throw Exception(json['message'] ?? 'Processing request failed');
    }
  }

  Future<UploadBatchStatus> getBatchStatus(String batchId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/uploader/batch/$batchId/status');
    final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return UploadBatchStatus.fromJson(json);
    } else {
      throw Exception('Failed to get batch status');
    }
  }

  Future<List<BatchRowResult>> getBatchRows(
    String batchId, {
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    var url = '${ApiConfig.baseUrl}/uploader/batch/$batchId/rows?page=$page&pageSize=$pageSize';
    if (status != null && status.isNotEmpty) {
      url += '&status=${Uri.encodeComponent(status)}';
    }
    final response = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List list = json['rows'] ?? [];
      return list.map((x) => BatchRowResult.fromJson(x)).toList();
    } else {
      throw Exception('Failed to load batch rows');
    }
  }

  Future<List<UploadBatchStatus>> getBatches({int page = 1, int pageSize = 20}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/uploader/batches?page=$page&pageSize=$pageSize');
    final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.map((x) => UploadBatchStatus.fromJson(x)).toList();
    } else {
      throw Exception('Failed to load batch history');
    }
  }

  String getTemplateUrl(String typeCode) =>
      '${ApiConfig.baseUrl}/uploader/template/$typeCode';

  String getReportUrl(String batchId) =>
      '${ApiConfig.baseUrl}/uploader/batch/$batchId/report';

  Future<Uint8List> downloadTemplateBytes(String typeCode) async {
    final uri = Uri.parse(getTemplateUrl(typeCode));
    final headers = <String, String>{
      'Accept': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/octet-stream',
    };
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (tenantId != null && tenantId! > 0) {
      headers['X-Tenant-Id'] = tenantId.toString();
    }

    final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      String msg = 'Failed to download template (${response.statusCode})';
      try {
        final json = jsonDecode(response.body);
        if (json['message'] != null) msg = json['message'];
      } catch (_) {}
      throw Exception(msg);
    }
  }

  Future<Uint8List> downloadReportBytes(String batchId) async {
    final uri = Uri.parse(getReportUrl(batchId));
    final headers = <String, String>{
      'Accept': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/octet-stream',
    };
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (tenantId != null && tenantId! > 0) {
      headers['X-Tenant-Id'] = tenantId.toString();
    }

    final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 45));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      String msg = 'Failed to download report (${response.statusCode})';
      try {
        final json = jsonDecode(response.body);
        if (json['message'] != null) msg = json['message'];
      } catch (_) {}
      throw Exception(msg);
    }
  }
}
