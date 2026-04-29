import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/utils/responsive_utils.dart';

/// Standard search input — pill shape, leading magnifier, optional
/// trailing clear button, debounced `onChanged`.
///
/// Replaces the inline TextField+InputDecoration blocks in marketplace,
/// reels, crops, and consultant screens which all looked subtly
/// different (different radii, different prefix-icon spacing,
/// different debounce intervals). 250ms is the default — long enough to
/// avoid one-request-per-keystroke against the search endpoint, short
/// enough to feel responsive.
class AppSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final Duration debounce;
  final bool autofocus;

  const AppSearchBar({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.debounce = const Duration(milliseconds: 250),
    this.autofocus = false,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  Timer? _debounceTimer;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_handleControllerChange);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_handleControllerChange);
    // Only dispose if we created the controller. If the caller passed
    // one in, they own its lifecycle.
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleControllerChange() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    if (widget.onChanged == null) return;
    _debounceTimer = Timer(widget.debounce, () {
      widget.onChanged!(value);
    });
  }

  void _clear() {
    _controller.clear();
    _debounceTimer?.cancel();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        onChanged: _onChanged,
        onSubmitted: widget.onSubmitted,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: AppSizes.fontM, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Search',
          hintStyle: TextStyle(fontSize: AppSizes.fontM, color: AppColors.textMuted),
          prefixIcon: Icon(Icons.search, size: AppSizes.iconM, color: AppColors.textGrey),
          suffixIcon: _hasText
              ? IconButton(
                  icon: Icon(Icons.close, size: AppSizes.iconS, color: AppColors.textGrey),
                  onPressed: _clear,
                  splashRadius: 20,
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSizes.paddingS,
            vertical: AppSizes.paddingM,
          ),
        ),
      ),
    );
  }
}
