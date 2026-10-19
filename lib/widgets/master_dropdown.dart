import 'package:flutter/material.dart';
import 'paginated_server_dropdown.dart';

/// Standard Server-Paginated Master Dropdown
/// Conforms to the Standard Large-Data architecture:
/// - Initially loads 5 records from server
/// - Search input with 350ms debounce
/// - Scrollable options with '+ Show More (+5)' pagination
/// - Preserves selected value without fetching all masters
/// - Eliminates client-side memory overhead and full-table network loading
class MasterDropdown extends StatelessWidget {
  final String masterType;
  final int? selectedId;
  final String? selectedValue;
  final String? label;
  final String? labelText;
  final String? hint;
  final dynamic parentFilter;
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
    this.parentFilter,
    this.isRequired = false,
    this.allowClear = false,
    this.enabled = true,
    this.prefixIcon,
    this.onChanged,
    this.validator,
  });

  String? get effectiveLabel => label ?? labelText;

  @override
  Widget build(BuildContext context) {
    return PaginatedServerDropdown.master(
      masterType: masterType,
      label: effectiveLabel,
      hint: hint ?? (effectiveLabel != null ? 'Select $effectiveLabel' : 'Select $masterType'),
      selectedId: selectedId,
      selectedTitle: selectedValue,
      parentFilter: parentFilter,
      isRequired: isRequired,
      allowClear: allowClear,
      enabled: enabled,
      prefixIcon: prefixIcon,
      validator: validator != null
          ? (val) {
              final intVal = val is int ? val : int.tryParse(val?.toString() ?? '');
              return validator!(intVal);
            }
          : null,
      onChanged: (item, id, title) {
        final intId = id is int ? id : int.tryParse(id?.toString() ?? '');
        onChanged?.call(intId, title);
      },
    );
  }
}
