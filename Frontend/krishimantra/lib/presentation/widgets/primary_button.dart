import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/utils/responsive_utils.dart';

/// The single CTA button used across the app.
///
/// Replaces the dozen+ ad-hoc `ElevatedButton(... AppColors.green ...)`
/// blocks scattered through screens. Every screen used slightly different
/// padding, radius, and disabled-state colours; consolidating means
/// design changes happen in one file. Inline ElevatedButton uses still
/// work — this is opt-in, not enforced.
///
/// Variants:
///   - `PrimaryButton(...)` — solid green, white text. Default CTA.
///   - `PrimaryButton.outline(...)` — green border + green text on white,
///     used for secondary CTAs in the same screen.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool fullWidth;
  final IconData? icon;
  final bool _outline;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.fullWidth = true,
    this.icon,
  }) : _outline = false;

  const PrimaryButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.fullWidth = true,
    this.icon,
  }) : _outline = true;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    final bgColor = _outline ? AppColors.white : AppColors.green;
    final fgColor = _outline ? AppColors.green : AppColors.white;
    final borderSide = _outline
        ? const BorderSide(color: AppColors.green, width: 1.5)
        : BorderSide.none;

    final child = isLoading
        ? SizedBox(
            height: AppSizes.iconM,
            width: AppSizes.iconM,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: fgColor, size: AppSizes.iconS),
                SizedBox(width: AppSizes.paddingS),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: AppSizes.fontL,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                ),
              ),
            ],
          );

    final button = ElevatedButton(
      onPressed: disabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        disabledBackgroundColor:
            _outline ? AppColors.white : AppColors.disabled,
        disabledForegroundColor: AppColors.textMuted,
        elevation: _outline ? 0 : 1,
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.paddingXL,
          vertical: AppSizes.paddingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          side: borderSide,
        ),
      ),
      child: child,
    );

    return fullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
