// ignore_for_file: file_names

import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Dashboard',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: DashboardBox(title: 'Technicians')),
                    const SizedBox(width: 16),
                    Expanded(child: DashboardBox(title: 'Checked Today')),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: DashboardBox(title: 'OK Tools')),
                    const SizedBox(width: 16),
                    Expanded(child: DashboardBox(title: 'Missing Tools')),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: DashboardBox(title: 'Defective Tools')),
                    const SizedBox(width: 16),
                    Expanded(child: DashboardBox(title: 'Total Tools')),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ✅ Reusable flexible dashboard box widget
class DashboardBox extends StatelessWidget {
  final String title;

  const DashboardBox({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1, // keeps it square and responsive
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 231, 235, 243),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey,
              blurRadius: 6,
              offset: const Offset(3, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
