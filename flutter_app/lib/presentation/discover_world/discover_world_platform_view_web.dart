import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

final Set<String> _registeredViewTypes = <String>{};

Widget buildDiscoverWorldPlatformView({
  required String viewType,
  required String containerId,
}) {
  if (_registeredViewTypes.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final element = html.DivElement()
        ..id = containerId
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..style.backgroundColor = '#120D18'
        ..style.overflow = 'hidden';
      return element;
    });
  }

  return HtmlElementView(
    key: const Key('discover-world-platform-view'),
    viewType: viewType,
  );
}
