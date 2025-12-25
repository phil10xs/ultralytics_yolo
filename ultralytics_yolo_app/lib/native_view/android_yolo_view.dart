import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class AndroidYoloViewPage extends StatefulWidget {
  const AndroidYoloViewPage({super.key});

  @override
  State<AndroidYoloViewPage> createState() => _AndroidYoloViewPageState();
}

class _AndroidYoloViewPageState extends State<AndroidYoloViewPage> {
  late final Future<bool> _ready;

  @override
  void initState() {
    super.initState();
    _ready = _ensureCameraPermission();
  }

  Future<bool> _ensureCameraPermission() async {
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
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.data != true) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Camera permission is required.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      await openAppSettings();
                      if (!mounted) return;
                      setState(() {
                        _ready = _ensureCameraPermission();
                      });
                    },
                    child: const Text('Open Settings'),
                  )
                ],
              ),
            );
          }

          return const AndroidView(
            viewType: 'native_kotlin_yolo_view',
            creationParamsCodec: StandardMessageCodec(),
          );
        },
      ),
    );
  }
}
