import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class AndroidYoloViewPage extends StatefulWidget {
  const AndroidYoloViewPage({super.key});

  @override
  State<AndroidYoloViewPage> createState() => _AndroidYoloViewPageState();
}

class _AndroidYoloViewPageState extends State<AndroidYoloViewPage> {
  late Future<bool> _ready;

  @override
  void initState() {
    super.initState();
    _ready = _ensureCameraPermission();
  }

  Future<bool> _ensureCameraPermission() async {
    // If already granted, don't re-prompt
    final current = await Permission.camera.status;
    if (current.isGranted) return true;

    final status = await Permission.camera.request();
    return status.isGranted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Android Native YOLO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: FutureBuilder<bool>(
        future: _ready,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final granted = snap.data == true;

          if (!granted) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Camera permission is required.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      // Re-request first (this will show dialog if eligible)
                      final status = await Permission.camera.request();

                      // If permanently denied, send them to Settings
                      if (status.isPermanentlyDenied) {
                        await openAppSettings();
                      }

                      if (!mounted) return;
                      setState(() {
                        _ready = _ensureCameraPermission();
                      });
                    },
                    child: const Text('Grant Permission'),
                  ),
                ],
              ),
            );
          }

          // Native view only when permission is granted
          return const AndroidView(
            viewType: 'native_kotlin_yolo_view',
            creationParamsCodec: StandardMessageCodec(),
          );
        },
      ),
    );
  }
}
