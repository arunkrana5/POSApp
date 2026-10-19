import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';


class PaginatedServerDropdown<T> extends StatefulWidget {
  final String? label;
  final String? hint;
  final dynamic selectedId;
  final String? selectedTitle;
  final String Function(T item) itemTitle;
  final dynamic Function(T item) itemId;
  final String Function(T item)? itemSubtitle;
  final Future<PaginatedDropdownResult<T>> Function({
    required int page,
    required int pageSize,
    required String search,
    dynamic parentFilter,
  }) fetchPage;
  final dynamic parentFilter;
  final void Function(T? item, dynamic id, String? title)? onChanged;
  final bool isRequired;
  final bool allowClear;
  final bool enabled;
  final Widget? prefixIcon;
  final String? Function(dynamic)? validator;

  const PaginatedServerDropdown({
    super.key,
    this.label,
    this.hint,
    this.selectedId,
    this.selectedTitle,
    required this.itemTitle,
    required this.itemId,
    this.itemSubtitle,
    required this.fetchPage,
    this.parentFilter,
    this.onChanged,
    this.isRequired = false,
    this.allowClear = true,
    this.enabled = true,
    this.prefixIcon,
    this.validator,
  });

  /// Factory constructor for masters (ItemCategory, Brand, UnitOfMeasurement, etc.)
  static PaginatedServerDropdown<Map<String, dynamic>> master({
    Key? key,
    required String masterType,
    String? label,
    String? hint,
    dynamic selectedId,
    String? selectedTitle,
    dynamic parentFilter,
    void Function(Map<String, dynamic>? item, dynamic id, String? title)? onChanged,
    bool isRequired = false,
    bool allowClear = true,
    bool enabled = true,
    Widget? prefixIcon,
    String? Function(dynamic)? validator,
  }) {
    return PaginatedServerDropdown<Map<String, dynamic>>(
      key: key,
      label: label ?? masterType,
      hint: hint ?? 'Select ${label ?? masterType}',
      selectedId: selectedId,
      selectedTitle: selectedTitle,
      parentFilter: parentFilter,
      isRequired: isRequired,
      allowClear: allowClear,
      enabled: enabled,
      prefixIcon: prefixIcon,
      validator: validator,
      onChanged: onChanged,
      itemId: (item) => item['id'] ?? item['ID'],
      itemTitle: (item) => (item['masterName'] ?? item['name'] ?? item['MasterName'] ?? '').toString(),
      itemSubtitle: (item) => (item['masterCode'] ?? item['description'] ?? item['code'] ?? '').toString(),
      fetchPage: ({required int page, required int pageSize, required String search, dynamic parentFilter}) async {
        final baseUrl = ApiConfig.baseUrl;
        final params = <String, String>{
          'masterType': masterType,
          'page': page.toString(),
          'pageSize': pageSize.toString(),
          'paged': 'true',
          'activeOnly': 'true',
        };
        if (search.trim().isNotEmpty) {
          params['search'] = search.trim();
        }
        if (parentFilter != null && parentFilter.toString().isNotEmpty) {
          params['parentId'] = parentFilter.toString();
        }

        final uri = Uri.parse('$baseUrl/masters').replace(queryParameters: params);
        final res = await http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic> && data.containsKey('items')) {
            final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
            final hasMore = data['hasMore'] == true;
            final totalCount = (data['totalCount'] as num?)?.toInt() ?? items.length;
            return PaginatedDropdownResult<Map<String, dynamic>>(
              items: items,
              hasMore: hasMore,
              totalCount: totalCount,
            );
          } else if (data is List) {
            final items = List<Map<String, dynamic>>.from(data);
            return PaginatedDropdownResult<Map<String, dynamic>>(
              items: items,
              hasMore: false,
              totalCount: items.length,
            );
          }
        }
        return PaginatedDropdownResult<Map<String, dynamic>>(items: [], hasMore: false, totalCount: 0);
      },
    );
  }

  /// Factory constructor for items master
  static PaginatedServerDropdown<Map<String, dynamic>> items({
    Key? key,
    String? label = 'Item',
    String? hint = 'Select Item',
    dynamic selectedId,
    String? selectedTitle,
    dynamic parentFilter,
    void Function(Map<String, dynamic>? item, dynamic id, String? title)? onChanged,
    bool isRequired = false,
    bool allowClear = true,
    bool enabled = true,
    Widget? prefixIcon,
    String? Function(dynamic)? validator,
  }) {
    return PaginatedServerDropdown<Map<String, dynamic>>(
      key: key,
      label: label,
      hint: hint,
      selectedId: selectedId,
      selectedTitle: selectedTitle,
      parentFilter: parentFilter,
      isRequired: isRequired,
      allowClear: allowClear,
      enabled: enabled,
      prefixIcon: prefixIcon,
      validator: validator,
      onChanged: onChanged,
      itemId: (item) => item['id'] ?? item['ID'],
      itemTitle: (item) => (item['name'] ?? item['ItemName'] ?? '').toString(),
      itemSubtitle: (item) => '${item['itemCode'] ?? ''} • ${item['category'] ?? ''} • ${item['unit'] ?? 'pcs'}',
      fetchPage: ({required int page, required int pageSize, required String search, dynamic parentFilter}) async {
        final baseUrl = ApiConfig.baseUrl;
        final params = <String, String>{
          'page': page.toString(),
          'pageSize': pageSize.toString(),
          'paged': 'true',
        };
        if (search.trim().isNotEmpty) {
          params['search'] = search.trim();
        }
        if (parentFilter != null && parentFilter.toString().isNotEmpty) {
          params['categoryId'] = parentFilter.toString();
        }

        final uri = Uri.parse('$baseUrl/Items').replace(queryParameters: params);
        final res = await http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic> && data.containsKey('items')) {
            final list = List<Map<String, dynamic>>.from(data['items'] ?? []);
            return PaginatedDropdownResult<Map<String, dynamic>>(
              items: list,
              hasMore: data['hasMore'] == true,
              totalCount: (data['totalCount'] as num?)?.toInt() ?? list.length,
            );
          } else if (data is List) {
            final list = List<Map<String, dynamic>>.from(data);
            return PaginatedDropdownResult<Map<String, dynamic>>(
              items: list,
              hasMore: false,
              totalCount: list.length,
            );
          }
        }
        return PaginatedDropdownResult<Map<String, dynamic>>(items: [], hasMore: false, totalCount: 0);
      },
    );
  }

  /// Factory constructor for customers
  static PaginatedServerDropdown<Map<String, dynamic>> customers({
    Key? key,
    String? label = 'Customer',
    String? hint = 'Select Customer',
    dynamic selectedId,
    String? selectedTitle,
    bool includeWalkIn = true,
    void Function(Map<String, dynamic>? item, dynamic id, String? title)? onChanged,
    bool isRequired = false,
    bool allowClear = true,
    bool enabled = true,
    Widget? prefixIcon,
    String? Function(dynamic)? validator,
  }) {
    return PaginatedServerDropdown<Map<String, dynamic>>(
      key: key,
      label: label,
      hint: hint,
      selectedId: selectedId,
      selectedTitle: selectedTitle,
      isRequired: isRequired,
      allowClear: allowClear,
      enabled: enabled,
      prefixIcon: prefixIcon,
      validator: validator,
      onChanged: onChanged,
      itemId: (c) => c['id'] ?? c['ID'],
      itemTitle: (c) => (c['name'] ?? '').toString(),
      itemSubtitle: (c) => '${c['phone'] ?? c['mobile'] ?? ''} ${c['village'] != null && c['village'].toString().isNotEmpty ? '• ${c['village']}' : ''}',
      fetchPage: ({required int page, required int pageSize, required String search, dynamic parentFilter}) async {
        final baseUrl = ApiConfig.baseUrl;
        final params = <String, String>{
          'page': page.toString(),
          'pageSize': pageSize.toString(),
          'paged': 'true',
        };
        if (search.trim().isNotEmpty) {
          params['search'] = search.trim();
        }

        final uri = Uri.parse('$baseUrl/customers').replace(queryParameters: params);
        final res = await http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          List<Map<String, dynamic>> list = [];
          bool hasMore = false;
          int totalCount = 0;
          if (data is Map<String, dynamic> && data.containsKey('items')) {
            list = List<Map<String, dynamic>>.from(data['items'] ?? []);
            hasMore = data['hasMore'] == true;
            totalCount = (data['totalCount'] as num?)?.toInt() ?? list.length;
          } else if (data is List) {
            list = List<Map<String, dynamic>>.from(data);
            hasMore = false;
            totalCount = list.length;
          }

          if (includeWalkIn && page == 1 && (search.isEmpty || 'walk-in customer'.contains(search.toLowerCase()))) {
            list.insert(0, {'id': 0, 'name': 'Walk-in Customer', 'phone': ''});
          }

          return PaginatedDropdownResult<Map<String, dynamic>>(
            items: list,
            hasMore: hasMore,
            totalCount: totalCount,
          );
        }
        return PaginatedDropdownResult<Map<String, dynamic>>(items: [], hasMore: false, totalCount: 0);
      },
    );
  }

  @override
  State<PaginatedServerDropdown<T>> createState() => _PaginatedServerDropdownState<T>();
}

class PaginatedDropdownResult<T> {
  final List<T> items;
  final bool hasMore;
  final int totalCount;

  PaginatedDropdownResult({
    required this.items,
    required this.hasMore,
    required this.totalCount,
  });
}

class _PaginatedServerDropdownState<T> extends State<PaginatedServerDropdown<T>> {
  dynamic _currentId;
  String? _currentTitle;
  T? _selectedItem;
  T? get selectedItem => _selectedItem;

  @override
  void initState() {
    super.initState();
    _currentId = widget.selectedId;
    _currentTitle = widget.selectedTitle;
  }

  @override
  void didUpdateWidget(covariant PaginatedServerDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId != oldWidget.selectedId) {
      _currentId = widget.selectedId;
    }
    if (widget.selectedTitle != oldWidget.selectedTitle) {
      _currentTitle = widget.selectedTitle;
    }
    if (widget.parentFilter != oldWidget.parentFilter) {
      // Clear selection if dependent parent changed
      _currentId = null;
      _currentTitle = null;
      _selectedItem = null;
      widget.onChanged?.call(null, null, null);
    }
  }

  void _openSearchModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (modalCtx) {
        return _DropdownModalContent<T>(
          label: widget.label,
          selectedId: _currentId,
          itemId: widget.itemId,
          itemTitle: widget.itemTitle,
          itemSubtitle: widget.itemSubtitle,
          fetchPage: widget.fetchPage,
          parentFilter: widget.parentFilter,
          allowClear: widget.allowClear,
          onSelected: (item) {
            Navigator.pop(modalCtx);
            if (item != null) {
              final id = widget.itemId(item);
              final title = widget.itemTitle(item);
              setState(() {
                _selectedItem = item;
                _currentId = id;
                _currentTitle = title;
              });
              widget.onChanged?.call(item, id, title);
            } else {
              setState(() {
                _selectedItem = null;
                _currentId = null;
                _currentTitle = null;
              });
              widget.onChanged?.call(null, null, null);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final displayText = _currentTitle != null && _currentTitle!.trim().isNotEmpty
        ? _currentTitle!
        : (_currentId != null ? 'Item #$_currentId' : (widget.hint ?? 'Select ${widget.label ?? ''}'));

    final hasValue = _currentId != null || (_currentTitle != null && _currentTitle!.trim().isNotEmpty);

    return FormField<dynamic>(
      initialValue: _currentId,
      validator: widget.validator ??
          (widget.isRequired
              ? (val) {
                  if (!hasValue) {
                    return '${widget.label ?? 'This field'} is required';
                  }
                  return null;
                }
              : null),
      builder: (fieldState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: widget.enabled ? () => _openSearchModal(context) : null,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: widget.label != null && widget.isRequired ? '${widget.label} *' : widget.label,
                  prefixIcon: widget.prefixIcon ?? const Icon(Icons.arrow_drop_down_circle_outlined, size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.allowClear && hasValue && widget.enabled)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _selectedItem = null;
                              _currentId = null;
                              _currentTitle = null;
                            });
                            widget.onChanged?.call(null, null, null);
                            fieldState.didChange(null);
                          },
                        ),
                      const Icon(Icons.arrow_drop_down),
                      const SizedBox(width: 8),
                    ],
                  ),
                  errorText: fieldState.errorText,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  filled: !widget.enabled,
                  fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                ),
                child: Text(
                  displayText,
                  style: TextStyle(
                    color: hasValue
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DropdownModalContent<T> extends StatefulWidget {
  final String? label;
  final dynamic selectedId;
  final dynamic Function(T item) itemId;
  final String Function(T item) itemTitle;
  final String Function(T item)? itemSubtitle;
  final Future<PaginatedDropdownResult<T>> Function({
    required int page,
    required int pageSize,
    required String search,
    dynamic parentFilter,
  }) fetchPage;
  final dynamic parentFilter;
  final bool allowClear;
  final void Function(T? item) onSelected;

  const _DropdownModalContent({
    super.key,
    required this.label,
    required this.selectedId,
    required this.itemId,
    required this.itemTitle,
    this.itemSubtitle,
    required this.fetchPage,
    this.parentFilter,
    required this.allowClear,
    required this.onSelected,
  });

  @override
  State<_DropdownModalContent<T>> createState() => _DropdownModalContentState<T>();
}

class _DropdownModalContentState<T> extends State<_DropdownModalContent<T>> {
  final List<T> _items = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _currentPage = 1;
  static const int _pageSize = 5; // Standard Large-Data architecture: initial 5 records
  bool _hasMore = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 20) {
      if (_hasMore && !_isLoading && !_isLoadingMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
      _items.clear();
    });

    try {
      final res = await widget.fetchPage(
        page: 1,
        pageSize: _pageSize,
        search: _searchController.text.trim(),
        parentFilter: widget.parentFilter,
      );

      if (mounted) {
        setState(() {
          _items.addAll(res.items);
          _hasMore = res.hasMore;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load options: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final res = await widget.fetchPage(
        page: nextPage,
        pageSize: _pageSize,
        search: _searchController.text.trim(),
        parentFilter: widget.parentFilter,
      );

      if (mounted) {
        setState(() {
          // Append without duplicate IDs
          final existingIds = _items.map((i) => widget.itemId(i).toString()).toSet();
          for (var newItem in res.items) {
            final newId = widget.itemId(newItem).toString();
            if (!existingIds.contains(newId)) {
              _items.add(newItem);
              existingIds.add(newId);
            }
          }
          _currentPage = nextPage;
          _hasMore = res.hasMore;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _loadInitial();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            // Modal header
            Row(
              children: [
                const Icon(Icons.list_alt, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select ${widget.label ?? 'Option'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (widget.allowClear && widget.selectedId != null)
                  TextButton.icon(
                    icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                    label: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 13)),
                    onPressed: () => widget.onSelected(null),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Search input
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search ${widget.label ?? 'options'}...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _loadInitial();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 8),

            // Content list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2),
                          SizedBox(height: 12),
                          Text('Loading options...', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Retry'),
                                onPressed: _loadInitial,
                              ),
                            ],
                          ),
                        )
                      : _items.isEmpty
                          ? const Center(
                              child: Text('No matching items found', style: TextStyle(color: Colors.grey)),
                            )
                          : ListView.separated(
                              controller: _scrollController,
                              itemCount: _items.length + (_hasMore ? 1 : 0),
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                if (idx == _items.length) {
                                  // Show More button / loading spinner
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Center(
                                      child: _isLoadingMore
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : OutlinedButton.icon(
                                              icon: const Icon(Icons.expand_more, size: 18),
                                              label: const Text('Show More (+5)'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.indigo,
                                                side: const BorderSide(color: Colors.indigo),
                                              ),
                                              onPressed: _loadMore,
                                            ),
                                    ),
                                  );
                                }

                                final item = _items[idx];
                                final itemId = widget.itemId(item);
                                final isSelected = widget.selectedId != null &&
                                    widget.selectedId.toString() == itemId.toString();

                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    widget.itemTitle(item),
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? Colors.indigo : null,
                                    ),
                                  ),
                                  subtitle: widget.itemSubtitle != null
                                      ? Text(
                                          widget.itemSubtitle!(item),
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        )
                                      : null,
                                  trailing: isSelected ? const Icon(Icons.check, color: Colors.indigo) : null,
                                  onTap: () => widget.onSelected(item),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
