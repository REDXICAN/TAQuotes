// lib/core/utils/disabled_state_helper.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Helper class for consistent disabled state handling across the app
class DisabledStateHelper {
  /// Get the appropriate color for disabled text
  static Color getDisabledTextColor(BuildContext context, {double opacity = 1.0}) {
    return Theme.of(context).disabledColor.withOpacity(opacity);
  }

  /// Get the appropriate color for disabled background
  static Color getDisabledBackgroundColor(BuildContext context, {double opacity = 0.1}) {
    return Theme.of(context).disabledColor.withOpacity(opacity);
  }

  /// Get the appropriate color for disabled borders
  static Color getDisabledBorderColor(BuildContext context, {double opacity = 0.3}) {
    return Theme.of(context).disabledColor.withOpacity(opacity);
  }

  /// Get the appropriate color for disabled icons
  static Color getDisabledIconColor(BuildContext context, {double opacity = 0.6}) {
    return Theme.of(context).disabledColor.withOpacity(opacity);
  }

  /// Create a disabled text style
  static TextStyle getDisabledTextStyle(BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    double opacity = 1.0,
  }) {
    return TextStyle(
      color: getDisabledTextColor(context, opacity: opacity),
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  /// Create a disabled container decoration
  static BoxDecoration getDisabledContainerDecoration(BuildContext context, {
    double borderRadius = 8.0,
    double backgroundOpacity = 0.1,
    double borderOpacity = 0.3,
    bool hasBorder = true,
  }) {
    return BoxDecoration(
      color: getDisabledBackgroundColor(context, opacity: backgroundOpacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder
          ? Border.all(
              color: getDisabledBorderColor(context, opacity: borderOpacity),
              width: 1,
            )
          : null,
    );
  }

  /// Check if a button should be disabled based on multiple conditions
  static bool shouldDisableButton({
    bool isLoading = false,
    bool hasErrors = false,
    bool hasEmptyRequiredFields = false,
    bool customCondition = false,
  }) {
    return isLoading || hasErrors || hasEmptyRequiredFields || customCondition;
  }

  /// Get button callback or null based on disabled state
  static VoidCallback? getButtonCallback({
    required VoidCallback onPressed,
    bool isLoading = false,
    bool hasErrors = false,
    bool hasEmptyRequiredFields = false,
    bool customCondition = false,
  }) {
    if (shouldDisableButton(
      isLoading: isLoading,
      hasErrors: hasErrors,
      hasEmptyRequiredFields: hasEmptyRequiredFields,
      customCondition: customCondition,
    )) {
      return null;
    }
    return onPressed;
  }

  /// Create a disabled overlay widget
  static Widget createDisabledOverlay({
    required Widget child,
    required bool isDisabled,
    String? disabledMessage,
  }) {
    if (!isDisabled) return child;

    return Stack(
      children: [
        Opacity(
          opacity: 0.5,
          child: AbsorbPointer(
            child: child,
          ),
        ),
        if (disabledMessage != null)
          Positioned.fill(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  disabledMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Create a disabled form field
  static InputDecoration getDisabledInputDecoration(BuildContext context, {
    String? labelText,
    String? hintText,
    String? helperText,
    IconData? prefixIcon,
    bool isEnabled = true,
  }) {
    final disabledColor = getDisabledTextColor(context, opacity: 0.6);

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      labelStyle: !isEnabled ? TextStyle(color: disabledColor) : null,
      hintStyle: !isEnabled ? TextStyle(color: disabledColor.withOpacity(0.5)) : null,
      helperStyle: !isEnabled ? TextStyle(color: disabledColor.withOpacity(0.7)) : null,
      prefixIcon: prefixIcon != null
          ? Icon(
              prefixIcon,
              color: !isEnabled ? disabledColor : null,
            )
          : null,
      filled: !isEnabled,
      fillColor: !isEnabled ? getDisabledBackgroundColor(context) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: !isEnabled ? getDisabledBorderColor(context) : Theme.of(context).dividerColor,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: getDisabledBorderColor(context),
        ),
      ),
    );
  }

  /// Create a disabled card
  static Widget createDisabledCard({
    required Widget child,
    required bool isDisabled,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      padding: padding,
      margin: margin,
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1.0,
        child: IgnorePointer(
          ignoring: isDisabled,
          child: child,
        ),
      ),
    );
  }

  /// Get the appropriate cursor for disabled state
  static SystemMouseCursor getMouseCursor(bool isDisabled) {
    return isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click;
  }

  /// Create a disabled list tile
  static Widget createDisabledListTile({
    required BuildContext context,
    required Widget title,
    Widget? subtitle,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
    bool isDisabled = false,
    String? disabledReason,
  }) {
    final tile = ListTile(
      title: DefaultTextStyle(
        style: TextStyle(
          color: isDisabled ? getDisabledTextColor(context) : null,
        ),
        child: title,
      ),
      subtitle: subtitle != null
          ? DefaultTextStyle(
              style: TextStyle(
                color: isDisabled ? getDisabledTextColor(context, opacity: 0.7) : null,
              ),
              child: subtitle,
            )
          : null,
      leading: leading != null
          ? IconTheme(
              data: IconThemeData(
                color: isDisabled ? getDisabledIconColor(context) : null,
              ),
              child: leading,
            )
          : null,
      trailing: trailing,
      onTap: isDisabled ? null : onTap,
      enabled: !isDisabled,
    );

    if (isDisabled && disabledReason != null) {
      return Tooltip(
        message: disabledReason,
        child: tile,
      );
    }

    return tile;
  }

  /// Check if form should be disabled based on validation
  static bool shouldDisableForm({
    required GlobalKey<FormState> formKey,
    List<TextEditingController>? requiredControllers,
    bool isSubmitting = false,
  }) {
    if (isSubmitting) return true;

    // Check if required fields are empty
    if (requiredControllers != null) {
      for (final controller in requiredControllers) {
        if (controller.text.trim().isEmpty) {
          return true;
        }
      }
    }

    // Note: Form validation state check would require more complex state management
    // This is a simplified version
    return false;
  }

  /// Create a disabled chip
  static Widget createDisabledChip({
    required BuildContext context,
    required String label,
    IconData? icon,
    bool isDisabled = false,
    VoidCallback? onDeleted,
  }) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          color: isDisabled ? getDisabledTextColor(context) : null,
        ),
      ),
      avatar: icon != null
          ? Icon(
              icon,
              size: 16,
              color: isDisabled ? getDisabledIconColor(context) : null,
            )
          : null,
      backgroundColor: isDisabled ? getDisabledBackgroundColor(context) : null,
      deleteIcon: isDisabled ? null : const Icon(Icons.close, size: 16),
      onDeleted: isDisabled ? null : onDeleted,
    );
  }
}