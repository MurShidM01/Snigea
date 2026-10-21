import 'package:flutter/material.dart';

/// The entry point of the Snigea application.
void main() {
  runApp(const SnigeaBootstrap());
}

/// The shell of the application while the feature modules are added.
class SnigeaBootstrap extends StatelessWidget {
  const SnigeaBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Snigea'))),
    );
  }
}
