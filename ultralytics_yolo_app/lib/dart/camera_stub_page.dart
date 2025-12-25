import 'package:flutter/material.dart';

class CameraStubPage extends StatelessWidget {
  const CameraStubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pure Dart – Architectural Decision')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          '''
Camera preview and UI can be built in pure Dart.

However, real-time YOLO inference is delegated to native
(Kotlin / Swift) to ensure:

• Low-latency frame processing
• Hardware acceleration (NNAPI / Core ML)
• Stable lifecycle handling
• Predictable performance at scale

This mirrors production mobile ML architectures.
''',
        ),
      ),
    );
  }
}
