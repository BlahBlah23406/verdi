// Synthetic investor environment, backed by its own SQLite database.
import 'package:flutter/material.dart';

import 'product/platform_app.dart';

void main() => runApp(
  PlatformApp(
    demo: true,
    institutional: Uri.base.queryParameters['view'] == 'institution',
  ),
);
