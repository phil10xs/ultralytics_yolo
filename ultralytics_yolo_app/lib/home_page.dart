import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_yolo_realtime/dart/camera_stub_page.dart';
import 'package:flutter_yolo_realtime/native_view/android_yolo_view.dart';
import 'package:flutter_yolo_realtime/native_view/ios_yolo_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    void open(Widget page) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('YOLO Realtime Showcase')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: Platform.isAndroid
                  ? () => open(const AndroidYoloViewPage())
                  : null,
              child: const Text('Native Android YOLO (Kotlin)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed:
                  Platform.isIOS ? () => open(const IOSYoloViewPage()) : null,
              child: const Text('Native iOS YOLO (Swift)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => open(const CameraStubPage()),
              child: const Text('Pure Dart Camera (No Inference)'),
            ),
          ],
        ),
      ),
    );
  }
}
