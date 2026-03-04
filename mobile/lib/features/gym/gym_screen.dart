import 'package:flutter/material.dart';

class GymScreen extends StatelessWidget {
  const GymScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gym')),
      body: const Center(
        child: Text('Gym search & check-in — placeholder'),
      ),
    );
  }
}
