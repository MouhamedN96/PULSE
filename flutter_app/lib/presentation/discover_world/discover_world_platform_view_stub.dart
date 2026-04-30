import 'package:flutter/widgets.dart';

Widget buildDiscoverWorldPlatformView({
  required String viewType,
  required String containerId,
}) {
  return const ColoredBox(
    key: Key('discover-world-platform-view'),
    color: Color(0xFF120D18),
    child: SizedBox.expand(),
  );
}
