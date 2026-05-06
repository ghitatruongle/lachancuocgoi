import 'package:flutter/material.dart';

class MonitoringPage extends StatelessWidget {
  final String? simulatedScenarioTitle;
  const MonitoringPage({super.key, this.simulatedScenarioTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitoring')),
      body: const Center(child: Text('Monitoring Page Stub')),
    );
  }
}
