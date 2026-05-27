import 'package:flutter/material.dart';

enum ModernButtonType {
  primary,
  secondary,
  outline,
  ghost,
}

class ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ModernButtonType type;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final double? height;

  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = ModernButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    
    // Determine button colors based on type
    Color backgroundColor;
    Color foregroundColor;
    Color borderColor;
    BorderSide? borderSide;
    
    switch (type) {
      case ModernButtonType.primary:
        backgroundColor = colors.primary;
        foregroundColor = colors.onPrimary;
        borderColor = Colors.transparent;
        break;
      case ModernButtonType.secondary:
        backgroundColor = colors.secondary;
        foregroundColor = colors.onSecondary;
        borderColor = Colors.transparent;
        break;
      case ModernButtonType.outline:
        backgroundColor = Colors.transparent;
        foregroundColor = colors.primary;
        borderColor = colors.primary;
        borderSide = BorderSide(color: borderColor, width: 1.5);
        break;
      case ModernButtonType.ghost:
        backgroundColor = Colors.transparent;
        foregroundColor = colors.onSurface.withOpacity(0.8);
        borderColor = Colors.transparent;
        break;
    }

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height ?? 48,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          splashFactory: InkRipple.splashFactory,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: borderSide != null ? Border.all(
                color: borderSide.color,
                width: borderSide.width,
              ) : null,
              boxShadow: type == ModernButtonType.primary || type == ModernButtonType.secondary
                  ? [
                      BoxShadow(
                        color: backgroundColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(
                            icon,
                            size: 18,
                            color: foregroundColor,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          text,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: foregroundColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class ModernIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final ModernButtonType type;
  final double? size;
  final String? tooltip;

  const ModernIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.type = ModernButtonType.ghost,
    this.size,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final buttonSize = size ?? 40;

    Color backgroundColor;
    Color foregroundColor;

    switch (type) {
      case ModernButtonType.primary:
        backgroundColor = colors.primary;
        foregroundColor = colors.onPrimary;
        break;
      case ModernButtonType.secondary:
        backgroundColor = colors.secondary;
        foregroundColor = colors.onSecondary;
        break;
      case ModernButtonType.outline:
        backgroundColor = Colors.transparent;
        foregroundColor = colors.primary;
        break;
      case ModernButtonType.ghost:
        backgroundColor = colors.surface.withOpacity(0.8);
        foregroundColor = colors.onSurface.withOpacity(0.8);
        break;
    }

    Widget button = Container(
      width: buttonSize,
      height: buttonSize,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: type == ModernButtonType.outline
            ? Border.all(color: colors.primary, width: 1.5)
            : null,
        boxShadow: type == ModernButtonType.primary || type == ModernButtonType.secondary
            ? [
                BoxShadow(
                  color: backgroundColor.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Icon(
              icon,
              size: buttonSize * 0.5,
              color: foregroundColor,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
