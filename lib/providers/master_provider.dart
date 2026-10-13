import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class MasterItem {
  final int id;
  final String masterType;
  final String masterName;
  final String masterCode;
  final String description;
  final int priority;
  final bool isActive;

  MasterItem({
    required this.id,
    required this.masterType,
    required this.masterName,
    required this.masterCode,
    this.description = '',
    this.priority = 0,
    this.isActive = true,
  });

  factory MasterItem.fromJson(Map<String, dynamic> json) {
    return MasterItem(
      id: json['id'] is int ? json['id'] : (int.tryParse('${json['id'] ?? json['ID'] ?? 0}') ?? 0),
      masterType: (json['masterType'] ?? json['MasterType'] ?? '').toString(),
      masterName: (json['masterName'] ?? json['MasterName'] ?? json['name'] ?? json['Name'] ?? '').toString(),
      masterCode: (json['masterCode'] ?? json['MasterCode'] ?? json['code'] ?? json['Code'] ?? '').toString(),
      description: (json['description'] ?? json['Description'] ?? '').toString(),
      priority: json['priority'] is int ? json['priority'] : (int.tryParse('${json['priority'] ?? json['Priority'] ?? 0}') ?? 0),
      isActive: json['isActive'] == null ? true : json['isActive'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'masterType': masterType,
    'masterName': masterName,
    'masterCode': masterCode,
    'description': description,
    'priority': priority,
    'isActive': isActive,
  };
}

class MasterProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  bool _hasFetched = false;

  List<MasterItem> _allMasters = [];
  List<MasterItem> _categories = [];
  List<MasterItem> _uoms = [];
  List<MasterItem> _itemTypes = [];
  List<MasterItem> _brands = [];
  List<MasterItem> _paymentModes = [];
  List<MasterItem> _taxes = [];
  List<MasterItem> _expenseCategories = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasFetched => _hasFetched;

  List<MasterItem> get allMasters => _allMasters;
  List<MasterItem> get categories => _categories;
  List<MasterItem> get uoms => _uoms;
  List<MasterItem> get itemTypes => _itemTypes;
  List<MasterItem> get brands => _brands;
  List<MasterItem> get paymentModes => _paymentModes;
  List<MasterItem> get taxes => _taxes;
  List<MasterItem> get expenseCategories => _expenseCategories;

  List<MasterItem> getOptions(String masterType, {bool activeOnly = true}) {
    final lower = masterType.trim().toLowerCase();
    List<MasterItem> list;
    if (lower == 'itemcategory' || lower == 'category' || lower == 'categories') {
      list = _categories;
    } else if (lower == 'unitofmeasurement' || lower == 'uom' || lower == 'unit' || lower == 'units') {
      list = _uoms;
    } else if (lower == 'itemtype' || lower == 'itemtypes' || lower == 'format') {
      list = _itemTypes;
    } else if (lower == 'brand' || lower == 'brands') {
      list = _brands;
    } else if (lower == 'paymentmode' || lower == 'paymentmodes' || lower == 'payment') {
      list = _paymentModes;
    } else if (lower == 'tax' || lower == 'taxes' || lower == 'gst') {
      list = _taxes;
    } else if (lower == 'expensecategory' || lower == 'expensecategories') {
      list = _expenseCategories;
    } else {
      list = _allMasters.where((m) => m.masterType.toLowerCase() == lower).toList();
    }

    if (activeOnly) {
      return list.where((m) => m.isActive).toList();
    }
    return list;
  }

  MasterItem? getById(int? id) {
    if (id == null || id <= 0) return null;
    try {
      return _allMasters.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  MasterItem? getByName(String masterType, String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final options = getOptions(masterType, activeOnly: false);
    final trimmed = name.trim().toLowerCase();
    try {
      return options.firstWhere(
        (m) => m.masterName.toLowerCase() == trimmed || m.masterCode.toLowerCase() == trimmed,
      );
    } catch (_) {
      return null;
    }
  }

  String getLabel(String masterType, dynamic idOrName, {String fallback = ''}) {
    if (idOrName == null) return fallback;
    if (idOrName is int) {
      final item = getById(idOrName);
      if (item != null) return item.masterName;
    } else if (idOrName is String && idOrName.trim().isNotEmpty) {
      final item = getByName(masterType, idOrName);
      if (item != null) return item.masterName;
      return idOrName;
    }
    return fallback;
  }

  int? getPaymentModeId(String? name) => getByName('PaymentMode', name)?.id;

  double getTaxRate(dynamic idOrName) {
    if (idOrName == null) return 0.0;
    MasterItem? item;
    if (idOrName is int) {
      item = getById(idOrName);
    } else if (idOrName is String) {
      item = getByName('Tax', idOrName);
    }

    if (item != null) {
      // Check description first, then code, then name for numeric percentage
      final desc = double.tryParse(item.description.replaceAll('%', '').trim());
      if (desc != null) return desc;

      final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(item.masterName);
      if (match != null) {
        return double.tryParse(match.group(1)!) ?? 0.0;
      }
    }

    if (idOrName is String) {
      final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(idOrName);
      if (match != null) {
        return double.tryParse(match.group(1)!) ?? 0.0;
      }
    }

    return 0.0;
  }

  Future<void> fetchAllMasters(String token, {bool forceRefresh = false, int? tenantId, String? tenantCode}) async {
    if (_hasFetched && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final baseUrl = ApiConfig.baseUrl;
      final uri = Uri.parse('$baseUrl/masters/all-dropdowns');
      final headers = {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        List<MasterItem> parseList(dynamic raw) {
          if (raw is List) {
            return raw.map((item) => MasterItem.fromJson(item as Map<String, dynamic>)).toList();
          }
          return [];
        }

        _categories = parseList(data['categories']);
        _uoms = parseList(data['uoms']);
        _itemTypes = parseList(data['itemTypes']);
        _brands = parseList(data['brands']);
        _paymentModes = parseList(data['paymentModes']);
        _taxes = parseList(data['taxes']);
        _expenseCategories = parseList(data['expenseCategories']);
        _allMasters = parseList(data['allMasters']);

        _hasFetched = true;
        _error = null;
      } else {
        _error = 'Failed to load master dropdowns (Status ${response.statusCode})';
      }
    } catch (e) {
      _error = 'Error loading master data: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void invalidateCache() {
    _hasFetched = false;
    notifyListeners();
  }
}
