import 'package:flutter/material.dart';

/// Breakpoints for responsive layout (logical pixels).
class Breakpoint {
  static const double mobile = 0;
  static const double tablet = 600;
  static const double desktop = 900;

  /// Max width for main content on desktop so it doesn't stretch too much.
  static const double contentMaxWidth = 720;
}

extension ResponsiveContext on BuildContext {
  double get width => MediaQuery.sizeOf(this).width;
  double get height => MediaQuery.sizeOf(this).height;
  bool get isWide => width >= Breakpoint.tablet;
  bool get isDesktop => width >= Breakpoint.desktop;
  bool get isNarrow => width < Breakpoint.tablet;
  EdgeInsets get padding => MediaQuery.paddingOf(this);
  EdgeInsets get viewInsets => MediaQuery.viewInsetsOf(this);
}

/// Wraps [child] so that on wide screens it's centered with [Breakpoint.contentMaxWidth].
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.width >= Breakpoint.tablet) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Breakpoint.contentMaxWidth),
          child: child,
        ),
      );
    }
    return child;
  }
}
