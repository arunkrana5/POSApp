import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/master_provider.dart';

class MasterDropdown extends StatefulWidget {
  final String masterType;
  final int? selectedId;
  final String? selectedValue;
  final String? label;
  final String? labelText;
  final String? hint;
  final bool isRequired;
  final bool allowClear;
  final bool enabled;
  final Widget? prefixIcon;
  final void Function(int? id, String? name)? onChanged;
  final FormFieldValidator<int>? validator;

  const MasterDropdown({
    super.key,
    required this.masterType,
    this.selectedId,
    this.selectedValue,
    this.label,
    this.labelText,
    this.hint,
    this.isRequired = false,
    this.allowClear = false,
    this.enabled = true,
    this.prefixIcon,
    this.onChanged,
    this.validator,
  });

  String? get effectiveLabel => label ?? labelText;

  @override
  State<MasterDropdown> createState() => _MasterDropdownState();
}

class _MasterDropdownState extends State<MasterDropdown> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLoaded();
    });
  }

  void _ensureLoaded() {
    final masterProvider = Provider.of<MasterProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!masterProvider.hasFetched && !masterProvider.isLoading) {
      masterProvider.fetchAllMasters(
        authProvider.accessToken ?? '',
        tenantCode: authProvider.tenantCode,
      );
    }
  }

  void _showSearchPicker(BuildContext context, List<MasterItem> items, MasterItem? currentSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final filtered = items.where((item) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return item.masterName.toLowerCase().contains(q) ||
                  item.masterCode.toLowerCase().contains(q) ||
                  item.description.toLowerCase().contains(q);
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 16,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.55,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(widget.prefixIcon != null ? Icons.search : Icons.list_alt, color: Colors.indigo),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Select ${widget.label ?? widget.masterType}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        if (widget.allowClear && currentSelected != null)
                          TextButton(
                            onPressed: () {
                              Navigator.pop(modalCtx);
                              widget.onChanged?.call(null, null);
                            },
                            child: const Text('Clear', style: TextStyle(color: Colors.red)),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search options...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) => setModalState(() => query = val),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No matching items found', style: TextStyle(color: Colors.grey)))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (listCtx, idx) {
                                final opt = filtered[idx];
                                final isSel = currentSelected?.id == opt.id;
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    opt.masterName,
                                    style: TextStyle(
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                      color: isSel ? Colors.indigo : null,
                                    ),
                                  ),
                                  subtitle: opt.masterCode.isNotEmpty || opt.description.isNotEmpty
                                      ? Text(
                                          opt.masterCode.isNotEmpty ? opt.masterCode : opt.description,
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        )
                                      : null,
                                  trailing: isSel ? const Icon(Icons.check, color: Colors.indigo) : null,
                                  onTap: () {
                                    Navigator.pop(modalCtx);
                                    widget.onChanged?.call(opt.id, opt.masterName);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = Provider.of<MasterProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (masterProvider.isLoading && !masterProvider.hasFetched) {
      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (widget.prefixIcon != null) ...[
              widget.prefixIcon!,
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                'Loading ${widget.label ?? widget.masterType}...',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      );
    }

    final activeOptions = masterProvider.getOptions(widget.masterType, activeOnly: true);

    // Resolve current selected item
    MasterItem? currentItem;
    if (widget.selectedId != null && widget.selectedId! > 0) {
      currentItem = masterProvider.getById(widget.selectedId);
    }
    if (currentItem == null && widget.selectedValue != null && widget.selectedValue!.trim().isNotEmpty) {
      currentItem = masterProvider.getByName(widget.masterType, widget.selectedValue);
    }

    // Build selectable items list, including current item even if inactive (Phase 6 safe handling)
    final itemsList = List<MasterItem>.from(activeOptions);
    if (currentItem != null && !itemsList.any((it) => it.id == currentItem!.id)) {
      itemsList.insert(0, currentItem);
    }

    // If options are numerous (> 6), present a searchable modal picker for high usability
    final useSearchPicker = itemsList.length > 6;

    if (useSearchPicker) {
      final displayText = currentItem != null
          ? (currentItem.isActive ? currentItem.masterName : '${currentItem.masterName} (Inactive)')
          : (widget.selectedValue != null && widget.selectedValue!.isNotEmpty
              ? widget.selectedValue!
              : (widget.hint ?? 'Select ${widget.effectiveLabel ?? widget.masterType}'));

      return FormField<int>(
        initialValue: currentItem?.id,
        validator: widget.validator ??
            (widget.isRequired
                ? (val) {
                    if (currentItem == null && (widget.selectedValue == null || widget.selectedValue!.isEmpty)) {
                      return '${widget.effectiveLabel ?? widget.masterType} is required';
                    }
                    return null;
                  }
                : null),
        builder: (fieldState) {
          final hasError = fieldState.hasError;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: widget.enabled
                    ? () => _showSearchPicker(context, itemsList, currentItem)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: widget.isRequired ? '${widget.effectiveLabel ?? widget.masterType} *' : widget.effectiveLabel,
                    prefixIcon: widget.prefixIcon,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.allowClear && currentItem != null && widget.enabled)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              fieldState.didChange(null);
                              widget.onChanged?.call(null, null);
                            },
                          ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    errorText: hasError ? fieldState.errorText : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  child: Text(
                    displayText,
                    style: TextStyle(
                      color: currentItem != null || (widget.selectedValue != null && widget.selectedValue!.isNotEmpty)
                          ? (isDark ? Colors.white : Colors.black87)
                          : Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    // Standard DropdownButtonFormField for shorter lists
    final dropdownItems = itemsList.map((item) {
      final isInactive = !item.isActive;
      return DropdownMenuItem<int>(
        value: item.id,
        child: Row(
          children: [
            Expanded(
              child: Text(
                isInactive ? '${item.masterName} (Inactive)' : item.masterName,
                style: TextStyle(
                  color: isInactive ? Colors.grey : null,
                  fontStyle: isInactive ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            if (item.masterCode.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.masterCode,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ),
          ],
        ),
      );
    }).toList();

    return DropdownButtonFormField<int>(
      value: currentItem?.id,
      decoration: InputDecoration(
        labelText: widget.isRequired ? '${widget.effectiveLabel ?? widget.masterType} *' : widget.effectiveLabel,
        hintText: widget.hint ?? 'Select ${widget.effectiveLabel ?? widget.masterType}',
        prefixIcon: widget.prefixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        suffixIcon: widget.allowClear && currentItem != null && widget.enabled
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => widget.onChanged?.call(null, null),
              )
            : null,
      ),
      items: dropdownItems,
      onChanged: widget.enabled
          ? (newId) {
              if (newId == null) {
                widget.onChanged?.call(null, null);
              } else {
                final found = masterProvider.getById(newId);
                widget.onChanged?.call(newId, found?.masterName);
              }
            }
          : null,
      validator: widget.validator ??
          (widget.isRequired
              ? (val) {
                  if (val == null || val <= 0) {
                    return '${widget.effectiveLabel ?? widget.masterType} is required';
                  }
                  return null;
                }
              : null),
    );
  }
}
