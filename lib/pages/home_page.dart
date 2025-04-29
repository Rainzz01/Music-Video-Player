import 'package:flutter/material.dart';
import '../components/my_drawer.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("H O M E"),
      ),
      drawer: const MyDrawer(),
      body: const Center(
        child: Text(
          'Welcome to Music Player',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}