import 'package:flutter/widgets.dart';

import 'discover_world_platform_view_stub.dart'
    if (dart.library.js_interop) 'discover_world_platform_view_web.dart'
    as platform;

class DiscoverWorldPlatformView extends StatelessWidget {
  const DiscoverWorldPlatformView({
    super.key,
    required this.viewType,
    required this.containerId,
  });

  final String viewType;
  final String containerId;

  @override
  Widget build(BuildContext context) {
    return platform.buildDiscoverWorldPlatformView(
      viewType: viewType,
      containerId: containerId,
    );
  }
}
