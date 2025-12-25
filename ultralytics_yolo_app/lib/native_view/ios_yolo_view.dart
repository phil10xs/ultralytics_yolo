import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:io';

class IOSYoloViewPage extends StatefulWidget {
  const IOSYoloViewPage({super.key});

  @override
  State<IOSYoloViewPage> createState() => _IOSYoloViewPageState();
}

class _IOSYoloViewPageState extends State<IOSYoloViewPage> {
  bool _showNative = false;

  @override
  void initState() {
    super.initState();
    // ✅ Delay platform-view creation until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _showNative = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) {
      return const Scaffold(body: Center(child: Text("iOS only")));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("iOS YOLO (Swift)")),
      body: _showNative
          ? const UiKitView(
              viewType:
                  "yolo-platform-view", // must match your AppDelegate registration
              creationParams: <String, dynamic>{},
              creationParamsCodec: StandardMessageCodec(),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
