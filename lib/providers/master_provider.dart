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
    // 100% case-insensitive lookup across all possible key aliases
    dynamic getVal(List<String> keys) {
      for (final k in keys) {
        if (json.containsKey(k) && json[k] != null && json[k].toString().trim().isNotEmpty) {
          return json[k];
        }
      }
      for (final entry in json.entries) {
        for (final k in keys) {
          if (entry.key.toLowerCase() == k.toLowerCase() && entry.value != null && entry.value.toString().trim().isNotEmpty) {
            return entry.value;
          }
        }
      }
      return null;
    }

    final rawId = getVal(['id', 'ID', 'Id']) ?? 0;
    final id = rawId is int ? rawId : (int.tryParse(rawId.toString()) ?? 0);

    final rawType = getVal(['masterType', 'MasterType', 'type', 'Type']) ?? '';

    // Robust case-insensitive name resolution
    String name = getVal([
      'masterName', 'MasterName',
      'name', 'Name',
      'categoryName', 'CategoryName',
      'uomName', 'UOMName',
      'itemTypeName', 'ItemTypeName',
      'brandName', 'BrandName',
      'paymentModeName', 'PaymentModeName',
      'taxName', 'TaxName',
      'expenseCategoryName', 'ExpenseCategoryName',
      'expenseName', 'ExpenseName',
      'title', 'Title',
      'label', 'Label',
    ])?.toString().trim() ?? '';

    // Robust case-insensitive code resolution
    String code = getVal([
      'masterCode', 'MasterCode',
      'code', 'Code',
      'symbol', 'Symbol',
      'categoryCode', 'CategoryCode',
      'uomCode', 'UOMCode',
      'itemTypeCode', 'ItemTypeCode',
      'brandCode', 'BrandCode',
      'shortName', 'ShortName',
    ])?.toString().trim() ?? '';

    // If name is empty or literally 'Unnamed', fallback to code, then description, then ID
    if (name.isEmpty || name.toLowerCase() == 'unnamed') {
      if (code.isNotEmpty) {
        name = code;
      } else {
        final desc = getVal(['description', 'Description', 'desc', 'Desc'])?.toString().trim() ?? '';
        if (desc.isNotEmpty) {
          name = desc;
        } else {
          name = id > 0 ? 'Item #$id' : 'Item';
        }
      }
    }

    final desc = getVal(['description', 'Description', 'desc', 'Desc'])?.toString().trim() ?? '';
    final rawPriority = getVal(['priority', 'Priority']) ?? 0;
    final priority = rawPriority is int ? rawPriority : (int.tryParse(rawPriority.toString()) ?? 0);

    final rawActive = getVal(['isActive', 'IsActive', 'active', 'Active', 'status', 'Status']);
    bool isActive = true;
    if (rawActive != null) {
      if (rawActive is bool) {
        isActive = rawActive;
      } else {
        final str = rawActive.toString().toLowerCase().trim();
        isActive = (str == 'true' || str == '1' || str == 'active');
      }
    }

    return MasterItem(
      id: id,
      masterType: rawType.toString(),
      masterName: name,
      masterCode: code,
      description: desc,
      priority: priority,
      isActive: isActive,
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
    } else if (lower == 'expensecategory' || lower == 'expensecategories' || lower == 'expense' || lower == 'expenses') {
      list = _expenseCategories;
    } else {
      list = _allMasters.where((m) => m.masterType.toLowerCase() == lower).toList();
    }

    // Dynamic fallback if specific category list was empty but allMasters has items
    if (list.isEmpty && _allMasters.isNotEmpty) {
      list = _allMasters.where((m) {
        final t = m.masterType.trim().toLowerCase();
        if (lower == 'itemcategory' || lower == 'category' || lower == 'categories') {
          return t == 'itemcategory' || t == 'category' || t == 'categories';
        }
        if (lower == 'unitofmeasurement' || lower == 'uom' || lower == 'unit' || lower == 'units') {
          return t == 'unitofmeasurement' || t == 'uom' || t == 'unit' || t == 'units';
        }
        if (lower == 'itemtype' || lower == 'itemtypes' || lower == 'format') {
          return t == 'itemtype' || t == 'itemtypes' || t == 'format';
        }
        if (lower == 'brand' || lower == 'brands') {
          return t == 'brand' || t == 'brands';
        }
        if (lower == 'paymentmode' || lower == 'paymentmodes' || lower == 'payment') {
          return t == 'paymentmode' || t == 'paymentmodes' || t == 'payment';
        }
        if (lower == 'tax' || lower == 'taxes' || lower == 'gst') {
          return t == 'tax' || t == 'taxes' || t == 'gst';
        }
        if (lower == 'expensecategory' || lower == 'expensecategories' || lower == 'expense' || lower == 'expenses') {
          return t == 'expensecategory' || t == 'expensecategories' || t == 'expense' || t == 'expenses';
        }
        return t == lower;
      }).toList();
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
      try {
        return _allMasters.firstWhere(
          (m) => m.masterName.toLowerCase() == trimmed || m.masterCode.toLowerCase() == trimmed,
        );
      } catch (_) {
        return null;
      }
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
      final tId = tenantId ?? 0;
      final qParam = tId > 0 ? '?tenantId=$tId' : '';
      final uri = Uri.parse('$baseUrl/masters/all-dropdowns$qParam');
      final headers = {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (tId > 0) 'X-Tenant-Id': tId.toString(),
        if (tenantCode != null && tenantCode.isNotEmpty) 'X-Tenant-Code': tenantCode,
      };

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        dynamic getVal(Map<String, dynamic> map, String key) {
          if (map.containsKey(key)) return map[key];
          for (var entry in map.entries) {
            if (entry.key.toLowerCase() == key.toLowerCase()) return entry.value;
          }
          return null;
        }

        List<MasterItem> parseList(dynamic raw) {
          if (raw is List) {
            return raw
                .whereType<Map<String, dynamic>>()
                .map(MasterItem.fromJson)
                .toList();
          }
          return [];
        }

        if (decoded is Map<String, dynamic>) {
          _categories = parseList(getVal(decoded, 'categories'));
          _uoms = parseList(getVal(decoded, 'uoms'));
          _itemTypes = parseList(getVal(decoded, 'itemTypes'));
          _brands = parseList(getVal(decoded, 'brands'));
          _paymentModes = parseList(getVal(decoded, 'paymentModes'));
          _taxes = parseList(getVal(decoded, 'taxes'));
          _expenseCategories = parseList(getVal(decoded, 'expenseCategories'));
          _allMasters = parseList(getVal(decoded, 'allMasters'));

          // If individual lists are empty but _allMasters is populated, intelligently partition:
          if (_allMasters.isNotEmpty) {
            if (_categories.isEmpty) {
              _categories = _allMasters.where((m) {
                final t = m.masterType.toLowerCase();
                return t == 'itemcategory' || t == 'category' || t == 'categories';
              }).toList();
            }
            if (_uoms.isEmpty) {
              _uoms = _allMasters.where((m) {
                final t = m.masterType.toLowerCase();
                return t == 'unitofmeasurement' || t == 'uom' || t == 'unit' || t == 'units';
              }).toList();
            }
            if (_itemTypes.isEmpty) {
              _itemTypes = _allMasters.where((m) {
                final t = m.masterType.toLowerCase();
                return t == 'itemtype' || t == 'itemtypes' || t == 'format';
              }).toList();
            }
            if (_brands.isEmpty) {
              _brands = _allMasters.where((m) {
                final t = m.masterType.toLowerCase();
                return t == 'brand' || t == 'brands';
              }).toList();
            }
            if (_paymentModes.isEmpty) {
              _paymentModes = _allMasters.where((m) {
                final t = m.masterType.toLowerCase();
                return t == 'paymentmode' || t == 'paymentmodes' || t == 'payment';
              }).toList();
            }
            if (_taxes.isEmpty) {
              _taxes = _allMasters.where((m) {
                final t = m.masterType.toLowerCase();
                return t == 'tax' || t == 'taxes' || t == 'gst';
              }).toList();
            }
            if (_expenseCategories.isEmpty) {
              _expenseCategories = _allMasters.where((m) {
                final t = m.masterType.toLowerCase();
                return t == 'expensecategory' || t == 'expensecategories' || t == 'expense' || t == 'expenses';
              }).toList();
            }
          } else {
            // Or if _allMasters was empty but sublists were populated, union them:
            _allMasters = [
              ..._categories,
              ..._uoms,
              ..._itemTypes,
              ..._brands,
              ..._paymentModes,
              ..._taxes,
              ..._expenseCategories,
            ];
          }
        } else if (decoded is List) {
          _allMasters = parseList(decoded);
          _categories = _allMasters.where((m) {
            final t = m.masterType.toLowerCase();
            return t == 'itemcategory' || t == 'category' || t == 'categories';
          }).toList();
          _uoms = _allMasters.where((m) {
            final t = m.masterType.toLowerCase();
            return t == 'unitofmeasurement' || t == 'uom' || t == 'unit' || t == 'units';
          }).toList();
          _itemTypes = _allMasters.where((m) {
            final t = m.masterType.toLowerCase();
            return t == 'itemtype' || t == 'itemtypes' || t == 'format';
          }).toList();
          _brands = _allMasters.where((m) {
            final t = m.masterType.toLowerCase();
            return t == 'brand' || t == 'brands';
          }).toList();
          _paymentModes = _allMasters.where((m) {
            final t = m.masterType.toLowerCase();
            return t == 'paymentmode' || t == 'paymentmodes' || t == 'payment';
          }).toList();
          _taxes = _allMasters.where((m) {
            final t = m.masterType.toLowerCase();
            return t == 'tax' || t == 'taxes' || t == 'gst';
          }).toList();
          _expenseCategories = _allMasters.where((m) {
            final t = m.masterType.toLowerCase();
            return t == 'expensecategory' || t == 'expensecategories' || t == 'expense' || t == 'expenses';
          }).toList();
        }

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
