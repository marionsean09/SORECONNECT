import 'package:flutter/material.dart';

// ============================================================
// MINIMAL FILTER BAR
//
// Shared, low-chrome building blocks for every search/sort/filter
// header in the app. Deliberately undecorated: flat neutral fill,
// no borders, no shadows — the kind of "unseen" restraint that
// reads as considered rather than plain. Reused verbatim across
// screens so search bars, sort pills, and location pickers stay
// visually consistent everywhere instead of each screen inventing
// its own bordered/shadowed variant.
// ============================================================

const double kMinimalControlHeight = 42;
const double _kPillRadius = 12;

class MinimalSearchField extends StatelessWidget {
  const MinimalSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search...',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade500,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 20,
          color: Colors.grey.shade500,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.grey.shade500,
                ),
                tooltip: 'Clear search',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: Colors.grey.shade100,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kPillRadius),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// A compact, borderless dropdown pill — used for sort, status, type,
// and month filters. `fullWidth` stretches it for location pickers.
class MinimalDropdown<T> extends StatelessWidget {
  const MinimalDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.icon,
    this.enabled = true,
    this.fullWidth = false,
  });

  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
  final IconData? icon;
  final bool enabled;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? Colors.grey.shade800 : Colors.grey.shade400;
    final iconColor = enabled ? Colors.grey.shade600 : Colors.grey.shade400;

    return Container(
      height: kMinimalControlHeight,
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: enabled ? Colors.grey.shade100 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(_kPillRadius),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: fullWidth,
          isDense: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: iconColor,
          ),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      itemLabel(item),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}
