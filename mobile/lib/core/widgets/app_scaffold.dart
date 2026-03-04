import 'package:flutter/material.dart';

/// Reusable scaffold with optional app bar, body padding, and safe area.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.title,
    this.actions,
    this.body,
    this.floatingActionButton,
    this.padding = const EdgeInsets.all(16),
  });

  final String? title;
  final List<Widget>? actions;
  final Widget? body;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title != null
          ? AppBar(
              title: Text(title!),
              actions: actions,
            )
          : null,
      body: body != null
          ? SafeArea(
              child: Padding(
                padding: padding,
                child: body,
              ),
            )
          : null,
      floatingActionButton: floatingActionButton,
    );
  }
}
