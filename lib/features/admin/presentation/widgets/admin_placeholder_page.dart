import 'package:flutter/material.dart';

class AdminPlaceholderPage extends StatelessWidget {
  const AdminPlaceholderPage({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}
